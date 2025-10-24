package main

import (
	"bufio"
	"bytes"
	"compress/gzip"
	"context"
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/blob"
	"github.com/caarlos0/env/v11"
	"github.com/joho/godotenv"
	_ "github.com/mattn/go-sqlite3"
)

type Config struct {
	Timeout                      time.Duration `env:"EXPORT_TIMEOUT" envDefault:"10m"`
	CostAnalysisURL              string        `env:"COST_ANALYSIS_URL" envDefault:"http://cost-analysis-agent-svc:9094"`
	AzureStorageConnectionString string        `env:"AZURE_STORAGE_CONNECTION_STRING"`
	AzureStorageBlobName         string        `env:"AZURE_STORAGE_BLOB_NAME"`
	AzureStorageContainerName    string        `env:"AZURE_STORAGE_CONTAINER_NAME"`
	AzureStorageAKSDataPrefix    string        `env:"AZURE_STORAGE_AKS_DATA_PREFIX" envDefault:"cost-analysis/"`
	AzureStorageCostExportPrefix string        `env:"AZURE_STORAGE_COST_EXPORT_PREFIX" envDefault:"cost-management/"`
	AzureStorageResultFile       string        `env:"AZURE_STORAGE_RESULT_FILE" envDefault:"cost-analysis/result.csv"`
	SQLiteFilePath               string        `env:"SQLITE_FILE_PATH"`
	ExportDate                   *time.Time    `env:"EXPORT_DATE" envDefault:""`
}

func main() {
	// Default to "both" if no arguments provided
	operation := "both"

	// Use the first positional argument as the operation
	if len(os.Args) > 1 {
		operation = os.Args[1]
	}

	err := ConfigureAndProcess(context.Background(), operation)
	if err != nil {
		slog.Error("failed to process data", "error", err)
		os.Exit(1)
	}
	slog.Info("data processing completed successfully")
	os.Exit(0)
}

type App struct {
	Config     Config
	BlobClient *azblob.Client
	ExportDate time.Time
	DB         *sql.DB
}

func NewApp(cfg Config) (*App, error) {
	blobClient, err := createBlobClient(cfg)
	if err != nil {
		return nil, fmt.Errorf("creating blob client: %w", err)
	}
	exportDate := time.Now().UTC().Add(-24 * time.Hour)
	if cfg.ExportDate != nil {
		exportDate = cfg.ExportDate.UTC()
	}
	return &App{
		Config:     cfg,
		BlobClient: blobClient,
		ExportDate: exportDate,
	}, nil
}

func (a *App) Process(ctx context.Context) error {
	if err := a.Export(ctx); err != nil {
		return fmt.Errorf("exporting data: %w", err)
	}
	slog.Info("export completed, starting merge")
	if err := a.Merge(ctx); err != nil {
		return fmt.Errorf("merging data: %w", err)
	}
	return nil
}

func createBlobClient(cfg Config) (*azblob.Client, error) {
	// If connection string is provided (for testing), use it
	if cfg.AzureStorageConnectionString != "" {
		return azblob.NewClientFromConnectionString(cfg.AzureStorageConnectionString, nil)
	}

	// Otherwise use default credentials (for production)
	credential, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		return nil, fmt.Errorf("creating default credential: %w", err)
	}

	return azblob.NewClient(cfg.AzureStorageBlobName, credential, nil)
}

func ConfigureAndProcess(ctx context.Context, operation string) error {
	// Load environment variables from .env file
	if err := godotenv.Load(".env"); err != nil {
		slog.Warn("failed to load .env file", "error", err)
	}

	// Parse configuration from environment variables
	var cfg Config
	if err := env.Parse(&cfg); err != nil {
		return fmt.Errorf("parsing config: %w", err)
	}

	// Validate configuration
	if err := cfg.Validate(); err != nil {
		return fmt.Errorf("invalid config: %w", err)
	}

	app, err := NewApp(cfg)
	if err != nil {
		return err
	}

	switch operation {
	case "export":
		return app.Export(ctx)
	case "merge":
		return app.Merge(ctx)
	case "both":
		return app.Process(ctx)
	default:
		return fmt.Errorf("invalid operation mode: %s (valid options: export, merge, both)", operation)
	}
}

