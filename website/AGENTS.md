# AKS Engineering Blog - Website Module Guide

> **Scope**: Module-specific guidance for the `website/` directory.
> **For Blog Posts**: See `.github/instructions/website.blog.instructions.md`
> **For Repo Standards**: See `.github/copilot-instructions.md`

## Quick Start

**Prerequisites**: Node.js >= 18.0, npm 9+

```bash
cd website
npm install        # Install dependencies (first time or when deps change)
npm start          # Dev server (http://localhost:3000) with hot reload
npm run build      # Production build → build/ directory
npm run typecheck  # TypeScript validation (catch before PR)
npm run clear      # Clear build cache (use if hot reload broken)
```

**First time?** Start with `npm start`, then create a post in `blog/YYYY-MM-DD-slug/index.md`. Changes hot-reload in browser.

---

## Architecture Overview

### Technology Stack

- **Framework**: Docusaurus 3.8.1+ (blog-only mode, docs disabled)
- **React**: 19.0.0
- **TypeScript**: 5.6.2
- **Node.js**: >= 18.0
- **Deployment**: Static site generation

### Key Design Decisions

1. **Blog-first**: Root path `/` serves blog listing (docs module disabled)
2. **Purple branding**: Custom theme (`#9f62eb`) with dark mode support
3. **Privacy-first**: GDPR cookie consent, analytics opt-in (GA4 only loads after consent)
4. **SEO-optimized**: RSS/Atom feeds auto-generated, meta descriptions, social cards, sitemap
5. **Type-safe**: Full TypeScript coverage with strict mode
6. **Static generation**: All pages pre-rendered at build time → deployed to Azure Static Web Apps
7. **No external build step for posts**: Drop `YYYY-MM-DD-slug/index.md` + run `npm run build`

---

## Directory Structure

```text
website/
├── blog/                          # Blog content (Markdown/MDX)
│   ├── YYYY-MM-DD-slug/          # Post directories
│   │   ├── index.md              # Post content
│   │   └── *.{png,jpg}           # Post assets
│   ├── authors.yml               # Author metadata
│   ├── tags.yml                  # Tag definitions
│   └── linters/                  # Content validation
├── src/
│   ├── components/               # React components
│   │   ├── CookieConsent.tsx    # GDPR banner
│   │   └── CookieConsent.css
│   ├── pages/                    # Custom pages
│   │   └── webinars.tsx         # Community webinar page
│   ├── theme/Root/               # Global layout wrapper
│   ├── utils/analytics.ts        # GA4 helpers
│   ├── css/custom.css           # Global styles (purple theme)
│   └── js/consentModule.ts      # Consent management
├── static/                       # Static assets
│   ├── img/                     # Logos, favicons, social cards
│   └── webinars/agenda/         # Monthly agendas (YYYY-MM.md)
├── docusaurus.config.ts         # Main configuration
├── package.json                 # Dependencies & scripts
├── tsconfig.json                # TypeScript config
└── AGENTS.md                    # This file
```

### Critical File Locations

| Purpose | Path |
|---------|------|
| Blog posts | `blog/YYYY-MM-DD-slug/index.md` |
| Authors | `blog/authors.yml` |
| Tags | `blog/tags.yml` |
| Site config | `docusaurus.config.ts` |
| Theme | `src/css/custom.css` |
| Analytics | `src/utils/analytics.ts` |
| Cookie consent | `src/components/CookieConsent.tsx` |
| Webinars | `src/pages/webinars.tsx` |

---

## Development Workflow

### Adding a Blog Post

See `.github/instructions/website.blog.instructions.md` for content guidelines and writing style.

**Quick steps**:

1. Create `blog/YYYY-MM-DD-slug/index.md`
2. Add front matter: `title`, `date`, `description`, `authors`, `tags`
3. Add `<!-- truncate -->` after intro paragraphs
4. Place images in same directory (`./image.png`)
5. Preview: `npm start`
6. Validate: `npm run build`

### Front Matter

See `.github/instructions/website.blog.instructions.md` for required and optional fields.

### Component Development

```typescript
// src/components/MyComponent.tsx
import React from 'react';
import ExecutionEnvironment from '@docusaurus/ExecutionEnvironment';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import styles from './MyComponent.module.css';
export default function MyComponent(): JSX.Element {
  // Guard browser APIs (server-side render safety)
  const [clientReady, setClientReady] = React.useState(false);
  React.useEffect(() => setClientReady(true), []);
  return (
    <Layout title="Page Title" description="Meta description">
      <div className={styles.container}>
        {clientReady && <p>Browser-only content here</p>}
      </div>
    </Layout>
  );
}
```

