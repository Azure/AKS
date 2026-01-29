package main

import (
	"bytes"
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go/modules/azure/azurite"
)

func TestMain(m *testing.M) {
	code := m.Run()

	// Cleanup Azurite container after all tests
	if azuriteContainer != nil {
		_ = azuriteContainer.Terminate(context.Background())
	}

	os.Exit(code)
}

func TestApp_ProcessWithRealData(t *testing.T) {
	date := time.Date(2025, 6, 17, 0, 0, 0, 0, time.UTC) // export contains data for this date
	cfg := Config{
		CostAnalysisURL: StartServer(t, loadTestFile(t, "testdata/cost-analysis.json")),
		AzureStorageConnectionString: SetupAzuriteContainer(t, "test-container", map[string][]byte{
			"cost-management/file1.csv": loadTestFile(t, "testdata/cost-management-export.csv"),
		}),
		AzureStorageContainerName:    "test-container",
		AzureStorageAKSDataPrefix:    "cost-analysis/",
		AzureStorageCostExportPrefix: "cost-management/",
		AzureStorageResultFile:       "cost-analysis/result.csv",
		SQLiteFilePath:               "test.sqlite",
		ExportDate:                   &date,
	}

	app, err := NewApp(cfg)
	require.NoError(t, err)
	err = app.Process(context.Background())
	require.NoError(t, err)
	content := downloadResult(t, app)

	lines := strings.Split(string(content), "\n")
	assert.Equal(t, 169, len(lines))

	// Check that header contains required columns (order may vary)
	header := lines[0]
	requiredColumns := []string{"Name", "Kind", "SplitBucket", "Fraction", "SplitKey", "UsageQuantity", "PreTaxCost", "SubscriptionGuid", "InstanceId"}
	for _, col := range requiredColumns {
		assert.Contains(t, header, col, "header missing required column")
	}

	assert.Greater(t, len(lines[1]), 1000, "expect to have more than 1000 characters of data")
}

func TestApp_Process(t *testing.T) {
	type testData struct {
		name            string
		costAgentData   []byte
		blobStorageData map[string][]byte
		expectedRows    int
		expectedFields  []string // fields that should appear in data rows
		headerFields    []string // fields that should appear in header
	}
	date := time.Date(2025, 6, 18, 0, 0, 0, 0, time.UTC)
	innerTest := func(t *testing.T, td testData) {
		t.Helper()
		cfg := Config{
			CostAnalysisURL:              StartServer(t, td.costAgentData),
			AzureStorageConnectionString: SetupAzuriteContainer(t, "test-container", td.blobStorageData),
			AzureStorageContainerName:    "test-container",
			AzureStorageAKSDataPrefix:    "cost-analysis/",
			AzureStorageCostExportPrefix: "cost-management/",
			AzureStorageResultFile:       "cost-analysis/result.csv",
			SQLiteFilePath:               "test.sqlite",
			ExportDate:                   &date,
		}

		app, err := NewApp(cfg)
		require.NoError(t, err)

		err = app.Process(context.Background())
		require.NoError(t, err)

		content := downloadResult(t, app)
		lines := strings.Split(strings.TrimSpace(string(content)), "\n")

		assert.Equal(t, td.expectedRows, len(lines), "unexpected number of rows")

		// Check header contains required columns
		for _, col := range td.headerFields {
			assert.Contains(t, lines[0], col, "header missing required column")
		}

		// Check data rows contain expected fields
		if len(lines) > 1 {
			for _, field := range td.expectedFields {
				assert.Contains(t, lines[1], field, "data row missing expected field")
			}
		}
	}

	testFunc := func(td testData) func(t *testing.T) {
		return func(t *testing.T) {
			t.Helper()
			innerTest(t, td)
		}
	}

	t.Run("Simple test", testFunc(testData{
		name: "Simple test",
		costAgentData: []byte(`
{
    "Resources": [
        {
            "ID": "/subscriptions/test-subscription/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachineScaleSets/aks-nodepool1-37076539-vmss",
            "Name": "aks-nodepool1-37076539-vmss",
            "Kind": "compute",
            "Splits": [
                {
                    "Fraction": 0.2,
                    "SplitKey": {
                        "namespace": "kube-system",
                        "object_kind": "deployment",
                        "object_name": "metrics-server"
                    },
                    "SplitBucket": "usage"
                },
                {
                    "Fraction": 0.8,
                    "SplitKey": {},
                    "SplitBucket": "idle"
                }
            ]
        }
    ]
}
		`),
		blobStorageData: map[string][]byte{
			"cost-management/file1.csv": []byte(`
SubscriptionGuid,ResourceGroup,ResourceLocation,UsageDateTime,MeterCategory,MeterSubCategory,MeterId,MeterName,MeterRegion,UsageQuantity,ResourceRate,PreTaxCost,ConsumedService,ResourceType,InstanceId,Tags,OfferId,AdditionalInfo,ServiceInfo1,ServiceInfo2,ServiceName,ServiceTier,Currency,UnitOfMeasure
SubscriptionGuid,ResourceGroup,ResourceLocation,2025-06-18,MeterCategory,MeterSubCategory,MeterId,MeterName,MeterRegion,UsageQuantity,ResourceRate,100.0,ConsumedService,ResourceType,/subscriptions/test-subscription/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachineScaleSets/aks-nodepool1-37076539-vmss,Tags,OfferId,AdditionalInfo,ServiceInfo1,ServiceInfo2,ServiceName,ServiceTier,Currency,UnitOfMeasure
`),
		},
		expectedRows:   3,
		headerFields:   []string{"Name", "Kind", "SplitBucket", "Fraction", "SplitKey", "PreTaxCost", "InstanceId"},
		expectedFields: []string{"aks-nodepool1-37076539-vmss", "compute", "0.200000", "kube-system"},
	}))
}

