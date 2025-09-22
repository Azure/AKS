// Maintenance overview:
// Agenda content and its month label are sourced exclusively from markdown files:
//   /website/static/webinars/agenda/YYYY-MM.md
// Frontmatter must include: month: Month YYYY
// Each agenda section uses a second-level heading (##) followed by optional lines:
//   Presenter: Name and title
//   Description: Text
//   Featured: true
//   - bullet point text (repeatable for bullets)
// If the current month file is missing, the code steps backwards (up to a
// configurable number of prior months) and uses the most recent available file.
// This ensures an agenda is always displayed, even before a new month’s file is added.
// Timezone call card data is defined in the constant `timezoneCalls` below.

import type { ReactNode } from "react";
import React, { useEffect, useState } from "react";
import Link from "@docusaurus/Link";
import Layout from "@theme/Layout";
import Heading from "@theme/Heading";
import ExecutionEnvironment from "@docusaurus/ExecutionEnvironment";
import styles from "./webinars.module.css";

// --- Data Types ------------------------------------------------------------
interface AgendaItem {
  title: string;
  presenter?: string;
  bullets?: string[];
  description?: string;
  featured?: boolean;
}

interface MonthlyAgendaResult {
  month?: string;
  items: AgendaItem[];
  loading: boolean;
}

interface TimezoneCall {
  region: string;
  schedule: string; // contains <br/>
  icsHref: string;
  joinHref: string;
}

// Static timezone call info (edit here if schedules/links change)
const timezoneCalls: TimezoneCall[] = [
  {
    region: "Americas, Europe",
    schedule:
      "3rd Wednesday<br/>every month<br/><br/>8 AM PST<br/>11 AM EST<br/>3 PM GMT",
    icsHref: "/webinars/Recurring-AKS-Community-Roadmap-Call.ics",
    joinHref: "https://aka.ms/aks/communitycalls-us/roadmap/joinnow",
  },
  {
    region: "India, APAC, ANZ",
    schedule:
      "4th Wednesday<br/>every month<br/><br/>10:30 AM IST<br/>1 PM SST<br/>3 PM AEST",
    icsHref: "/webinars/AKS-Community-Roadmap-Call-APAC.ics",
    joinHref: "https://aka.ms/aks/communitycalls-apac/roadmap/joinnow",
  },
];

// --- Markdown Parsing Logic -----------------------------------------------
// The markdown file structure (static/webinars/agenda/YYYY-MM.md) is expected to have:
// Frontmatter: ---\nmonth: Month YYYY\n--- then sections introduced by `## Heading`.
// Within each section optional lines:
//   Presenter: Name
//   Description: Text
//   Featured: true
//   - bullet point
// Blank lines are ignored.

function parseAgendaMarkdown(raw: string): {
  month?: string;
  items: AgendaItem[];
} {
  let month: string | undefined;
  let content = raw.trim();
  // Extract frontmatter
  if (content.startsWith("---")) {
    const end = content.indexOf("\n---", 3);
    if (end !== -1) {
      const front = content.substring(3, end).trim();
      content = content.substring(end + 4).trim();
      front.split(/\r?\n/).forEach((line) => {
        const m = line.match(/^month:\s*(.+)$/i);
        if (m) month = m[1].trim();
      });
    }
  }

  const lines = content.split(/\r?\n/);
  interface WorkingItem extends AgendaItem {
    _lines: string[];
  }
  const items: WorkingItem[] = [];
  let current: WorkingItem | null = null;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;
    const headingMatch = line.match(/^##\s+(.+)$/);
    if (headingMatch) {
      // push previous
      if (current) items.push(current);
      current = { title: headingMatch[1].trim(), _lines: [] };
      continue;
    }
    if (!current) continue; // ignore content before first heading
    current._lines.push(line);
  }
  if (current) items.push(current);

  const finalized: AgendaItem[] = items.map((w) => {
    const bullets: string[] = [];
    let presenter: string | undefined;
    let description: string | undefined;
    let featured = false;
    w._lines.forEach((l) => {
      if (/^Presenter:/i.test(l))
        presenter = l.replace(/^Presenter:/i, "").trim();
      else if (/^Description:/i.test(l))
        description = l.replace(/^Description:/i, "").trim();
      else if (/^Featured:/i.test(l)) featured = /true/i.test(l.split(":")[1]);
      else if (/^-\s+/.test(l)) bullets.push(l.replace(/^-\s+/, ""));
    });
    const item: AgendaItem = { title: w.title };
    if (presenter) item.presenter = presenter;
    if (description) item.description = description;
    if (bullets.length) item.bullets = bullets;
    if (featured) item.featured = true;
    return item;
  });
  return { month, items: finalized };
}