func (c *Config) Validate() error {
	if c.AzureStorageContainerName == "" {
		return errors.New("AZURE_STORAGE_CONTAINER_NAME is required")
	}
	if c.AzureStorageConnectionString == "" && c.AzureStorageBlobName == "" {
		return errors.New("either AZURE_STORAGE_CONNECTION_STRING or AZURE_STORAGE_BLOB_NAME must be provided")
	}
	if c.Timeout <= 0 {
		return errors.New("EXPORT_TIMEOUT must be positive")
	}
	return nil
}

func (a *App) Export(ctx context.Context) error {
	// Calculate midnight timestamps
	date := a.ExportDate.UTC()
	startTime := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	endTime := startTime.Add(24 * time.Hour)

	// Format timestamps as RFC3339
	from := startTime.Format(time.RFC3339)
	to := endTime.Format(time.RFC3339)

	// Build URL with query parameters
	agentURL := fmt.Sprintf("%s/resources/v1?from=%s&source=opencost&to=%s", a.Config.CostAnalysisURL, from, to)

	slog.Info("exporting data", "url", agentURL, "from", from, "to", to)

	// Create request with context
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, agentURL, nil)
	if err != nil {
		return fmt.Errorf("creating request: %w", err)
	}

	// Execute request
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to reach cost analysis service: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("cost analysis service returned status: %s", resp.Status)
	}

	AKSData := &AKSData{}
	if err := json.NewDecoder(resp.Body).Decode(AKSData); err != nil {
		return fmt.Errorf("decoding response: %w", err)
	}
	slog.Info("data received", "resources_count", len(AKSData.Resources))

	// Convert to CSV format
	var csvBuffer bytes.Buffer
	writer := csv.NewWriter(&csvBuffer)

	// Write CSV header
	if err := writer.Write([]string{"Date", "ID", "Name", "Kind", "Fraction", "SplitBucket", "SplitKey"}); err != nil {
		return fmt.Errorf("writing CSV header: %w", err)
	}

	// Write CSV rows
	for _, resource := range AKSData.Resources {
		for _, split := range resource.Splits {
			// Compact JSON if possible
			splitKey := string(split.SplitKey)
			if len(split.SplitKey) > 0 {
				var buf bytes.Buffer
				if json.Compact(&buf, split.SplitKey) == nil {
					splitKey = buf.String()
				}
			}

			record := []string{
				startTime.Format(time.DateOnly),
				resource.ID,
				resource.Name,
				resource.Kind,
				fmt.Sprintf("%f", split.Fraction),
				split.SplitBucket,
				splitKey,
			}
			if err := writer.Write(record); err != nil {
				return fmt.Errorf("writing CSV record: %w", err)
			}
		}
	}

	// Flush the writer to ensure all data is written
	writer.Flush()
	if err := writer.Error(); err != nil {
		return fmt.Errorf("CSV writer error: %w", err)
	}

	// Create export file path
	fileName := fmt.Sprintf("export-%s.csv", startTime.Format(time.DateOnly))
	csvPath, err := url.JoinPath(a.Config.AzureStorageAKSDataPrefix, fileName)
	if err != nil {
		return fmt.Errorf("joining path for CSV: %w", err)
	}

	// Upload CSV data
	_, err = a.BlobClient.UploadBuffer(ctx, a.Config.AzureStorageContainerName, csvPath, csvBuffer.Bytes(), nil)
	if err != nil {
		return fmt.Errorf("uploading CSV blob: %w", err)
	}

	slog.Info("CSV data exported successfully", "path", csvPath)

	return nil
}

func sqlLiteFile(cfg Config) (*os.File, error) {
	if cfg.SQLiteFilePath == "" {
		tmpDB, err := os.CreateTemp("", "test-*.db")
		if err != nil {
			return nil, fmt.Errorf("creating temp database file: %w", err)
		}
		return tmpDB, nil
	}
	dir := filepath.Dir(cfg.SQLiteFilePath)
	err := os.MkdirAll(dir, 0755)
	if err != nil {
		return nil, fmt.Errorf("creating directory for database file: %w", err)
	}
	tmpDB, err := os.Create(cfg.SQLiteFilePath)
	if err != nil {
		return nil, fmt.Errorf("creating database file: %w", err)
	}
	return tmpDB, nil
}