func TestJoinData(t *testing.T) {
	tests := []struct {
		name           string
		costAgentData  []byte
		costMgmtData   map[string][]byte
		expectedRows   int
		expectedFields []string
		gzipped        bool
	}{
		{
			name: "matching resources",
			costAgentData: []byte(`{
				"Resources": [{
					"ID": "/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss",
					"Name": "vmss",
					"Kind": "compute",
					"Splits": [{
						"Fraction": 0.5,
						"SplitKey": {"namespace": "default"},
						"SplitBucket": "usage"
					}]
				}]
			}`),
			costMgmtData: map[string][]byte{
				"cost-management/file1.csv": []byte(`SubscriptionGuid,ResourceGroup,ResourceLocation,UsageDateTime,MeterCategory,MeterSubCategory,MeterId,MeterName,MeterRegion,UsageQuantity,ResourceRate,PreTaxCost,ConsumedService,ResourceType,InstanceId,Tags,OfferId,AdditionalInfo,ServiceInfo1,ServiceInfo2,ServiceName,ServiceTier,Currency,UnitOfMeasure
test-guid,rg,westus,2025-06-18,Virtual Machines,Standard,meter-id,VM,westus,1,10,10,Microsoft.Compute,Microsoft.Compute/virtualMachineScaleSets,/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss,{},offer-id,info,,,VM,Standard,USD,Hour`),
			},
			expectedRows:   2, // header + 1 data row
			expectedFields: []string{"vmss", "compute", "usage", "0.500000"},
		},
		{
			name: "unallocated cost",
			costAgentData: []byte(`{
				"Resources": [{
					"ID": "/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss",
					"Name": "vmss",
					"Kind": "compute",
					"Splits": [{
						"Fraction": 0.3,
						"SplitKey": {"namespace": "default"},
						"SplitBucket": "usage"
					}]
				}]
			}`),
			costMgmtData: map[string][]byte{
				"cost-management/file1.csv": []byte(`SubscriptionGuid,ResourceGroup,ResourceLocation,UsageDateTime,MeterCategory,MeterSubCategory,MeterId,MeterName,MeterRegion,UsageQuantity,ResourceRate,PreTaxCost,ConsumedService,ResourceType,InstanceId,Tags,OfferId,AdditionalInfo,ServiceInfo1,ServiceInfo2,ServiceName,ServiceTier,Currency,UnitOfMeasure
test-guid,rg,westus,2025-06-18,Virtual Machines,Standard,meter-id,VM,westus,1,10,10,Microsoft.Compute,Microsoft.Compute/virtualMachineScaleSets,/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/other-vmss,{},offer-id,info,,,VM,Standard,USD,Hour`),
			},
			expectedRows:   2, // header + 1 unallocated row (different resource ID)
			expectedFields: []string{"__unallocated__", "1"},
		},
		{
			name: "empty cost management file",
			costAgentData: []byte(`{
				"Resources": [{
					"ID": "/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss",
					"Name": "vmss",
					"Kind": "compute",
					"Splits": [{
						"Fraction": 0.5,
						"SplitKey": {"namespace": "default"},
						"SplitBucket": "usage"
					}]
				}]
			}`),
			costMgmtData: map[string][]byte{
				"cost-management/empty.csv": []byte(""),
			},
			expectedRows:   1, // header only
			expectedFields: []string{},
		},
		{
			name: "multiple cost management files",
			costAgentData: []byte(`{
				"Resources": [{
					"ID": "/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss1",
					"Name": "vmss1",
					"Kind": "compute",
					"Splits": [{
						"Fraction": 0.5,
						"SplitKey": {"namespace": "default"},
						"SplitBucket": "usage"
					}]
				}]
			}`),
			costMgmtData: map[string][]byte{
				"cost-management/file1.csv": []byte(`SubscriptionGuid,ResourceGroup,ResourceLocation,UsageDateTime,MeterCategory,MeterSubCategory,MeterId,MeterName,MeterRegion,UsageQuantity,ResourceRate,PreTaxCost,ConsumedService,ResourceType,InstanceId,Tags,OfferId,AdditionalInfo,ServiceInfo1,ServiceInfo2,ServiceName,ServiceTier,Currency,UnitOfMeasure
test-guid,rg,westus,2025-06-18,Virtual Machines,Standard,meter-id,VM,westus,1,5,5,Microsoft.Compute,Microsoft.Compute/virtualMachineScaleSets,/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss1,{},offer-id,info,,,VM,Standard,USD,Hour`),
				"cost-management/file2.csv": []byte(`SubscriptionGuid,ResourceGroup,ResourceLocation,UsageDateTime,MeterCategory,MeterSubCategory,MeterId,MeterName,MeterRegion,UsageQuantity,ResourceRate,PreTaxCost,ConsumedService,ResourceType,InstanceId,Tags,OfferId,AdditionalInfo,ServiceInfo1,ServiceInfo2,ServiceName,ServiceTier,Currency,UnitOfMeasure
test-guid,rg,westus,2025-06-18,Virtual Machines,Standard,meter-id2,VM,westus,2,3,6,Microsoft.Compute,Microsoft.Compute/virtualMachineScaleSets,/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss1,{},offer-id,info,,,VM,Standard,USD,Hour`),
			},
			expectedRows:   3, // header + 2 data rows
			expectedFields: []string{"vmss1", "compute", "usage", "0.500000"},
		},
		{
			name: "gzipped cost management file",
			costAgentData: []byte(`{
				"Resources": [{
					"ID": "/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss",
					"Name": "vmss",
					"Kind": "compute",
					"Splits": [{
						"Fraction": 0.8,
						"SplitKey": {"namespace": "kube-system"},
						"SplitBucket": "usage"
					}]
				}]
			}`),
			costMgmtData:   map[string][]byte{},
			expectedRows:   2, // header + 1 data row
			expectedFields: []string{"vmss", "compute", "usage", "0.800000"},
			gzipped:        true,
		},
		{
			// Modern EA schema (2024-08-01)
			// https://learn.microsoft.com/en-us/azure/cost-management-billing/dataset-schema/cost-usage-details-ea
			name: "Modern EA schema (2024)",
			costAgentData: []byte(`{
				"Resources": [{
					"ID": "/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss",
					"Name": "vmss",
					"Kind": "compute",
					"Splits": [{
						"Fraction": 0.5,
						"SplitKey": {"namespace": "default"},
						"SplitBucket": "usage"
					}]
				}]
			}`),
			costMgmtData: map[string][]byte{
				"cost-management/file1.csv": []byte(`SubscriptionId,ResourceGroup,ResourceLocation,Date,MeterCategory,MeterSubCategory,MeterId,MeterName,MeterRegion,Quantity,EffectivePrice,CostInBillingCurrency,ConsumedService,ResourceId,Tags,OfferId,AdditionalInfo,ServiceInfo1,ServiceInfo2,ServiceName,ServiceTier,Currency,UnitOfMeasure
test-guid,rg,westus,2025-06-18,Virtual Machines,Standard,meter-id,VM,westus,2,10,20,Microsoft.Compute,/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss,{},offer-id,info,,,VM,Standard,USD,Hour`),
			},
			expectedRows:   2,
			expectedFields: []string{"vmss", "compute", "usage", "0.500000", "test-guid", "westus"},
		},
		{
			// MCA schema (camelCase) - applies to MCA, MCA Partner, and CSP Subscription
			// https://learn.microsoft.com/en-us/azure/cost-management-billing/dataset-schema/cost-usage-details-mca
			// https://learn.microsoft.com/en-us/azure/cost-management-billing/dataset-schema/cost-usage-details-mca-partner
			// https://learn.microsoft.com/en-us/azure/cost-management-billing/dataset-schema/cost-usage-details-mca-partner-subscription
			name: "MCA schema (camelCase)",
			costAgentData: []byte(`{
				"Resources": [{
					"ID": "/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss",
					"Name": "vmss",
					"Kind": "compute",
					"Splits": [{
						"Fraction": 0.6,
						"SplitKey": {"namespace": "kube-system"},
						"SplitBucket": "usage"
					}]
				}]
			}`),
			costMgmtData: map[string][]byte{
				"cost-management/file1.csv": []byte(`SubscriptionId,resourceGroupName,resourceLocation,date,meterCategory,meterSubCategory,meterId,meterName,meterRegion,quantity,effectivePrice,costInBillingCurrency,consumedService,ResourceId,tags,additionalInfo,serviceInfo1,serviceInfo2,billingCurrency,unitOfMeasure
test-guid,rg,westus,2025-06-18,Virtual Machines,Standard,meter-id,VM,westus,2,5,10,Microsoft.Compute,/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss,{},info,,,USD,Hour`),
			},
			expectedRows:   2,
			expectedFields: []string{"vmss", "compute", "usage", "0.600000", "test-guid", "westus"},
		},
		{
			// FOCUS schema (FinOps Open Cost and Usage Specification)
			// https://learn.microsoft.com/en-us/azure/cost-management-billing/dataset-schema/cost-usage-details-focus
			name: "FOCUS schema",
			costAgentData: []byte(`{
				"Resources": [{
					"ID": "/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss",
					"Name": "vmss",
					"Kind": "compute",
					"Splits": [{
						"Fraction": 0.4,
						"SplitKey": {"namespace": "monitoring"},
						"SplitBucket": "usage"
					}]
				}]
			}`),
			costMgmtData: map[string][]byte{
				"cost-management/file1.csv": []byte(`BilledCost,BillingCurrency,ChargePeriodStart,ChargePeriodEnd,ConsumedQuantity,ConsumedUnit,ContractedCost,EffectiveCost,ListCost,ListUnitPrice,PricingQuantity,PricingUnit,ResourceId,ResourceName,ResourceType,ServiceName,SubAccountId,SubAccountName,Tags,x_ResourceGroupName
10,USD,2025-06-18,2025-06-19,2,Hours,10,10,12,6,2,Hour,/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss,vmss,Microsoft.Compute/virtualMachineScaleSets,Virtual Machines,test-sub,Test Subscription,{},rg`),
			},
			expectedRows:   2,
			expectedFields: []string{"vmss", "compute", "usage", "0.400000", "USD", "Hours"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			date := time.Date(2025, 6, 18, 0, 0, 0, 0, time.UTC)

			blobData := tt.costMgmtData
			if tt.gzipped {
				// Create gzipped version of the first cost management file
				csvData := []byte(`SubscriptionGuid,ResourceGroup,ResourceLocation,UsageDateTime,MeterCategory,MeterSubCategory,MeterId,MeterName,MeterRegion,UsageQuantity,ResourceRate,PreTaxCost,ConsumedService,ResourceType,InstanceId,Tags,OfferId,AdditionalInfo,ServiceInfo1,ServiceInfo2,ServiceName,ServiceTier,Currency,UnitOfMeasure
test-guid,rg,westus,2025-06-18,Virtual Machines,Standard,meter-id,VM,westus,1,10,10,Microsoft.Compute,Microsoft.Compute/virtualMachineScaleSets,/subscriptions/test/resourceGroups/rg/providers/Microsoft.Compute/virtualMachineScaleSets/vmss,{},offer-id,info,,,VM,Standard,USD,Hour`)
				gzippedData := gzipData(t, csvData)
				blobData = map[string][]byte{
					"cost-management/file1.csv.gz": gzippedData,
				}
			}

			cfg := Config{
				CostAnalysisURL:              StartServer(t, tt.costAgentData),
				AzureStorageConnectionString: SetupAzuriteContainer(t, "test-join-container", blobData),
				AzureStorageContainerName:    "test-join-container",
				AzureStorageAKSDataPrefix:    "cost-analysis/",
				AzureStorageCostExportPrefix: "cost-management/",
				AzureStorageResultFile:       "cost-analysis/result.csv",
				SQLiteFilePath:               "test.sqlite",
				ExportDate:                   &date,
				Timeout:                      time.Minute,
			}

			app, err := NewApp(cfg)
			require.NoError(t, err)

			err = app.Process(context.Background())
			require.NoError(t, err)

			content := downloadResult(t, app)
			lines := strings.Split(strings.TrimSpace(string(content)), "\n")

			// Check number of rows
			assert.Equal(t, tt.expectedRows, len(lines), "unexpected number of result rows")

			// Check that expected fields appear in the result
			if len(lines) > 1 && len(tt.expectedFields) > 0 {
				dataRow := lines[1]
				for _, field := range tt.expectedFields {
					assert.Contains(t, dataRow, field, "expected field not found in result")
				}
			}
		})
	}
}

func TestConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  Config
		wantErr bool
	}{
		{"missing container", Config{}, true},
		{"missing storage config", Config{AzureStorageContainerName: "test"}, true},
		{"valid config", Config{AzureStorageContainerName: "test", AzureStorageBlobName: "test", Timeout: time.Minute}, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if tt.wantErr {
				require.Error(t, err)
			} else {
				require.NoError(t, err)
			}
		})
	}
}

func downloadResult(t *testing.T, app *App) []byte {
	t.Helper()

	response, err := app.BlobClient.DownloadStream(
		context.Background(),
		app.Config.AzureStorageContainerName,
		app.Config.AzureStorageResultFile,
		nil,
	)
	require.NoError(t, err, "failed to download result blob")
	defer func() { _ = response.Body.Close() }()

	content, err := io.ReadAll(response.Body)
	require.NoError(t, err, "failed to read blob content")

	return content
}

var (
	azuriteContainer *azurite.Container
	azuriteURL       string
	azuriteConnStr   string
)

func StartAzuriteOnce(t *testing.T) {
	t.Helper()

	if azuriteContainer != nil {
		return
	}

	var err error
	azuriteContainer, err = azurite.Run(
		context.Background(),
		"mcr.microsoft.com/azure-storage/azurite:3.34.0",
	)
	require.NoError(t, err, "failed to start Azurite container")

	azuriteURL, err = azuriteContainer.BlobServiceURL(context.Background())
	require.NoError(t, err)

	azuriteConnStr = fmt.Sprintf("DefaultEndpointsProtocol=http;AccountName=%s;AccountKey=%s;BlobEndpoint=%s/%s;",
		azurite.AccountName,
		azurite.AccountKey,
		azuriteURL,
		azurite.AccountName)
}

