# AKS Website / Blog Authoring Guide

This document explains how to create and maintain blog posts for the Docusaurus site under `website/`.

## Contents

1. Prerequisites & Local Preview
2. Create / Update an Author (`blog/authors.yml`)
3. Pick / Create Tags (`blog/tags.yml`)
4. Post Folder & File Structure
5. Front Matter Reference
6. Writing Conventions
7. Images & Media Guidance
8. Admonitions
9. Tag Strategy
10. Drafts vs Published
11. Pull Request Checklist
12. Example Complete Post
13. Maintaining the Webinars / Community Calls Page

---

## 1. Prerequisites & Local Preview

From the `website/` directory:

```bash
npm install        # first time or when deps change
npm start          # launch local dev server (http://localhost:3000)
```

Edits hot‑reload. If you add new authors or tags and they do not appear, restart.

---

## 2. Create / Update an Author (`blog/authors.yml`)

Each author has a YAML key (the author ID) used in post front matter: `authors: ["author-id"]`.

Author ID rules:

- Lowercase
- Words separated by hyphens
- Unique & stable (avoid renames)

Minimal entry template:

```yaml
your-id:
  name: Full Name
  title: Short public-facing title / role
  url: https://optional-profile-url
  image_url: https://link.to/avatar.png
  page: true # set true to generate an author page - must be sure to have 1+ post otherwise a build error occurs
  socials: # omit keys you don't use
    x: handle-without-@
    linkedin: linkedin-handle
    github: github-handle
```

Add yourself before referencing the author ID in a post. Multiple authors are supported with a list.

---

## 3. Pick / Create Tags (`blog/tags.yml`)

`tags.yml` defines curated tags (label + permalink + description). A tag used in a post that is not defined here will still render, but adding it here:

- Centralizes descriptions
- Maintains permalink consistency
- Enables easier curation

Template:

```yaml
my-new-tag:
  label: My New Tag
  permalink: /my-new-tag
  description: One-line description shown on tag page
```

Naming guidance:

- Use kebab-case keys
- Labels may have spaces / capitalization (stay consistent)
- Prefer existing tags over near-duplicates (`networking` vs `network`)

---

## 4. Post Folder & File Structure

Each post is a directory under `blog/` named with ISO date prefix + descriptive slug:

```
YYYY-MM-DD-descriptive-kebab-slug/
  index.md                # required primary content file
  image1.png
  diagram-architecture.webp
  ...other media assets...
```

Example: `2025-02-28-end-to-end-tls-encryption-with-aks-app-routing-and-afd/`

Folder naming tips:

- Date must match the `date:` in front matter (controls chronology)
- Slug: concise, lowercase, hyphenated, avoid filler words

---

## 5. Front Matter Reference

The front matter goes at the top of `index.md` between `---` delimiters.

Common fields:

```yaml
---
title: "Clear, Human-Readable Title (Use Title Case)"
date: "2025-09-20" # YYYY-MM-DD (UTC)
description: "1–2 sentence summary for previews & SEO."
authors: ["paul-yu", "brian-redmond"]
tags:
  - networking
  - add-ons
  - azure-front-door
image: ./hero.png # optional hero/social card
hide_table_of_contents: false # optional, true for very short posts
draft: false # optional draft flag (see section 10)
keywords: ["AKS", "Kubernetes", "Azure"]
---
```

Excerpt control:

- Place `<!-- truncate -->` on a blank line after the intro paragraph to define the listing excerpt.
- Everything above `<!-- truncate -->` appears in blog post previews/listings
- Everything below `<!-- truncate -->` only appears when viewing the full post
- This helps keep blog listings concise while allowing detailed content in the full post
- Position it after 1-3 introductory paragraphs that give readers enough context to decide if they want to read more

Multiple authors:

```yaml
authors: ["alice-id", "bob-id"]
```

Single author:

```yaml
authors: ["alice-id"]
```

---