func (a *App) Merge(ctx context.Context) error {
	// Create temporary SQLite database
	tmpDB, err := sqlLiteFile(a.Config)
	if err != nil {
		return fmt.Errorf("creating temporary database file: %w", err)
	}
	defer func() { _ = tmpDB.Close() }()

	// Initialize database
	a.DB, err = sql.Open("sqlite3", tmpDB.Name())
	if err != nil {
		return fmt.Errorf("opening database: %w", err)
	}
	defer func() { _ = a.DB.Close() }()

	a.DB.SetMaxOpenConns(1)
	a.DB.SetMaxIdleConns(1)
	a.DB.SetConnMaxLifetime(0)

	if err := a.DB.Ping(); err != nil {
		return fmt.Errorf("pinging database: %w", err)
	}

	slog.Info("temporary database created", "path", tmpDB.Name())

	// Import AKS data
	if err := a.importAKSData(ctx); err != nil {
		return fmt.Errorf("importing AKS data: %w", err)
	}

	// Import cost management data
	if err := a.importCostManagementData(ctx); err != nil {
		return fmt.Errorf("importing cost management data: %w", err)
	}

	// Join data and export result
	if err := a.joinAndExportData(ctx); err != nil {
		return fmt.Errorf("joining and exporting data: %w", err)
	}

	return nil
}

func (a *App) importAKSData(ctx context.Context) error {
	// List and process all CSV files
	pager := a.BlobClient.NewListBlobsFlatPager(a.Config.AzureStorageContainerName, &azblob.ListBlobsFlatOptions{
		Prefix: &a.Config.AzureStorageAKSDataPrefix,
	})

	for pager.More() {
		page, err := pager.NextPage(ctx)
		if err != nil {
			return fmt.Errorf("getting next page of blobs: %w", err)
		}

		for _, blob := range page.Segment.BlobItems {
			if blob.Name == nil {
				continue
			}

			// Process only AKS export CSV files (including gzipped ones)
			if !strings.HasPrefix(*blob.Name, a.Config.AzureStorageAKSDataPrefix+"export-") ||
				(!strings.HasSuffix(*blob.Name, ".csv") && !strings.HasSuffix(*blob.Name, ".csv.gz")) {
				continue
			}

			if err := a.processAKSBlob(ctx, *blob.Name); err != nil {
				slog.Error("failed to process AKS blob", "name", *blob.Name, "error", err)
				continue
			}
		}
	}

	return nil
}

func (a *App) processAKSBlob(ctx context.Context, blobName string) error {
	return a.processCSVBlob(ctx, blobName, "aks_splits", "processing AKS blob", "imported AKS data from blob")
}

func (a *App) importCostManagementData(ctx context.Context) error {
	// List and process all cost management CSV files
	pager := a.BlobClient.NewListBlobsFlatPager(a.Config.AzureStorageContainerName, &azblob.ListBlobsFlatOptions{
		Prefix: &a.Config.AzureStorageCostExportPrefix,
	})

	filesProcessed := 0

	for pager.More() {
		page, err := pager.NextPage(ctx)
		if err != nil {
			return fmt.Errorf("getting next page of blobs: %w", err)
		}

		for _, blob := range page.Segment.BlobItems {
			if blob.Name == nil {
				continue
			}

			// Process only CSV files (including gzipped ones)
			if !strings.HasSuffix(*blob.Name, ".csv") &&
				!strings.HasSuffix(*blob.Name, ".csv.gz") {
				continue
			}

			if err := a.processCostManagementBlob(ctx, *blob.Name); err != nil {
				slog.Error("failed to process cost management blob", "name", *blob.Name, "error", err)
				continue
			}
			filesProcessed++
		}
	}

	if filesProcessed == 0 {
		slog.Error("no cost management files found to process", "prefix", a.Config.AzureStorageCostExportPrefix)
	} else {
		slog.Info("processed cost management files", "count", filesProcessed)
	}

	return nil
}