func SetupAzuriteContainer(t *testing.T, containerName string, data map[string][]byte) string {
	t.Helper()

	StartAzuriteOnce(t)

	blobClient, err := azblob.NewClientFromConnectionString(azuriteConnStr, nil)
	require.NoError(t, err, "failed to create blob client")

	// Delete container if it exists (to ensure clean state)
	_, _ = blobClient.DeleteContainer(context.Background(), containerName, nil)

	// Create new container
	_, err = blobClient.CreateContainer(context.Background(), containerName, nil)
	require.NoError(t, err, "failed to create container")

	// Upload test data
	for path, content := range data {
		_, err := blobClient.UploadBuffer(context.Background(), containerName, path, content, nil)
		require.NoError(t, err, "failed to upload blob: %s", path)
	}

	return azuriteConnStr
}

func StartServer(t *testing.T, content []byte) string {
	t.Helper()

	// Create a test server that returns the provided content
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, err := w.Write(content)
		require.NoError(t, err)
	}))

	// Ensure server is closed when test completes
	t.Cleanup(func() {
		server.Close()
	})

	return server.URL
}

func loadTestFile(t *testing.T, path string) []byte {
	t.Helper()
	content, err := os.ReadFile(path)
	require.NoError(t, err, "failed to read test file: %s", path)
	return content
}

func gzipData(t *testing.T, data []byte) []byte {
	t.Helper()
	var buf bytes.Buffer
	gw := gzip.NewWriter(&buf)
	_, err := gw.Write(data)
	require.NoError(t, err)
	err = gw.Close()
	require.NoError(t, err)
	return buf.Bytes()
}
