---
applyTo: website/blog/**/index.md
---

# AKS Blog Post Content Guidelines

> **Scope**: File-specific patterns for blog post Markdown files.  
> **Module Context**: See `website/AGENTS.md` for architecture and workflows.  
> **Repo Standards**: See `.github/copilot-instructions.md` for general conventions.

## Editorial Purpose

The AKS engineering blog shares the engineering and product thinking behind AKS. Help technical readers understand **why we did it this way**, **why it matters to them**, and **how to reach us about it**. A post should add insight beyond product documentation or a release announcement.

Write for developers building and running applications on AKS, platform engineers, and Kubernetes practitioners. Start with their problem or a technical constraint, not a feature list.

### Complement Documentation and Announcements

- **Documentation**: Link to maintained Microsoft Learn and upstream documentation rather than repeating setup, reference, or troubleshooting instructions.
- **Walkthroughs**: Include steps when they demonstrate integration choices, an experiment, or a result that existing documentation does not explain.
- **Announcements**: Availability alone is not enough. Add engineering insight or a specific question readers can help answer. Otherwise, recommend the established announcement channel or release notes.

### Sources and Reader Feedback

- Ground claims in sources. Don't invent engineering decisions, customer stories, or results. Include test conditions and limitations with measurements.
- Cite sources for adapted text, diagrams, and code, and respect their licenses.
- Keep internal links, confidential details, and customer-identifying information out.
- Close with a useful next step and verified public feedback route. Ask a specific question when seeking feedback.

### Agent Workflow for Writing and Review

1. Establish the reader, problem, and single takeaway. Use supplied context and ask only for material gaps.
2. Read the source material and existing documentation. Identify the post's contribution beyond those sources.
3. Choose a structure and supporting examples that serve that contribution.
4. Review editorial fit, accuracy, reader impact, and feedback route before formatting. Report actionable findings with their location and reader impact.
5. Preserve the author's voice. Do not rewrite the full post unless requested.

Review the post's contribution, not its conformity to a template. Don't require implementation steps or a fixed length when the engineering takeaway is clear.

## Front Matter (Required)

Required fields:

```yaml
---
title: "Descriptive Post Title"
description: "A unique summary of what readers will learn."
authors: [author-key]  # From blog/authors.yml
tags: [tag1, tag2]     # From blog/tags.yml
---
```

- **Title**: Write a concise, descriptive title that accurately reflects the post. Avoid keyword stuffing.
- **Description**: Write a unique, relevant summary explaining what readers will learn. Use search terms naturally, without padding to a character target.
- Use author and tag keys defined in `blog/authors.yml` and `blog/tags.yml`.
- Optional: `image` for the social card and `keywords` for relevant search terms.

### Publication

- For new posts, omit `date` and use `blog/YYYY-MM-DD-slug/index.md`. The folder supplies the publication date. Update it before merging if review has made the date stale.
- Merging to `master` means publish. Keep unfinished posts in PRs and omit `draft`; Docusaurus defaults it to `false`.
- Future dates do not delay publication. `unlisted: true` hides a post from listings, not public access.
- Leave existing `date` overrides and folder names unchanged during unrelated edits to preserve published dates and URLs.

## Structure and Style

- Explain the problem, approach, trade-offs, and reader impact in an order that suits the story. These are not mandatory headings.
- Follow the repository's [Microsoft Style Guide](../copilot-instructions.md#part-2-microsoft-style-guide). Use a direct, technical, approachable voice, active sentences, and short paragraphs. Avoid hype and unexplained jargon.
- Keep the post focused. Include enough context and evidence to support the takeaway, without repetition or filler.
- Add `<!-- truncate -->` after the opening paragraph for listing previews.
- The title comes from front matter. Use sentence-style H2 and H3 headings in the body, with H4 sparingly.
- Use [Docusaurus admonitions](https://docusaurus.io/docs/markdown-features/admonitions) for notes, tips, and warnings instead of blockquote callouts. Leave blank lines around their content.
- Posts use [MDX syntax](https://docusaurus.io/docs/markdown-features), including `.md` files. Put literal placeholders such as `<resource-group>` and expressions containing braces in code spans or fenced code blocks so they aren't parsed as JSX.
- Use descriptive Markdown links, not bare URLs or "click here."
- Remove locale segments such as `/en-us/` from Microsoft Learn URLs: use `https://learn.microsoft.com/azure/aks/...`.
- When linking to existing blog posts, use their actual published URLs in root-relative form (for example, `/2026/11/09/build-the-platform-not-the-plumbing`), not full `https://blog.aks.azure.com/...` URLs. Don't infer URLs from folder names.
- A hero image is optional. When using images, keep them beside `index.md`, reference them with relative paths such as `./hero.png`, add descriptive alt text, and compress each image to under 500KB before committing.

### Technical Examples

- Include code, diagrams, or measurements only where they explain or help reproduce the engineering work.
- Label fenced code blocks with a language. Use realistic, focused examples and link to longer samples when they interrupt the flow.
- For runnable steps, include prerequisites, versions, permissions, expected results, and cleanup for resources created.
- Distinguish Microsoft-managed capabilities from self-managed components and link to applicable support guidance.

## Pre-Publish Checklist

- [ ] Editorial and source checks above are complete
- [ ] Front matter, folder date, author keys, and tag keys are correct
- [ ] Links and images resolve
- [ ] Spelling, grammar, and formatting are checked
- [ ] Preview with `npm start` in `website/` and check rendered admonitions, code blocks, images, and heading links
- [ ] Build test with `npm run build`
