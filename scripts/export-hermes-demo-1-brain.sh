#!/usr/bin/env bash
# export-hermes-demo-1-brain.sh — Export hermes-demo-1-tagged pages to dashboard JSON
# Uses the same enrichment pipeline as the main dashboard, then filters by tag.
set -euo pipefail

TAG="${TAG:-hermes-demo-1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT="${OUTPUT:-$REPO_DIR/hermes-demo-1/gbrain-data.json}"
ENRICH_SCRIPT="$HOME/.hermes/skills/software-development/gbrain-dashboard/references/enrichment-script.py"
MAIN_DATA="/tmp/hermes-agent-cost/gbrain-data.json"

export PATH="$HOME/.bun/bin:$PATH"

echo "=== Exporting pages tagged '$TAG' ==="

# Step 1: Export all pages from gbrain
echo "[1/3] Exporting brain to /tmp/brain-export..."
gbrain export --dir /tmp/brain-export 2>&1 | tail -1

# Step 2: Run enrichment pipeline (same as main dashboard)
echo "[2/3] Running enrichment pipeline..."
python3 "$ENRICH_SCRIPT" 2>&1 | tail -1

# Step 2b: Get actual page dates from gbrain (for accurate log timestamps)
echo "[2b/4] Getting page dates from gbrain..."
export PATH="$HOME/.bun/bin:$PATH"
gbrain list 2>&1 > /tmp/gbrain-list.tsv
echo "       $(wc -l < /tmp/gbrain-list.tsv) pages listed"

# Step 3: Filter by tag, build hermes-demo-1-scoped data, and write JSON
echo "[3/4] Filtering by tag '$TAG'..."
python3 << PYEOF
"""
Hermes Demo Dashboard Data Builder
----------------------------------
Reads the enriched main brain JSON, filters to hermes-demo-1-tagged pages only,
builds a scoped summary, and generates a static activity log from page
metadata — no live API, no cross-contamination.
"""
import json, os
from datetime import datetime, timezone
from collections import Counter

# ── Load ───────────────────────────────────────────────────────────────
with open("$MAIN_DATA") as f:
    data = json.load(f)

tag = "$TAG"
all_pages = data.get("pages", [])
tagged_pages = [p for p in all_pages if tag in p.get("tags", [])]
print(f"  Pages: {len(tagged_pages)} tagged '{tag}' (out of {len(all_pages)} total)")

tagged_slugs = {p["slug"] for p in tagged_pages}

# ── Filter graph links ─────────────────────────────────────────────────
all_links = data.get("graph_links", [])
tagged_links = [l for l in all_links
              if l.get("source") in tagged_slugs and l.get("target") in tagged_slugs]
print(f"  Links: {len(tagged_links)} (out of {len(all_links)} total)")

# ── Filter entities ────────────────────────────────────────────────────
entities_raw = data.get("entities", {})
entities = {"people": [], "companies": []}
for kind in ["people", "companies"]:
    for slug in entities_raw.get(kind, []):
        if slug in tagged_slugs:
            entities[kind].append(slug)

# ── Filter artifacts ───────────────────────────────────────────────────
all_artifacts = data.get("artifacts", [])
tagged_artifacts = [a for a in all_artifacts
                  if any(sp in tagged_slugs for sp in a.get("source_pages", []))]

# ── Build scoped summary ──────────────────────────────────────────────
type_counts = Counter(p["type"] for p in tagged_pages)
outbound_total = sum(p.get("outbound_count", 0) for p in tagged_pages)
inbound_total = sum(p.get("inbound_count", 0) for p in tagged_pages)
pages_with_inbound = sum(1 for p in tagged_pages if p.get("inbound_count", 0) > 0)
graph_pct = round(pages_with_inbound / max(len(tagged_pages), 1) * 100, 1)

