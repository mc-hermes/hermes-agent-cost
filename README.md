# hermes-agent-cost

Live gbrain dashboard and AI agent cost breakdown for Maloha Coast Sdn Bhd.

**Live:** [mc-hermes.github.io/hermes-agent-cost](https://mc-hermes.github.io/hermes-agent-cost)

## Contents

| File | Description |
|------|-------------|
| `index.html` | Landing page with links to all presentations |
| `gbrain-dashboard.html` | Interactive gbrain control panel — knowledge graph, page browser, entity cards, health monitoring, clickable modals |
| `gbrain-data.json` | Enriched brain data (auto-generated via cron) |
| `gbrain-head-hands-heart.html` | Slide deck — "The 3-Folder Brain" onboarding |
| `hermes-agent-cost.html` | Slide deck — "The $40 AI Agent" cost breakdown |

## Dashboard Features

- **Knowledge Graph** — force-directed graph showing all brain pages and their connections
- **Clickable Page Modals** — full content, tags, outgoing links, backlinks
- **Entity Cards** — people and companies with contact details
- **Health Monitoring** — 50+ automated diagnostic checks
- **Instant Search** — across pages, content, tags, and types
- **Built-in Help** — press `?` or click the gold button for docs

## How It Works

1. `gbrain` (the knowledge base) stores pages about people, companies, meetings, concepts, infrastructure
2. A cron job runs `gbrain doctor --json` and exports page data into `gbrain-data.json`
3. The static dashboard reads the JSON and renders everything client-side — no backend, no database queries, no server cost
4. Files are deployed to GitHub Pages (free)

## Deploy

```bash
git clone https://github.com/mc-hermes/hermes-agent-cost.git
# Edit gbrain-data.json with your brain's data
git add . && git commit -m "update" && git push
```

Or use any static host — Netlify, Vercel, S3, or a plain web server. Just two files: `gbrain-dashboard.html` + `gbrain-data.json`.

## Auto-Refresh

The dashboard fetches `gbrain-data.json` on load. To keep it current, regenerate the JSON on a schedule:

```bash
# Example cron: every 6 hours
0 */6 * * * cd /path/to/brain && ./export-dashboard.sh && cd /path/to/repo && git add gbrain-data.json && git commit -m "data refresh" && git push
```

## Brand

Maloha Coast brand colours: teal blue `#2a6a8a` + champagne gold `#c4a86a`. Dark slate `#020617` background. Inter + JetBrains Mono typography.

## License

Private — Maloha Coast Sdn Bhd
