# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A static GitHub Pages site for Maloha Coast — a collection of standalone HTML pages (slide decks, diagrams, a PRD) plus a live gbrain knowledge-base dashboard. No build step, no dependencies, no server. Everything deploys as-is.

**Live site:** `mc-hermes.github.io/hermes-agent-cost`
**Remote:** `https://github.com/mc-hermes/hermes-agent-cost.git`

## Deploy

```bash
git add . && git commit -m "message" && git push
```

GitHub Pages serves `main` directly. Changes are live within ~60 seconds of push.

## Data refresh

**Do not publish brain data to this repo.** It is public, and GitHub Pages serves
`main` directly. `gbrain-data.json`, the per-tenant directories, and the dashboard
were removed because they exposed client brains and the tenant registry to anyone
with the URL. See the repo history for the incident.

Brain data belongs on a private host. If you need a public demo, publish a seeded
dataset with no real people, companies, or meeting content.

To refresh a private dashboard: run `gbrain doctor --json` on the VPS and deploy
the output to the private host, not to GitHub Pages.

## Architecture

### gbrain-dashboard.html

Removed from this repo. The interactive dashboard (single self-contained HTML file,
~2700 lines, vanilla JS) is developed and deployed on the private host; it fetches
`gbrain-data.json` at page load and renders the graph, entity, and activity views.
Do not commit it here.

**`gbrain-data.json` schema** (top-level keys):
- `updated_at` — ISO timestamp of last export
- `summary` — aggregate stats (page count, score, entity counts, link counts)
- `pages[]` — all brain pages with slug, title, type, body, tags, links_out, backlinks
- `graph_links[]` — edges for the force-directed graph
- `entities` — `{ people: [slug,...], companies: [slug,...] }` (slugs that reference pages[])
- `doctor` — `{ checks: [{name, status, category, message},...] }` for health view
- `artifacts[]` — binary/media files with preview metadata

**View system:** `showView(name)` swaps `.view-panel` visibility. Views render lazily (guarded by `graphRendered`, `pagesRendered`, `entitiesRendered`, `healthRendered`, `artifactsRendered` flags). Views: `today`, `graph`, `browse`, `entities`, `health`, `artifacts`.

**Graph:** Force-directed physics on a `<canvas>`. `initGraph()` builds node/edge arrays from `DATA.pages` and `DATA.graph_links`. `runPhysics()` runs spring/repulsion simulation. Supports pan/zoom/drag, touch, fullscreen.

**Themes:** 6 CSS variable sets toggled by `applyTheme(name)` — `library` (default, warm academic with Playfair Display serif headings + Crimson Text body), `dark` (Tokyo Night), `light`, `catppuccin-mocha`, `catppuccin-latte`, `tokyo-night`. Persisted in `localStorage('gbrain-theme')`.

**Modals:** `openModal(title, subtitle, bodyHtml)` is the generic modal. `openPageModal(slug)` and `openCheckModal(name)` are the two callers.

### Other HTML files

| File | Type | Notes |
|------|------|-------|
| `index.html` | Landing page | Links to all other pages; Maloha Coast brand palette |
| `business-case-second-brain.html` | Slide deck | Client pitch for Second Brain product ($29/mo) |
| `prd-email-to-brain.html` | PRD doc | RFC-001 technical spec for email-to-brain pipeline |
| `email-to-brain-architecture.html` | Architecture diagram | SVG pipeline diagram |
| `gbrain-head-hands-heart.html` | Slide deck | "3-Folder Brain" onboarding |
| `hermes-agent-cost.html` | Slide deck | "$40 AI Agent" cost breakdown |

### Brand

All pages use consistent tokens:
- **Colors:** teal `#2a6a8a`, champagne gold `#c4a86a`, dark slate `#020617` background
- **Fonts:** Inter (body) + JetBrains Mono (code/numbers) — loaded from Google Fonts
- **Exception:** `gbrain-dashboard.html` uses the Library Design System (warm academic palette) as default. Serif headings (Playfair Display) + Crimson Text body. Also loads Syne, Inter, JetBrains Mono for other themes.

## The `.bak` file

`gbrain-dashboard.html.bak-20260611-0841` is a timestamped backup — safe to ignore or delete.