// Hook to load agenda markdown for current month, falling back to latest prior month.
function useMonthlyAgenda(): MonthlyAgendaResult {
  const [state, setState] = useState<MonthlyAgendaResult>({
    items: [],
    loading: true,
  });

  useEffect(() => {
    if (!ExecutionEnvironment.canUseDOM) {
      setState({ items: [], loading: false });
      return;
    }
    const now = new Date();
    let attempts = 0;
    const maxLookback = 6; // months
    let year = now.getFullYear();
    let monthIndex = now.getMonth(); // 0-based
    let cancelled = false;

    const tryFetch = () => {
      const monthStr = `${year}-${String(monthIndex + 1).padStart(2, "0")}`;
      const url = `/webinars/agenda/${monthStr}.md`;
      fetch(url, { cache: "no-cache" })
        .then(async (res) => {
          if (!res.ok)
            throw new Error(`Agenda markdown not found (${res.status})`);
          return res.text();
        })
        .then((text) => {
          if (cancelled) return;
          const parsed = parseAgendaMarkdown(text);
          setState({
            items: parsed.items,
            month: parsed.month,
            loading: false,
          });
        })
        .catch(() => {
          if (cancelled) return;
          attempts++;
          if (attempts > maxLookback) {
            // Give up: show empty state.
            setState({ items: [], loading: false });
            return;
          }
          // Move back one month
          monthIndex -= 1;
          if (monthIndex < 0) {
            monthIndex = 11;
            year -= 1;
          }
          tryFetch();
        });
    };
    tryFetch();
    return () => {
      cancelled = true;
    };
  }, []);
  return state;
}

function Hero(): ReactNode {
  const bannerUrl = "/webinars/AKS-CommunityCalls-Banner.png";
  return (
    <div
      className={styles.heroOverlay}
      style={{ backgroundImage: `url(${bannerUrl})` }}
      role="img"
      aria-label="AKS Community Calls Banner"
    >
      <div className={styles.heroOverlayInner}>
        <Heading as="h1">AKS - Community Calls</Heading>
        <div className={styles.heroButtons}>
          <Link
            className="button button--primary button--lg"
            to="https://www.youtube.com/playlist?list=PLc3Ep462vVYu0eMSiORonzj3utqYu285z"
          >
            Past Call Recordings
          </Link>
        </div>
      </div>
    </div>
  );
}

function Intro(): ReactNode {
  return (
    <div className={styles.introBox}>
      <p className="margin--none">
        Welcome to the AKS Community Calls! These sessions foster direct
        interaction between our product teams and the AKS community. Engage with
        our teams, hear the latest updates, and gain insights into the product’s
        development. Join our monthly public calls to discuss the product
        roadmap, provide feedback, and learn from others’ experiences with AKS.
        Check out the{" "}
        <Link to="https://github.com/orgs/Azure/projects/685/views/1">
          public feature roadmap
        </Link>{" "}
        for details on features in development, public preview, and general
        availability.
      </p>
    </div>
  );
}

function AgendaPanel(): ReactNode {
  const { month, items, loading } = useMonthlyAgenda();
  const label = month || "Latest";
  const empty = !loading && items.length === 0;
  return (
    <div className={styles.panel}>
      <div className={`${styles.panelHeader} ${styles.calendar}`}>
        Agenda ({label}){" "}
        {loading && (
          <span style={{ fontSize: "0.65rem", fontWeight: 400 }}>loading…</span>
        )}
      </div>
      <div className={styles.panelBody}>
        {empty && (
          <div style={{ fontSize: "0.85rem", opacity: 0.8 }}>
            No agenda has been published yet. Once an agenda markdown file is
            added it will appear here automatically.
          </div>
        )}
        {!empty && (
          <ul className={styles.agendaList}>
            {items.map((item, idx) => (
              <li
                key={idx}
                className={`${styles.agendaItem} ${
                  item.featured ? styles.featured : ""
                }`.trim()}
              >
                <h4>{item.title}</h4>
                {item.presenter && (
                  <p>
                    <strong>{item.presenter}</strong>
                  </p>
                )}
                {item.description && (
                  <p className={styles.agendaDescription}>{item.description}</p>
                )}
                {item.bullets && (
                  <ul>
                    {item.bullets.map((b, i) => (
                      <li key={i}>{b}</li>
                    ))}
                  </ul>
                )}
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

function TimezonePanel(): ReactNode {
  return (
    <div className={styles.panel}>
      <div className={styles.panelHeader}>Join An Upcoming Call</div>
      <div className={styles.panelBody}>
        <div className={styles.timezoneCards}>
          {timezoneCalls.map((tz) => (
            <div key={tz.region} className={styles.timezoneCard}>
              <div className={styles.timezoneCardHeader}>
                <h4>{tz.region}</h4>
              </div>
              <div className={styles.timezoneCardBody}>
                <p dangerouslySetInnerHTML={{ __html: tz.schedule }} />
                <div>
                  <a href={tz.icsHref} className={styles.calendarLink}>
                    Add to my calendar
                  </a>
                </div>
                <div className={styles.timezoneButtons}>
                  <Link
                    className="button button--primary button--sm"
                    to={tz.joinHref}
                  >
                    Join
                  </Link>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function Webinars(): ReactNode {
  return (
    <Layout
      title="Community Calls"
      description="AKS Community Calls: monthly roadmap, deep dives, and Q&A sessions with the Azure Kubernetes Service team"
    >
      <Hero />
      <main>
        <Intro />
        <div className={styles.gridColumns}>
          <div className={styles.agendaColumn}>
            <AgendaPanel />
          </div>
          <div className={styles.timezoneColumn}>
            <TimezonePanel />
          </div>
        </div>
      </main>
    </Layout>
  );
}