func (a *App) processCostManagementBlob(ctx context.Context, blobName string) error {
	return a.processCSVBlob(ctx, blobName, "cost_management", "processing cost management blob", "imported cost management data from blob")
}

func (a *App) processCSVBlob(ctx context.Context, blobName, tableName, startMsg, endMsg string) error {
	slog.Info(startMsg, "name", blobName)

	tmpfile, err := os.CreateTemp("", "csv_blob_*")
	if err != nil {
		return fmt.Errorf("creating temp file: %w", err)
	}
	defer func() {
		_ = tmpfile.Close()
		_ = os.Remove(tmpfile.Name())
	}()

	// Download blob
	_, err = a.BlobClient.DownloadFile(ctx, a.Config.AzureStorageContainerName, blobName, tmpfile, nil)
	if err != nil {
		return fmt.Errorf("downloading blob: %w", err)
	}

	// Reset file pointer to beginning
	_, err = tmpfile.Seek(0, 0)
	if err != nil {
		return fmt.Errorf("seeking to beginning of file: %w", err)
	}

	// Import the CSV data (handle gzip automatically)
	var reader io.Reader = tmpfile
	if strings.HasSuffix(blobName, ".gz") {
		gr, err := gzip.NewReader(tmpfile)
		if err != nil {
			return fmt.Errorf("creating gzip reader: %w", err)
		}
		defer func() { _ = gr.Close() }()
		reader = gr
	}

	err = a.ImportCSV(ctx, reader, tableName)
	if err != nil {
		return fmt.Errorf("importing CSV data: %w", err)
	}

	slog.Info(endMsg, "name", blobName)
	return nil
}

func (a *App) joinAndExportData(ctx context.Context) error {
	file, err := a.JoinData(ctx)
	if err != nil {
		return fmt.Errorf("joining data: %w", err)
	}
	slog.Info("data joined successfully", "file", file.Name())

	contentType := "text/csv"
	_, err = a.BlobClient.UploadFile(ctx, a.Config.AzureStorageContainerName, a.Config.AzureStorageResultFile, file, &azblob.UploadFileOptions{
		HTTPHeaders: &blob.HTTPHeaders{
			BlobContentType: &contentType,
		},
	})
	if err != nil {
		return fmt.Errorf("uploading joined data to blob: %w", err)
	}
	slog.Info("joined data uploaded successfully", "blob_name", a.Config.AzureStorageResultFile)

	return nil
}

type AKSData struct {
	Resources []Resource `json:"resources"`
}

type Resource struct {
	ID     string  `json:"ID"`
	Name   string  `json:"Name"`
	Kind   string  `json:"Kind"`
	Splits []Split `json:"Splits"`
}

type Split struct {
	Fraction    float64         `json:"Fraction"`
	SplitKey    json.RawMessage `json:"SplitKey"`
	SplitBucket string          `json:"SplitBucket"`
}

