<!-- markdownlint-disable -->
---
applyTo: website/blog/**/index.md
---

# AKS Blog Post Content Guidelines

> **Scope**: File-specific patterns for blog post Markdown files.  
> **Module Context**: See `website/AGENTS.md` for architecture and workflows.  
> **Repo Standards**: See `.github/copilot-instructions.md` for general conventions.

## Front Matter (Required)

Every blog post MUST include:

```yaml
---
title: "Descriptive Post Title"
date: YYYY-MM-DD
description: "SEO-optimized summary (150-160 characters)"
authors: [author-key]  # From blog/authors.yml
tags: [tag1, tag2]     # From blog/tags.yml
---
```

**Validation Checklist**:

- [ ] `title`: Clear, descriptive, under 60 chars
- [ ] `date`: Valid format, can be future-dated for future publishing
- [ ] `description`: 150-160 chars, includes keywords
- [ ] `authors`: Valid keys from `blog/authors.yml`
- [ ] `tags`: Valid keys from `blog/tags.yml`

## Content Structure

### Required Pattern

```markdown
---
title: "..."
date: YYYY-MM-DD
description: "..."
authors: [...]
tags: [...]
---

[Opening paragraph: Hook the reader, set context, preview content]

<!-- truncate -->

![Hero Image](./hero-image.png)

## Section 1: Problem/Context
[Describe the challenge or background...]

## Section 2: Solution/Details
[Explain the approach or feature...]

## Section 3: Implementation
[Step-by-step guide or examples...]

## Conclusion
[Summarize key takeaways...]
```

### Critical Elements

1. **Truncation marker**: `<!-- truncate -->` after 2-3 intro paragraphs (shows on listing page)
2. **Hero image**: Use `./hero-image.png` for same-directory assets
3. **Heading hierarchy**: H2 (`##`) for major sections, H3 (`###`) for subsections
4. **Alt text**: All images MUST have descriptive alt text

## Writing Style

### Target Audience

- **Primary**: AKS users, Kubernetes practitioners, platform engineers
- **Level**: Intermediate to advanced technical knowledge
- **Expectation**: Practical, actionable content with examples

### Tone Guidelines

- ✅ Follows the Microsoft Style Guide
- ✅ Professional yet approachable
- ✅ Direct and concise
- ✅ Technical but accessible
- ❌ No marketing fluff or buzzwords
- ❌ No unexplained jargon
- ❌ No passive voice (prefer active)

### Content Requirements

- **Length**: 800-1500 words (longer acceptable if high-value)
- **Paragraphs**: 3-4 sentences max per paragraph
- **Lists**: Use bullets/numbers liberally to break up text
- **Examples**: Include code snippets, commands, or diagrams
- **Links**: External references to docs, GitHub, or related posts
- **Originality**: Must be original content (cite sources if adapted)

## Formatting Patterns

### Headings

```markdown
## Major Section (H2)

### Subsection (H3)

#### Detail Point (H4 - use sparingly)
```

**Rules**:

- Title (H1) auto-generated from front matter
- Use H2 for main sections
- Use H3 for subsections
- Avoid H4+ (indicates over-complexity)

### Code Blocks

**Always specify language**:

````markdown
```bash
kubectl get pods -n production
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example
```

```typescript
export function handleRequest(): void {
  // Implementation
}
```
````

**Best Practices**:

- Include comments for complex code
- Show realistic examples (not `foo`/`bar`)
- Keep snippets under 30 lines (link to gists for longer)

### Links

```markdown
✅ [Azure Kubernetes Service documentation](https://learn.microsoft.com/azure/aks)
✅ See the [AKS roadmap](https://github.com/orgs/Azure/projects/685) for planned features.

❌ Click [here](https://example.com) for more info.
❌ Check out https://example.com
```

**Rules**:

- Descriptive link text (not "click here" or "this link")
- No bare URLs (always use `[text](url)` syntax)
- Prefer Microsoft Learn for Azure docs

### Images

```markdown
![Descriptive alt text explaining the image](./image-filename.png)
```

**Requirements**:

- Images in same directory as `index.md`
- Use relative paths: `./image.png`
- Descriptive alt text (accessibility + SEO)
- Optimize before commit (compress PNGs/JPGs)
- Max 500KB per image

### Emphasis

