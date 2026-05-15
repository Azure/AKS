// Maintenance overview:
// Agenda content and its month label are sourced exclusively from markdown files:
//   Community Calls: /website/static/webinars/agenda/YYYY-MM.md (monthly files)
//   Architecture Review Hour: /website/static/webinars/agenda/architecture-review.md (single file, updated in-place)
// Frontmatter must include: month: Month YYYY (or a label for the session)
// Each agenda section uses a second-level heading (##) followed by optional lines:
//   Presenter: Name and title
//   Description: Text
//   Featured: true
//   - bullet point text (repeatable for bullets)
// Community Calls: If the current month file is missing, the code steps backwards
//   (up to 6 prior months) and uses the most recent available file.
// Architecture Review Hour: Uses a single static file that is updated whenever
//   a new session is scheduled.
// Event data is defined in the constant `eventTypes` below.

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

interface EventType {
  id: string;
  label: string;
  description: string;
  schedule: string;
  icsHref: string;
  joinHref: string;
  agendaBasePath: string;
  agendaMode: "monthly" | "static";
  getNextDate: () => Date;
  pastRecordingsHref?: string;
}

// --- Event Definitions -----------------------------------------------------

const eventTypes: EventType[] = [
  {
    id: "community-calls",
    label: "Community Calls",
    description:
      "Roadmap updates, product demos, and open Q&A with the AKS team.",
    schedule:
      "8 AM Pacific / 11 AM Eastern / 4 PM GMT / 8:30 PM IST",
    icsHref: "/webinars/calendar/AKS-Community-Roadmap-Call-US.ics",
    joinHref: "https://aka.ms/aks/communitycalls-us/roadmap/joinnow",
    agendaBasePath: "/webinars/agenda",
    agendaMode: "monthly",
    getNextDate: getNextThirdWednesday,
    pastRecordingsHref: "https://www.youtube.com/playlist?list=PLc3Ep462vVYu0eMSiORonzj3utqYu285z",
  },
  {
    id: "kube&tell-podcast",
    label: "Kube & Tell",
    description:
      "Live, community-driven podcast for Kubernetes practitioners",
    schedule:
      "8 AM Pacific / 11 AM Eastern / 4 PM GMT / 8:30 PM IST",
    icsHref: "/webinars/calendar/Kube & Tell _ Real Clusters, Real Conversations.ics",
    joinHref: "https://aka.ms/aks/architecture-review/joinnow",
    agendaBasePath: "/webinars/agenda/architecture-review.md",
    agendaMode: "static",
    getNextDate: getNextArchitectureReviewDate,
  },
];

// --- Date Helpers ----------------------------------------------------------

// Returns the upcoming 3rd Wednesday (or today if today is the 3rd Wednesday).
function getNextThirdWednesday(): Date {
  const PST_OFFSET_MS = 8 * 60 * 60 * 1000;
  const nowUTC = Date.now();
  const nowPST = new Date(nowUTC - PST_OFFSET_MS);

  const year = nowPST.getUTCFullYear();
  const month = nowPST.getUTCMonth();
  const today = nowPST.getUTCDate();

  const thirdWed = (y: number, m: number): Date => {
    const first = new Date(Date.UTC(y, m, 1));
    const offset = (3 - first.getUTCDay() + 7) % 7;
    return new Date(Date.UTC(y, m, 1 + offset + 14));
  };

  const candidate = thirdWed(year, month);
  if (candidate.getUTCDate() >= today && candidate.getUTCMonth() === month) {
    return new Date(candidate.getUTCFullYear(), candidate.getUTCMonth(), candidate.getUTCDate());
  }
  const nextMonth = month + 1;
  const result = thirdWed(
    nextMonth > 11 ? year + 1 : year,
    nextMonth % 12,
  );
  return new Date(result.getUTCFullYear(), result.getUTCMonth(), result.getUTCDate());
}

// Returns the next Architecture Review Hour date.
// Known upcoming dates: June 11, 2026. After that, assume 2nd Thursday monthly.
function getNextArchitectureReviewDate(): Date {
  const PST_OFFSET_MS = 8 * 60 * 60 * 1000;
  const nowUTC = Date.now();
  const nowPST = new Date(nowUTC - PST_OFFSET_MS);
  const todayMs = Date.UTC(nowPST.getUTCFullYear(), nowPST.getUTCMonth(), nowPST.getUTCDate());

  // Known fixed date
  const knownDate = new Date(2026, 5, 11); // June 11, 2026
  if (knownDate.getTime() >= todayMs) {
    return knownDate;
  }

  // Fallback: 2nd Thursday of each month
  const year = nowPST.getUTCFullYear();
  const month = nowPST.getUTCMonth();
  const today = nowPST.getUTCDate();

  const secondThursday = (y: number, m: number): Date => {
    const first = new Date(Date.UTC(y, m, 1));
    const offset = (4 - first.getUTCDay() + 7) % 7;
    return new Date(Date.UTC(y, m, 1 + offset + 7));
  };

  const candidate = secondThursday(year, month);
  if (candidate.getUTCDate() >= today && candidate.getUTCMonth() === month) {
    return new Date(candidate.getUTCFullYear(), candidate.getUTCMonth(), candidate.getUTCDate());
  }
  const nextMonth = month + 1;
  const result = secondThursday(
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
function useMonthlyAgenda(basePath: string): MonthlyAgendaResult {
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
      const url = `${basePath}/${monthStr}.md`;
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
  }, [basePath]);
  return state;
}