**Best Practices**:

- ✅ Use TypeScript (`.tsx`) — build will catch errors
- ✅ CSS Modules (`.module.css`) — all styles scoped locally
- ✅ Import from `@theme/Layout`, `@theme/Heading` — uses Docusaurus theme system
- ✅ Use `@docusaurus/Link` for internal links (handles routing)
- ✅ Guard browser APIs with `ExecutionEnvironment.canUseDOM` or `useEffect`
- ❌ Don't use browser APIs directly in render (causes SSR errors)
- ❌ Don't import CSS directly; use CSS Modules instead

---

## Customizations

### 1. Purple Theme (src/css/custom.css)

```css
--ifm-color-primary: #9f62eb;        /* Brand purple */
--ifm-color-primary-dark: #8e42e6;   /* Hover states */
--ifm-color-primary-darkest: #6f2bc7; /* Footer */
```

**Typography**: Inter (body), JetBrains Mono (code)

### 2. Cookie Consent System

**Components**:

- `src/components/CookieConsent.tsx` - Banner UI (shows on first visit)
- `src/utils/analytics.ts` - GA4 configuration & tracking
- `src/js/consentModule.ts` - Consent state management (`localStorage`)

**Consent Flow**:

1. User visits → Banner appears (if no prior choice)
2. User clicks "Accept" or "Reject" → Choice saved to `localStorage`
3. If accepted:
   - GA4 script loads and initializes
   - Consent event sent to Google Analytics
   - Page views and events tracked normally
4. If rejected:
   - No GA4 script loads
   - No analytics collected
5. Default (if user dismisses banner without clicking): Analytics denied

**Updating GA4 Tracking ID**:

```typescript
// src/utils/analytics.ts
export const GA_CONFIG = {
  trackingId: 'G-XXXXXXXXXX',  // Get from Google Analytics > Admin > Data Streams
  anonymizeIP: true,
} as const;
```

**Testing Analytics**:

1. Open DevTools → Application → Cookies → find `aks-consent-choice`
2. Delete cookie → reload → banner appears
3. Accept → check Network tab for `gtag/js` script loading
4. Reject → confirm no `gtag/js` request

**Privacy Compliance**: All analytics disabled by default. Only GA4 used (no third-party trackers). User consent stored locally, never shared.

### 3. Webinar Page (src/pages/webinars.tsx)

**Data Sources**:

1. **Timezone cards**: Hardcoded `timezoneCalls` array in component (edit directly)
2. **Monthly agendas**: `static/webinars/agenda/YYYY-MM.md` (parsed at build time)

**Agenda Format** (`YYYY-MM.md`):

```markdown
---
month: October 2025
---
## Topic Title
Presenter: Name, Title
Description: Brief summary
Featured: true
- Key point 1
- Key point 2
## Q&A Session
Description: Open floor for questions
```

**Parsing Rules**:

- Frontmatter MUST include `month:` field
- Each section intro is a `## Heading`
- Optional lines (in any order): `Presenter:`, `Description:`, `Featured: true`
- Bullet points (`- text`) collect into a list
- Blank lines ignored
- First matching section becomes the topic

**Fallback Behavior**: If current month file missing, component steps backward up to 3 months to find latest available agenda. This ensures agenda always displays even before current month is created.

**Maintenance**: 
- Create `2025-11.md` before November community call
- No need to delete old months—component finds latest automatically
- Update timezone cards if meeting times/links change

### 4. Root Wrapper (src/theme/Root/)

Injects `<CookieConsent />` globally on all pages.

---

## Content Management

### Authors (blog/authors.yml)

```yaml
author-key:
  name: Full Name
  title: Job Title
  url: https://linkedin.com/in/username
  image_url: https://github.com/username.png
  page: true                    # Generate author page
  socials:
    x: twitter_handle
    linkedin: linkedin_username
    github: github_username
```

**Usage**: `authors: [author-key]` in front matter

### Tags (blog/tags.yml)

```yaml
tag-key:
  label: Display Name
  permalink: /tag-url
  description: SEO description for tag page
```

**Common tags**: `aks`, `kubernetes`, `ai`, `networking`, `security`, `storage`, `observability`, `troubleshooting`, `gpu`, `istio`, `open-source`

**Usage**: `tags: [tag1, tag2]` in front matter

### Navigation

**Navbar**: Posts (/) | Tags | Resources (dropdown) | Releases | Roadmap | GitHub