```markdown
**Important term or concept** (bold - use sparingly)
*Subtle emphasis* (italic - rare)
`code or technical term` (inline code)
```

### Blockquotes

```markdown
> **Note**: Important callout for readers to understand before proceeding.

> **Warning**: This action cannot be undone.
```

Use for:

- Important notes or warnings
- Prerequisites
- Key takeaways

### Lists

**Unordered (bullets)**:

```markdown
- First item
- Second item
  - Nested item
  - Another nested item
- Third item
```

**Ordered (numbers)**:

```markdown
1. First step
2. Second step
3. Third step
```

**Checklists**:

```markdown
- [ ] Incomplete task
- [x] Completed task
```

## SEO Best Practices

### Description Field

- **Length**: 150-160 characters (strict)
- **Include**: Primary keyword(s)
- **Avoid**: Duplicate meta descriptions across posts
- **Example**: "Learn how to optimize AKS cluster performance with node pools, autoscaling, and resource management best practices."

### Keywords

- Use naturally in title, description, headings
- Include variations (e.g., "Kubernetes" + "K8s")
- Focus on user intent (what they're searching for)

### Internal Linking

Link to other blog posts when relevant:

```markdown
See our previous post on [AKS networking fundamentals](/2024/01/15/aks-networking-basics).
```

## Common Mistakes to Avoid

❌ **Future-dated posts**: Will not appear on site until publish date
❌ **Missing truncate marker**: Full post shows on listing page  
❌ **Bare URLs**: Always use `[text](url)` syntax  
❌ **Locale based URLs**: Use generic links (no `/en-us/`)  
❌ **Generic alt text**: Use descriptive alt text for images  
❌ **Invalid author/tag keys**: Must exist in `authors.yml`/`tags.yml`  
❌ **No code language**: Specify language for syntax highlighting  
❌ **Huge images**: Compress before commit  
❌ **Broken links**: Test all links before publishing

## Pre-Publish Checklist

Before submitting a blog post:

- [ ] Content follows the Microsoft Style Guide
- [ ] Front matter complete and validated
- [ ] `<!-- truncate -->` after intro (2-3 paragraphs)
- [ ] All images have descriptive alt text
- [ ] All code blocks have language specified
- [ ] All links use descriptive text (no "click here")
- [ ] SEO description is 150-160 chars
- [ ] Spell-check and grammar-check complete
- [ ] Preview with `npm start` in `website/`
- [ ] Build test with `npm run build`
- [ ] Images compressed (under 500KB each)
- [ ] Author keys exist in `blog/authors.yml`
- [ ] Tag keys exist in `blog/tags.yml`

## Examples

### Good Post Structure

```markdown
---
title: "Optimizing AKS Network Performance with CNI Plugins"
date: 2025-10-04
description: "Compare Azure CNI and Kubenet for AKS networking to optimize performance, security, and cost for your workloads."
authors: [paul-yu]
tags: [aks, networking, performance, cni]
---

Choosing the right Container Network Interface (CNI) plugin is critical for AKS cluster performance. This guide compares Azure CNI and Kubenet to help you make informed decisions.

<!-- truncate -->

![CNI Architecture Comparison](./cni-comparison.png)

## Understanding CNI Options

Azure Kubernetes Service supports two primary CNI plugins...

### Azure CNI

Azure CNI assigns Azure VNet IPs directly to pods...

### Kubenet

Kubenet uses bridge networking with NAT...

## Performance Comparison

| Metric | Azure CNI | Kubenet |
|--------|-----------|---------|
| Latency | Lower | Higher |
| IP Usage | High | Low |

## Implementation Guide

### Step 1: Plan IP Address Space

```bash
# Calculate required IPs
NODES=10
MAX_PODS_PER_NODE=30
REQUIRED_IPS=$((NODES * MAX_PODS_PER_NODE))
echo "Need subnet with /${REQUIRED_IPS} IPs"
```

### Step 2: Create Cluster

```bash
az aks create \
  --resource-group myRG \
  --name myCluster \
  --network-plugin azure \
  --vnet-subnet-id $SUBNET_ID
```

## Conclusion

Azure CNI offers better performance but higher IP consumption. Choose based on your network topology and scale requirements.
```
---
**Questions?** Contact brian.redmond@microsoft.com  
**Module Guide**: See `website/AGENTS.md`