// Hook to load a single static agenda markdown file.
function useStaticAgenda(filePath: string): MonthlyAgendaResult {
  const [state, setState] = useState<MonthlyAgendaResult>({
    items: [],
    loading: true,
  });

  useEffect(() => {
    if (!ExecutionEnvironment.canUseDOM) {
      setState({ items: [], loading: false });
      return;
    }
    let cancelled = false;
    fetch(filePath, { cache: "no-cache" })
      .then(async (res) => {
        if (!res.ok) throw new Error(`Agenda not found (${res.status})`);
        return res.text();
      })
      .then((text) => {
        if (cancelled) return;
        const parsed = parseAgendaMarkdown(text);
        setState({ items: parsed.items, month: parsed.month, loading: false });
      })
      .catch(() => {
        if (!cancelled) setState({ items: [], loading: false });
      });
    return () => { cancelled = true; };
  }, [filePath]);
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
      aria-label="AKS Community Events Banner"
    >
      <div className={styles.heroOverlayInner}>
        <Heading as="h1">AKS Community Events</Heading>
        <p className={styles.heroSubtitle}>
          Monthly public sessions with the AKS Product Team.
        </p>
        <div className={styles.heroButtons}>
        </div>
      </div>
    </div>
  );
}

function EventSection({ event }: { event: EventType }): ReactNode {
  const monthlyResult = useMonthlyAgenda(event.agendaMode === "monthly" ? event.agendaBasePath : "");
  const staticResult = useStaticAgenda(event.agendaMode === "static" ? event.agendaBasePath : "");
  const { month, items, loading } = event.agendaMode === "monthly" ? monthlyResult : staticResult;
  const label = month || "Latest";
  const empty = !loading && items.length === 0;
  const nextDate = event.getNextDate();
  const metaSeparator = ": ";

  return (
    <section className={styles.agendaSection}>
      <div className={styles.callStrip}>
        <div className={styles.callStripInfo}>
          <span className={styles.callStripLabel}>Next session</span>
          <span className={styles.callStripSchedule}>
            {formatDate(nextDate)}
            {event.id === "community-calls" && " (Every 3rd Wednesday)"}
            <br />
            {event.schedule}
          </span>
        </div>
        <div className={styles.callStripActions}>
          {event.pastRecordingsHref && (
            <>
              <a href={event.pastRecordingsHref} className={styles.calendarLink}>
                Past recordings
              </a>
              <span className={styles.linkDivider}>|</span>
            </>
          )}
          <a href={event.icsHref} className={styles.calendarLink}>
            Add to calendar
          </a>
          <Link
            className={`button button--primary button--sm ${styles.joinBtn}`}
            to={event.joinHref}
          >
            Join Now
          </Link>
        </div>
      </div>
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
        <ul className={styles.agendaList}>
          {items.map((item, idx) => (
            <li key={idx} className={styles.agendaListItem}>
              <span className={`${styles.agendaItemTitle} ${item.featured ? styles.featured : ""}`.trim()}>
                {item.title}
              </span>
              {item.description && (
                <span className={`${styles.agendaItemMeta} ${styles.agendaItemDescription}`}>
                  {item.description}
                </span>
              )}
              {item.presenter && (
                <span className={styles.agendaItemMeta}>{metaSeparator}{item.presenter}</span>
              )}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export default function Webinars(): ReactNode {
  return (
    <Layout
      title="Community Events"
      description="AKS Community Events: monthly roadmap calls, architecture review hours, deep dives, and Q&A sessions with the Azure Kubernetes Service team"
    >
      <Hero />
      <main className={styles.eventsContainer}>
        {eventTypes.map((evt) => (
          <div
            key={evt.id}
            className={`${styles.eventBlock} ${evt.id === "community-calls" ? styles.communityBlock : styles.reviewBlock}`}
          >
            <Heading as="h2" className={styles.eventBlockTitle}>
              {evt.label}
            </Heading>
            <p className={styles.eventBlockSummary}>{evt.description}</p>
            <EventSection event={evt} />
          </div>
        ))}
      </main>
    </Layout>
  );
}