summary = {
    "page_count": len(tagged_pages),
    "people_count": len(entities["people"]),
    "company_count": len(entities["companies"]),
    "artifact_count": len(tagged_artifacts),
    "total_links": len(tagged_links),
    "outbound_count": outbound_total,
    "inbound_count": inbound_total,
    "graph_coverage": f"{graph_pct}% of pages have inbound links",
    "concept_count": type_counts.get("concept", 0),
    "meeting_count": type_counts.get("meeting", 0),
    "person_count": type_counts.get("person", 0),
    "newsletter_count": type_counts.get("newsletter", 0),
    "video_count": type_counts.get("video", 0),
    "article_count": type_counts.get("article", 0),
    "bookmark_count": type_counts.get("bookmark", 0),
    "quote_count": type_counts.get("quote", 0),
    "dataset_count": type_counts.get("dataset", 0),
    "digest_count": type_counts.get("digest", 0),
}

# ── Build scoped activity log ─────────────────────────────────────────
now = datetime.now(timezone.utc)
now_ts = now.strftime("%Y-%m-%dT%H:%M:%SZ")

# Parse gbrain list dates: "slug\ttype\tYYYY-MM-DD\ttitle"
page_dates = {}
try:
    with open("/tmp/gbrain-list.tsv") as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) >= 3:
                slug, ptype, date_str = parts[0], parts[1], parts[2]
                if date_str and len(date_str) == 10:  # YYYY-MM-DD
                    page_dates[slug] = date_str
except Exception:
    pass  # best-effort; fall back to empty dates

# ── Load existing logs to preserve history ──
existing_logs = []
existing_keys = set()
try:
    with open("$OUTPUT") as f:
        old = json.load(f)
        for ev in old.get("logs", []):
            key = (ev.get("ts",""), ev.get("source",""), ev.get("stage",""), ev.get("slug"))
            if key not in existing_keys:
                existing_keys.add(key)
                existing_logs.append(ev)
    print(f"  Loaded {len(existing_logs)} existing log entries")
except Exception:
    print("  No existing logs (fresh export)")

# ── Generate new log entries ──
new_logs = []

# Page events: use the real gbrain modification date if available,
# otherwise fall back to enrichment frontmatter date.
for p in tagged_pages:
    slug = p["slug"]
    title = p.get("title", slug)
    gb_date = page_dates.get(slug, "")
    fm_date = p.get("updated", "")
    real_date = gb_date or fm_date
    if real_date:
        ev = {
            "ts": f"{real_date}T00:00:00Z",
            "source": "page",
            "stage": "updated",
            "slug": slug,
            "detail": title,
            "level": "info",
        }
        key = (ev["ts"], ev["source"], ev["stage"], ev["slug"])
        if key not in existing_keys:
            existing_keys.add(key)
            new_logs.append(ev)

# Export pipeline event — this timestamp IS real.
export_ev = {
    "ts": now_ts,
    "source": "export",
    "stage": "deployed",
    "slug": None,
    "detail": f"Dashboard refreshed — {len(tagged_pages)} pages, {len(tagged_links)} links",
    "level": "info",
}
# Export events always get a new entry (timestamp changes each run)
new_logs.append(export_ev)

# ── Merge: existing first, then new on top ──
logs = existing_logs + new_logs

# Sort newest first, then by source for stable ordering
logs.sort(key=lambda e: (e["ts"], e["source"]), reverse=True)

print(f"  Logs: {len(new_logs)} new + {len(existing_logs)} existing = {len(logs)} total")

# ── Assemble and write ─────────────────────────────────────────────────
output = {
    "updated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "summary": summary,
    "pages": tagged_pages,
    "graph_links": tagged_links,
    "entities": entities,
    "doctor": {},
    "artifacts": tagged_artifacts,
    "logs": logs,
}

os.makedirs(os.path.dirname("$OUTPUT"), exist_ok=True)
with open("$OUTPUT", "w") as f:
    json.dump(output, f, indent=2)

print(f"  Wrote {len(json.dumps(output))} bytes to $OUTPUT")
PYEOF

echo "=== Done ==="
echo "  Output: $OUTPUT"
