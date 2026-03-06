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
// This ensures an agenda is always displayed, even before a new month's file is added.
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
      "Every 3rd Wednesday. 8 AM Pacific Time / 11 AM Eastern Time / 4 PM GMT / 9:30 PM IST",
    icsHref: "/webinars/calendar/AKS-Community-Roadmap-Call-US.ics",
    joinHref: "https://aka.ms/aks/communitycalls-us/roadmap/joinnow",
  },
];

// --- Markdown Parsing Logic -----------------------------------------------

function parseAgendaMarkdown(raw: string): {
  month?: string;
  items: AgendaItem[];
} {
  let month: string | undefined;
  let content = raw.trim();
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
      if (current) items.push(current);
      current = { title: headingMatch[1].trim(), _lines: [] };
      continue;
    }
    if (!current) continue;
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
    const maxLookback = 6;
    let year = now.getFullYear();
    let monthIndex = now.getMonth();
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
            setState({ items: [], loading: false });
            return;
          }
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

// --- Components ------------------------------------------------------------

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
        <Heading as="h1">AKS Community Calls</Heading>
        <p className={styles.heroSubtitle}>
          Monthly public sessions to connect with the AKS product team, learn roadmap updates, and share feature deep dives.
        </p>
        <div className={styles.heroButtons}>
          <Link
            className="button button--primary button--sm"
            to="https://www.youtube.com/playlist?list=PLc3Ep462vVYu0eMSiORonzj3utqYu285z"
          >
            Past Recordings
          </Link>
          <Link
            className="button button--outline button--sm"
            to="https://github.com/orgs/Azure/projects/685/views/1"
          >
            Feature Roadmap
          </Link>
        </div>
      </div>
    </div>
  );
}

// Returns the upcoming 3rd Wednesday (or today if today is the 3rd Wednesday).
function getNextThirdWednesday(): Date {
  // Compute everything relative to PST (UTC-8) so the result is
  // consistent regardless of the server's or visitor's local timezone.
  const PST_OFFSET_MS = 8 * 60 * 60 * 1000; // UTC-8
  const nowUTC = Date.now();
  // Current date/time expressed as if the clock were in PST
  const nowPST = new Date(nowUTC - PST_OFFSET_MS);

  const year = nowPST.getUTCFullYear();
  const month = nowPST.getUTCMonth();
  const today = nowPST.getUTCDate();

  const thirdWed = (y: number, m: number): Date => {
    // First day of the month in PST (represented as UTC for arithmetic)
    const first = new Date(Date.UTC(y, m, 1));
    // Day-of-week for the 1st (0 = Sun … 6 = Sat); Wednesday = 3
    const offset = (3 - first.getUTCDay() + 7) % 7; // days until first Wednesday
    // 3rd Wednesday = first Wednesday + 14 days
    return new Date(Date.UTC(y, m, 1 + offset + 14));
  };

  const candidate = thirdWed(year, month);
  // If the 3rd Wednesday this month is still today or in the future (in PST), use it
  if (candidate.getUTCDate() >= today && candidate.getUTCMonth() === month) {
    // Return as a plain local-midnight Date so formatDate() keeps working
    return new Date(candidate.getUTCFullYear(), candidate.getUTCMonth(), candidate.getUTCDate());
  }
  // Otherwise, move to next month
  const nextMonth = month + 1;
  const result = thirdWed(
    nextMonth > 11 ? year + 1 : year,
    nextMonth % 12,
  );
  return new Date(result.getUTCFullYear(), result.getUTCMonth(), result.getUTCDate());
}

function formatDate(d: Date): string {
  const months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
  ];
  return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
}

function AgendaSection(): ReactNode {
  const { month, items, loading } = useMonthlyAgenda();
  const label = month || "Latest";
  const empty = !loading && items.length === 0;
  const tz = timezoneCalls[0];
  const nextDate = getNextThirdWednesday();
  return (
    <section className={styles.agendaSection}>
      {tz && (
        <div className={styles.callStrip}>
          <div className={styles.callStripInfo}>
            <span className={styles.callStripLabel}>Next call</span>
            <span className={styles.callStripSchedule}>
              {formatDate(nextDate)}
              <br />
              {tz.schedule}
            </span>
          </div>
          <div className={styles.callStripActions}>
            <a href={tz.icsHref} className={styles.calendarLink}>
              Add to calendar
            </a>
            <Link
              className={`button button--primary button--sm ${styles.joinBtn}`}
              to={tz.joinHref}
            >
              Join Now
            </Link>
          </div>
        </div>
      )}
      <div className={styles.sectionHeader}>
        <Heading as="h2">
          Agenda - {label}
        </Heading>
        {loading && (
          <span className={styles.loadingBadge}>loading&hellip;</span>
        )}
      </div>
      {empty && (
        <p className={styles.emptyState}>
          No agenda has been published yet. Once an agenda file is added it
          appears here automatically.
        </p>
      )}
      {!empty && (
        <div className={styles.agendaGrid}>
          {items.map((item, idx) => (
            <div
              key={idx}
              className={`${styles.agendaCard} ${
                item.featured ? styles.featured : ""
              }`.trim()}
            >
              <h3 className={styles.agendaCardTitle}>{item.title}</h3>
              {item.presenter && (
                <p className={styles.agendaPresenter}>{item.presenter}</p>
              )}
              {item.description && (
                <p className={styles.agendaDescription}>{item.description}</p>
              )}
              {item.bullets && (
                <ul className={styles.agendaBullets}>
                  {item.bullets.map((b, i) => (
                    <li key={i}>{b}</li>
                  ))}
                </ul>
              )}
            </div>
          ))}
        </div>
      )}
    </section>
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
        <AgendaSection />
      </main>
    </Layout>
  );
}
