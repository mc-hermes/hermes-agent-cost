#!/usr/bin/env bash
# export-zaim-brain.sh — Export Zaim-tagged pages to his dashboard JSON
# Uses the same enrichment pipeline as the main dashboard, then filters by tag.
set -euo pipefail

TAG="${TAG:-zaim}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT="${OUTPUT:-$REPO_DIR/zaim/gbrain-data.json}"
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

# Step 3: Filter by tag and write Zaim's JSON
echo "[3/3] Filtering by tag '$TAG'..."
python3 << PYEOF
import json, os, re
from datetime import datetime, timezone

with open("$MAIN_DATA") as f:
    data = json.load(f)

tag = "$TAG"
all_pages = data.get("pages", [])
zaim_pages = [p for p in all_pages if tag in p.get("tags", [])]
print(f"  Pages: {len(zaim_pages)} tagged '{tag}' (out of {len(all_pages)} total)")

zaim_slugs = {p["slug"] for p in zaim_pages}

# Filter graph links
all_links = data.get("graph_links", [])
zaim_links = [l for l in all_links
              if l.get("source") in zaim_slugs and l.get("target") in zaim_slugs]
print(f"  Links: {len(zaim_links)} (out of {len(all_links)} total)")

# Filter entities
entities_raw = data.get("entities", {})
entities = {"people": [], "companies": []}
for kind in ["people", "companies"]:
    for slug in entities_raw.get(kind, []):
        if slug in zaim_slugs:
            entities[kind].append(slug)

# Filter artifacts
all_artifacts = data.get("artifacts", [])
zaim_artifacts = [a for a in all_artifacts
                  if any(sp in zaim_slugs for sp in a.get("source_pages", []))]

# Rebuild summary
summary = dict(data.get("summary", {}))
summary["page_count"] = len(zaim_pages)
summary["people_count"] = len(entities["people"])
summary["company_count"] = len(entities["companies"])
summary["artifact_count"] = len(zaim_artifacts)

output = {
    "updated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "summary": summary,
    "pages": zaim_pages,
    "graph_links": zaim_links,
    "entities": entities,
    "doctor": {},
    "artifacts": zaim_artifacts,
}

os.makedirs(os.path.dirname("$OUTPUT"), exist_ok=True)
with open("$OUTPUT", "w") as f:
    json.dump(output, f, indent=2)

print(f"  Wrote {len(json.dumps(output))} bytes to $OUTPUT")
PYEOF

echo "=== Done ==="