## 6. Writing Conventions

- Use sentence case for section headings (except the title)
- Prefer `##` and `###` levels; avoid deeper nesting unless necessary
- Wrap lines naturally (no need for manual 80-char wraps) – readability in Markdown source matters but is secondary to clarity.
- Use fenced code blocks with language identifiers for syntax highlighting:

```bash
az aks show -g myrg -n mycluster -o table
```

- For inline code or commands, use backticks: `kubectl get pods`.
- Links: Prefer descriptive text over bare URLs.
- Avoid marketing fluff; focus on clarity and actionable guidance.
- Use correct product names (Azure Kubernetes Service (AKS), Azure Front Door, etc.).

---

## 7. Images & Media Guidance

Store images in the same post folder and reference relatively:

```markdown
![High-level architecture diagram](./architecture-diagram.webp)
```

Best practices:

- Prefer `.webp` (or `.avif`) for diagrams/screenshots; `.png` for sharp detail, `.jpg` for photos
- Filenames: lowercase, hyphen-separated (`control-plane-flow.png`)
- Optimize (< ~300 KB when feasible) via tools like `cwebp`, `oxipng`, or `squoosh.app`
- Provide meaningful alt text (accessibility + SEO)
- Reuse image paths (avoid duplicates)
- Use GIFs only when motion adds real value; otherwise static sequence

Diagram options:

- If Mermaid or similar is enabled you can embed source; else export to an image

---

## 8. Admonitions (Docusaurus Callouts)

Supported types: `note`, `tip`, `info`, `caution`, `danger` (and sometimes `warning`).

Syntax:

```markdown
:::note
This is a simple note.
:::

:::tip Pro Tip
Add a custom title after the type for emphasis.
:::

:::caution Be Careful
Highlight potential pitfalls or irreversible actions.
:::

:::danger Irreversible Operation
Double check before running destructive commands.
:::
```

Guidelines:

- `tip` for performance/efficiency hints
- `caution` for side effects / billing / security concerns
- `danger` for destructive or high-risk steps
- Keep them concise; move deep detail to body text

---

## 9. Tag Strategy & Best Practices

Keep tags curated:

- Use 2–6 tags per post
- Combine broad (`networking`) and specific (`azure-front-door`)
- Reuse existing tags before adding new
- If adding, define in `tags.yml` with a clear description

Example fragment:

```yaml
tags:
  - networking
  - add-ons
  - azure-front-door
  - ingress-nginx
```

---

## 10. Drafts vs Published Posts

Options:

1. Future `date:` (some pipelines hide future posts)
2. `draft: true` (requires site config support)
3. Keep locally until ready, then commit

Indicate in the PR description if a post is a draft.

---

## 11. Pull Request Checklist

Before opening / merging:

- [ ] Folder named `YYYY-MM-DD-slug/` with `index.md`
- [ ] Front matter: title, date, description, authors, tags
- [ ] Authors present in `authors.yml`
- [ ] Tags validated / added to `tags.yml` if new
- [ ] Images optimized (no oversized raw screenshots)
- [ ] `<!-- truncate -->` placed intentionally
- [ ] Code blocks have language identifiers
- [ ] Admonitions appropriate & minimal
- [ ] Spell check / lint pass
- [ ] Links resolve (no obvious 404s)

Optional:

- Hero `image:` defined (if theme uses it)
- `keywords:` added for niche SEO

---

## 12. Example Complete `index.md`

```markdown
---
title: "Optimizing Node Throughput on AKS"
date: "2025-09-20"
description: "Practical tuning techniques to squeeze more network and CPU throughput from AKS worker nodes."
authors: ["paul-yu"]
tags:
  - performance
  - networking
  - tuning
image: ./throughput-hero.webp
keywords: ["AKS", "performance", "networking"]
---

Modern workloads can push a surprising amount of packets and system calls. In this post we'll look at how to profile your current node limits and apply targeted optimizations.

<!-- truncate -->

:::tip Quick Win
If you only do one thing, enable accelerated networking on all eligible VM sizes.
:::

## Baseline Profiling

...content...
```