func (a *App) ImportCSV(ctx context.Context, data io.Reader, tableName string) error {
	csvReader := csv.NewReader(stripBOMReader(data))
	header, err := csvReader.Read()
	if err != nil {
		if errors.Is(err, io.EOF) {
			// For empty files, create a table with standard cost management columns
			if tableName == "cost_management" {
				standardHeader := []string{"SubscriptionGuid", "ResourceGroup", "ResourceLocation", "UsageDateTime", "MeterCategory", "MeterSubCategory", "MeterId", "MeterName", "MeterRegion", "UsageQuantity", "ResourceRate", "PreTaxCost", "ConsumedService", "ResourceType", "InstanceId", "Tags", "OfferId", "AdditionalInfo", "ServiceInfo1", "ServiceInfo2", "ServiceName", "ServiceTier", "Currency", "UnitOfMeasure"}
				return a.createTableFromHeader(ctx, tableName, standardHeader)
			}
			return nil
		}
		return fmt.Errorf("reading header: %w", err)
	}

	if err := a.createTableFromHeader(ctx, tableName, header); err != nil {
		return fmt.Errorf("creating table: %w", err)
	}

	// Build INSERT statement with placeholders
	placeholders := make([]string, len(header))
	for i := range header {
		placeholders[i] = "?"
	}

	quotedColumns := make([]string, len(header))
	for i, col := range header {
		quotedColumns[i] = quoteIdentifier(col)
	}
	query := fmt.Sprintf(
		`INSERT INTO %s (%s) VALUES (%s)`,
		quoteIdentifier(tableName),
		strings.Join(quotedColumns, ", "),
		strings.Join(placeholders, ", "),
	)

	const batchSize = 10000
	batch := make([][]interface{}, 0, batchSize)
	lineNum := 1

	for {
		record, err := csvReader.Read()
		if errors.Is(err, io.EOF) {
			// Process final batch if any
			if len(batch) > 0 {
				if err := a.executeBatch(ctx, query, batch); err != nil {
					return fmt.Errorf("executing final batch: %w", err)
				}
			}
			break
		}
		if err != nil {
			return fmt.Errorf("reading CSV record at line %d: %w", lineNum+1, err)
		}
		lineNum++

		// Convert []string to []interface{}
		values := make([]interface{}, len(record))
		for i, v := range record {
			values[i] = v
		}

		batch = append(batch, values)

		// Execute batch when full
		if len(batch) >= batchSize {
			if err := a.executeBatch(ctx, query, batch); err != nil {
				return fmt.Errorf("executing batch at line %d: %w", lineNum, err)
			}
			batch = batch[:0] // Reset batch
		}
	}

	return nil
}