**Footer**: Resources | Community | More (Roadmap, FAQ, RSS, Contact)

---

## Common Tasks

### Add Author

```yaml
# Edit blog/authors.yml
john-doe:
  name: John Doe
  title: Senior Engineer, AKS
  url: https://linkedin.com/in/johndoe
  image_url: https://github.com/johndoe.png
  page: true
  socials:
    github: johndoe
    linkedin: johndoe
```

### Add Tag

```yaml
# Edit blog/tags.yml
new-topic:
  label: New Topic
  permalink: /new-topic
  description: Brief SEO description
```

### Update Webinar Agenda

```bash
cat > static/webinars/agenda/2025-11.md << 'EOF'
---
month: November 2025
---
## Feature Highlight
Presenter: Jane Smith, PM Lead
Featured: true
- Topic overview
- Key benefits
EOF
```

### Customize Theme Colors

```css
/* Edit src/css/custom.css */
:root {
  --ifm-color-primary: #YOUR_COLOR;
  /* Update all color variations */
}
```

---

## Build & Deployment

### Build Process

```bash
npm run build
# 1. Compile TypeScript + React (typecheck first)
# 2. Generate static HTML for all pages
# 3. Optimize CSS/JS bundles (minify, code-split)
# 4. Create RSS + Atom feeds from blog metadata
# 5. Copy rss.xml → feed.xml (RSS alias for compatibility)
# 6. Output: build/ directory ready for deployment
```

**Feed Generation**:

- RSS feed: `build/rss.xml` (standard RSS format with post summaries)
- Atom feed: `build/atom.xml` (alternative feed format)
- RSS alias: `build/feed.xml` (copies `rss.xml` for backward compatibility)
- Generated from post front matter: `title`, `date`, `description`, `authors`
- Posts with `draft: true` excluded from feeds

**Feed Testing**:

```bash
npm run build
# Verify feeds exist and are valid XML
file build/rss.xml build/feed.xml build/atom.xml
# Should output: XML document text
```

### Output Structure

```text
build/
├── index.html           # Blog listing
├── tags/                # Tag pages
├── blog/YYYY/MM/DD/     # Post pages
├── rss.xml              # RSS feed
├── feed.xml             # Alias
├── atom.xml             # Atom feed
└── assets/              # Optimized CSS/JS/images
```

### Deployment Config

- **Base URL**: `/` (root)
- **Trailing slashes**: Disabled
- **Broken links**: Fail build
- **Target**: Azure Static Web Apps

### SEO Features

**Automatic**:

- RSS/Atom feeds with full post metadata (discoverable by feed readers)
- Sitemap generated at build time (`build/sitemap.xml`)
- Edit links to GitHub (helps crawlers understand content history)
- Canonical URLs (prevent duplicate content issues)
- Meta descriptions from front matter

**Manual Setup** (in front matter):

```yaml
description: "1–2 sentence summary (150–160 chars for Google preview)"
keywords: ["AKS", "Kubernetes", "networking"]  # Optional: for niche searches
```

**Social Cards**:

- Social card image: `image: ./hero.png` in front matter
- Falls back to default card if not specified
- Used by social media platforms (Twitter, LinkedIn, Slack, etc.)
- Recommended size: 1200x630px (16:9 aspect ratio)

**Best Practices**:

- Description should answer: "What will I learn from this post?"
- Include 2-3 keywords in description naturally
- Social card: Use unique images per post (avoid generic placeholders)
- Test: Use [Open Graph debugger](https://developers.facebook.com/tools/debug/og/object) to preview social cards

---

## Image & Media Guidelines

### Image Optimization

- **Format**: PNG for diagrams/screenshots, JPG for photos
- **Size**: < 500KB per image (consider WebP for modern browsers)
- **Dimensions**: Max width 1200px (Docusaurus container width)
- **Alt text**: Always include descriptive alt text for accessibility

```markdown
![AKS cluster architecture showing node pools and networking](./aks-architecture.png)
```

### Embedding

```markdown
# Images in same directory as index.md
![Alt text](./image-name.png)
# Relative paths (one level up if needed)
![Alt text](../shared/image.png)
# Avoid external images (slower, not recommended)
![Alt text](https://example.com/image.png)
```

### Screenshots

- Use full-width examples where possible
- Highlight important areas with rectangles/arrows
- Include terminal output in code blocks instead of images (better for accessibility)

---

## Troubleshooting

### Build fails: "broken links"

**Fix**: Run `npm run build` to see exact errors. Use `./image.png` for same-directory images.

### Post not appearing

**Check**:

- [ ] Date not in future (or explicitly allowed for scheduled posts)
- [ ] No `draft: true` in front matter
- [ ] Author key exists in `blog/authors.yml`
- [ ] Tag keys exist in `blog/tags.yml`
- [ ] File named `index.md` (not `post.md`, etc.)
- [ ] Restart dev server if authors/tags recently changed

### Images not loading

**Fix**:

- Images must be in same directory as `index.md`
- Use relative path: `![alt](./image.png)` (not absolute)
- Check case-sensitive filenames (Linux/Mac enforce case)
- Run `npm run build` to catch broken image links

### Build fails: "Post without authors" or "Post without tags"

**Fix**: Ensure all `authors` and `tags` referenced in front matter exist:

```bash
npm run build  # Shows exact line numbers
# Then verify entries exist in blog/authors.yml and blog/tags.yml
```

### RSS/Atom feeds missing or invalid

**Check**:

```bash
npm run build
file build/rss.xml build/atom.xml build/feed.xml
# Should output: XML document text
# Also validates that posts appear in feeds
```

If feeds are invalid, check:
- [ ] All posts have `date:` in front matter
- [ ] `date` format is valid: `YYYY-MM-DD`
- [ ] No `draft: true` posts in feeds (only published posts)

### Analytics not working

**Check**:

- [ ] `GA_CONFIG.trackingId` is not placeholder (starts with `G-`)
- [ ] User accepted cookies (check `localStorage` > `aks-consent-choice`)
- [ ] No console errors (DevTools → Console tab)
- [ ] `gtag/js` loads (DevTools → Network tab, search for "gtag")
- [ ] GA4 property is not in test mode

### TypeScript errors

```bash
npm run typecheck  # See all type errors with file:line references
```

**Common issues**:

- `Cannot find module '@docusaurus/...'`: Check `npm install` completed successfully
- `Type X is not assignable to type Y`: Check prop types match component definition
- Missing `.tsx` extension: All React files must be `.tsx`, not `.ts`

### Hot reload broken or styles not updating

```bash
npm run clear    # Clear Docusaurus cache
npm start        # Restart dev server
```

**If still broken**: Delete `node_modules/.cache`, then restart.

---

## Agent Checklist

### When Adding Blog Posts

Follow `.github/instructions/website.blog.instructions.md` for content requirements.

**Technical validation**:

- ✅ Use `blog/YYYY-MM-DD-slug/index.md` structure
- ✅ All author/tag keys exist in `blog/authors.yml` and `blog/tags.yml`
- ✅ Test locally: `npm start`
- ✅ Validate: `npm run build` (must succeed)

### When Modifying Config

- ✅ Backup current version of `docusaurus.config.ts` before editing
- ✅ Edit `docusaurus.config.ts` for navbar/footer/metadata
- ✅ Edit `src/css/custom.css` for theme colors/typography
- ✅ Run `npm run typecheck` and fix any errors
- ✅ Test light + dark mode toggle
- ✅ Verify feeds still generate: `npm run build` → check `build/rss.xml`

### When Creating Components

- ✅ Use TypeScript (`.tsx`) — no JavaScript files
- ✅ CSS Modules (`.module.css`) for scoped styles
- ✅ Import utilities from `@theme/` aliases (e.g., `@theme/Layout`)
- ✅ Guard browser APIs: `import ExecutionEnvironment from '@docusaurus/ExecutionEnvironment'`
- ✅ Use functional components with hooks (no class components)
- ✅ Test client-side rendering (SSR safety)

### Quality Checks (Pre-Deployment)

- ✅ `npm run build` succeeds completely (no warnings/errors)
- ✅ `npm run typecheck` passes with no errors
- ✅ All posts render with images correctly
- ✅ No broken internal links (build verifies)
- ✅ RSS/Atom feeds valid XML: `file build/rss.xml build/atom.xml`
- ✅ SEO metadata complete: description, authors, tags present
- ✅ Mobile responsive (test at 375px, 768px, 1200px widths)
- ✅ Accessibility: alt text on images, semantic HTML, color contrast

---

## Links

- **Production**: <https://blog.aks.azure.com\>
- **Repository**: <https://github.com/Azure/AKS\>
- **Docusaurus Docs**: <https://docusaurus.io/docs\>
- **Contact**: brian.redmond@microsoft.com

---

**Last Updated**: 2025-10-04
**Docusaurus**: 3.8.1
**Node**: >= 18.0