---

## Questions?

Open an issue or start a discussion in the repository. Happy writing!

---

## 13. Maintaining the Webinars / Community Calls Page

The Community Calls page (`/webinars`) displays two kinds of information:

1. Agenda items (topics, presenters, bullets) from the latest available monthly markdown (current month first, then automatic lookback)
2. Regional call times + calendar links (hard-coded constants in the page)

The agenda now comes only from markdown files. There is no JSON fallback.

### A. Monthly Agenda via Markdown (Authoring Model)

Location for files: `website/static/webinars/agenda/`

Filename format: `YYYY-MM.md` (e.g. `2025-09.md` for September 2025)

Minimal structure:

```markdown
---
month: September 2025
---

# Agenda

## Welcome & Announcements

- Bullet one
- Bullet two

## Feature Deepdive: Something Cool

Presenter: Jane Doe, Principal PM
Featured: true

## Q&A Session

Description: Open floor for questions
```

Supported lines under a `## Heading`:

- `Presenter: Name and title` (optional)
- `Description: Short sentence` (optional)
- `Featured: true` (optional highlight)
- Bullet points starting with `-` collect into a list

Rules:

- Omit a field if not needed
- Blank lines between sections help readability
- First frontmatter block must include `month:`

Runtime resolution logic:

- Attempt current month file (`YYYY-MM.md`).
- If missing, step backwards month-by-month (up to 6 previous months) until a file is found.
- First successfully parsed file supplies the agenda and displayed month.
- If none found in the lookback window, an empty-state message appears.

### B. Update Workflow (Monthly)

1. Copy previous month markdown to new `YYYY-MM.md` under `static/webinars/agenda/`.
2. Update `month:` frontmatter and edit sections.
3. Keep headings meaningful (they render as agenda item titles).
4. Commit + open PR. Preview build: navigate to `/webinars` and ensure items render.
5. (Optional) Add future month early; it will auto-activate when that month begins.

### C. Lookup / Error Behavior

- Missing current month file: The logic searches prior months (up to 6) for the latest agenda.
- Nothing found in lookback: Panel shows an empty-state message.
- Parse issues (rare): Treated like missing; previous month(s) are tried.
- Typos in keys simply ignored (e.g. `Presentor:`) and do not break parsing.

### D. Adding / Updating Calendar Files

Calendar `.ics` files live under: `website/static/webinars/`

They are referenced directly in the React component; keep filenames consistent or update the hrefs when changing calendar files.

### E. Troubleshooting

| Symptom                                 | Likely Cause                                                | Fix                                     |
| --------------------------------------- | ----------------------------------------------------------- | --------------------------------------- |
| Agenda shows old month                  | New markdown filename wrong (e.g. missing leading zero)     | Ensure `YYYY-MM.md` (e.g. `2025-09.md`) |
| Bullets not appearing                   | Missing `-` prefix                                          | Add `-` at line start                   |
| Presenter not shown                     | Typo (`Presentor:`)                                         | Use exact `Presenter:` key              |
| Highlight not applied                   | `Featured: True` capital T maybe with spaces                | Use `Featured: true` (lowercase true)   |
| Line breaks inside schedule not working | Using actual newline instead of `<br />` in schedule string | Replace with `<br />` tags              |

### F. Best Practices

- Commit next month’s agenda a few days early—users will see it immediately on the 1st.
- Keep headings short; they render as the agenda item titles.
- Use `Featured: true` sparingly to highlight one key segment.
- Break very long agendas into logical headings instead of large bullet collections.

### G. Future Enhancements (Optional)

- Previous months dropdown (on-demand fetch)
- Build-time pre-parsing (plugin) for SSR + SEO improvements
- Script to scaffold next month automatically

Open an issue if you want any of these implemented.