func (a *App) executeBatch(ctx context.Context, query string, batch [][]interface{}) error {
	tx, err := a.DB.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("beginning transaction: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	stmt, err := tx.PrepareContext(ctx, query)
	if err != nil {
		return fmt.Errorf("preparing statement: %w", err)
	}
	defer func() { _ = stmt.Close() }()

	for _, values := range batch {
		_, err = stmt.ExecContext(ctx, values...)
		if err != nil {
			return fmt.Errorf("inserting record: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("committing transaction: %w", err)
	}

	return nil
}

func (a *App) createTableFromHeader(ctx context.Context, tableName string, header []string) error {
	// Build column definitions (all TEXT)
	columns := make([]string, len(header))
	for i, col := range header {
		columns[i] = quoteIdentifier(col) + " TEXT"
	}

	// Create table
	query := fmt.Sprintf(
		`CREATE TABLE IF NOT EXISTS %s (%s)`,
		quoteIdentifier(tableName),
		strings.Join(columns, ", "),
	)

	_, err := a.DB.ExecContext(ctx, query)
	if err != nil {
		return fmt.Errorf("creating table: %w", err)
	}

	return nil
}

// quoteIdentifier safely quotes SQL identifiers.
func quoteIdentifier(name string) string {
	// Replace any quotes in the identifier with doubled quotes
	return `"` + strings.ReplaceAll(name, `"`, `""`) + `"`
}

// stripBOMReader wraps a reader and strips UTF-8 BOM if present.
func stripBOMReader(r io.Reader) io.Reader {
	br := bufio.NewReader(r)
	if peek, _ := br.Peek(3); len(peek) >= 3 && peek[0] == 0xef && peek[1] == 0xbb && peek[2] == 0xbf {
		_, _ = br.Discard(3)
	}
	return br
}

const joinQuery = `
WITH aks_rg as (
SELECT DISTINCT
    LOWER(SUBSTR(ID, 1, 
        (INSTR(ID, '/resourceGroups/') + LENGTH('/resourceGroups/')) + 
        INSTR(SUBSTR(ID, INSTR(ID, '/resourceGroups/') + LENGTH('/resourceGroups/')), '/') - 2
    )) AS rg_path,
    Date
FROM aks_splits
WHERE ID LIKE '/subscriptions/%'
)
SELECT
    CASE 
        WHEN s.Fraction IS NULL THEN '__unallocated__'
        ELSE s.Name
    END AS Name,
    CASE 
        WHEN s.Fraction IS NULL THEN '__unallocated__'
        ELSE s.Kind
    END AS Kind,
    CASE 
        WHEN s.Fraction IS NULL THEN '__unallocated__'
        ELSE s.SplitBucket
    END AS SplitBucket,
    COALESCE(s.Fraction, 1) AS Fraction,
    COALESCE(s.SplitKey, '{}') AS SplitKey,
    CAST(c.UsageQuantity AS DECIMAL) * CAST(COALESCE(s.Fraction, 1) AS DECIMAL) AS UsageQuantity,
    CAST(c.ResourceRate AS DECIMAL) * CAST(COALESCE(s.Fraction, 1) AS DECIMAL) AS ResourceRate,
    CAST(c.PreTaxCost AS DECIMAL) * CAST(COALESCE(s.Fraction, 1) AS DECIMAL) AS PreTaxCost,
	c.UsageDateTime as Date,
    c.SubscriptionGuid,
    c.ResourceGroup,
    c.ResourceLocation,
    c.MeterCategory,
    c.MeterSubCategory,
    c.MeterId,
    c.MeterName,
    c.MeterRegion,
    c.ConsumedService,
    c.ResourceType,
    c.InstanceID,
    c.Tags,
    c.OfferId,
    c.AdditionalInfo,
    c.ServiceInfo1,
    c.ServiceInfo2,
    c.ServiceName,
    c.ServiceTier,
    c.Currency,
    c.UnitOfMeasure
FROM cost_management c
INNER JOIN aks_rg r ON LOWER(c.InstanceID) LIKE r.rg_path || '%' AND c.UsageDateTime = r.Date -- Exclude non-AKS resources
LEFT JOIN aks_splits s ON LOWER(s.ID) = LOWER(c.InstanceID) AND c.UsageDateTime = s.Date
`

func (a *App) JoinData(ctx context.Context) (*os.File, error) {
	tmpFile, err := os.CreateTemp("", "joined_data_*.csv")
	if err != nil {
		return nil, fmt.Errorf("creating temp file: %w", err)
	}

	// Ensure cleanup on error
	success := false
	defer func() {
		if !success {
			_ = tmpFile.Close()
			_ = os.Remove(tmpFile.Name())
		}
	}()

	if err := a.writeJoinedData(ctx, tmpFile); err != nil {
		return nil, err
	}

	// Seek to beginning for reading
	if _, err := tmpFile.Seek(0, 0); err != nil {
		return nil, fmt.Errorf("seeking to beginning: %w", err)
	}

	success = true
	return tmpFile, nil
}

func (a *App) writeJoinedData(ctx context.Context, w io.Writer) error {
	rows, err := a.DB.QueryContext(ctx, joinQuery)
	if err != nil {
		return fmt.Errorf("executing join query: %w", err)
	}
	defer func() { _ = rows.Close() }()

	columns, err := rows.Columns()
	if err != nil {
		return fmt.Errorf("getting columns: %w", err)
	}

	csvWriter := csv.NewWriter(w)

	// Write header
	if err := csvWriter.Write(columns); err != nil {
		return fmt.Errorf("writing header: %w", err)
	}

	// Process rows
	if err := a.writeRows(rows, csvWriter, len(columns)); err != nil {
		return err
	}

	csvWriter.Flush()
	if err := csvWriter.Error(); err != nil {
		return fmt.Errorf("flushing writer: %w", err)
	}

	return nil
}

func (a *App) writeRows(rows *sql.Rows, writer *csv.Writer, columnCount int) error {
	values := make([]sql.RawBytes, columnCount)
	scanArgs := make([]interface{}, columnCount)
	for i := range values {
		scanArgs[i] = &values[i]
	}

	record := make([]string, columnCount)

	for rows.Next() {
		if err := rows.Scan(scanArgs...); err != nil {
			return fmt.Errorf("scanning row: %w", err)
		}

		// Convert to string slice
		for i, val := range values {
			if val != nil {
				record[i] = string(val)
			} else {
				record[i] = ""
			}
		}

		if err := writer.Write(record); err != nil {
			return fmt.Errorf("writing row: %w", err)
		}
	}

	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterating rows: %w", err)
	}

	return nil
}
