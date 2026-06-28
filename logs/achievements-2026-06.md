---
title: "June 2026 — Monthly Achievement Log"
type: log
tags: [monthly-log, achievements, 2026]
---

## June 2026 — What We Built

**Maloha Coast Sdn Bhd — Month at a Glance**

### 🧠 Infrastructure & Tools
- **Google Workspace configured** — OAuth set up for `info@malohacoast.com` with full Gmail/Calendar/Drive/Sheets/Docs/People API scopes. Token auto-refreshes.
- **gbrain operational** — Local instance at `~/.bun/bin/gbrain` with OpenAI embeddings. 399+ pages ingested across people, companies, meetings, articles, and concepts.
- **gbrain dashboard deployed** — Interactive dashboard on GitHub Pages (`mc-hermes.github.io/hermes-agent-cost`) with knowledge graph, browse, entities, health, ask, and activity views. 6 themes, 0 dependencies.

### 🎓 Training & Workshops
- **Lead Instructor — Deploying AI Agents with Microsoft Foundry** — Hands-on lab delivered at Cradle Fund with KrackedDevs, in partnership with Microsoft.
- **Vibe101 Workshop — Sunway DealFlow Club, Sunway College** — Took beginners from setup to a live-deployed project in one evening with KrackedDevs / Danial Alias.

### 📊 Client-Specific Dashboards
- **Zaim dashboard** — Isolated gbrain dashboard for career coach Zaim Mohzani at `/zaim/`. Knowledge graph + entity views + activity log.
- **Certava dashboard** — Full gbrain setup for Certava team. 15 pages (6 people, 3 companies, 4 meetings, 2 concepts) with 27 cross-references, 26 action items. OCR'd Excel/Word/PNG attachments into structured data.

### 📬 Automations & Pipelines
- **Email Ingest Pipeline** — Cron job runs twice daily (9 AM & 9 PM MYT). Every 2-minute watchdog checks for new emails.
- **Daily Email Briefing** — 7 AM MYT cron summaries unread emails from key contacts.
- **Malaysia News Digest** — Daily 7:45 AM MYT fetch + curation of morning news.
- **gbrain Dashboard Auto-Refresh** — Hourly export + deploy to GitHub Pages.
- **gbrain Weekly Maintenance** — Monday 9 AM: doctor → extract → embed cycle.
- **Agent Dashboard** — 5-minute refresh for agent cost/usage tracking.
- **Gateway Health Watchdog** — Daily 6 AM memory/crash threshold checks.
- **Weekly Hermes Gateway Restart** — Sunday 4 AM to prevent memory bloat.

### 📅 Certava Project Operations
- **Certava Weekly Digest cron** — Monday 9 AM MYT: queries certava brain and produces meeting summary digest for team.
- **Certava Weekly Calendar Event** — Recurring Google Calendar event (Sundays 10-11 AM MYT) set up on `info@malohacoast.com`.

### 🗄️ How To Read This Log
This file lives at `logs/achievements-2026-06.md` in the `hermes-agent-cost-pages` repo. Each month appends a new entry. The gbrain dashboard loads this file and displays it in the Monthly Report view.

### 📏 Metrics for Future Months
| Metric | Jun 2026 | Notes |
|--------|----------|-------|
| gbrain pages | 399 | Tracking knowledge base growth |
| Cron jobs running | 10 | Automation infrastructure |
| Client dashboards | 2 (Zaim, Certava) | Billable deliverables |
| Workshops delivered | 2 (Cradle Fund, Sunway) | Training engagements |
| Meetings ingested | 4+ | Certava: Ventris, AL Pine, Weekly Sync |
| GitHub deploys (auto) | ~720 | Hourly auto-refresh |
| News digests delivered | ~25 | Daily weekday news |
