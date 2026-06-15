#!/usr/bin/env bash
# export-zaim-brain.sh — Export Zaim-tagged pages from main gbrain to his dashboard JSON
# Usage: ./export-zaim-brain.sh [--tag zaim] [--output ../zaim/gbrain-data.json]
set -euo pipefail

TAG="${TAG:-zaim}"
OUTPUT="${OUTPUT:-$(dirname "$0")/../zaim/gbrain-data.json}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

export PATH="$HOME/.bun/bin:$PATH"

echo "=== Exporting pages tagged '$TAG' to $OUTPUT ==="

# Get full doctor output
DOCTOR_JSON=$(gbrain doctor --json 2>/dev/null)
if [ -z "$DOCTOR_JSON" ]; then
    echo "ERROR: gbrain doctor returned empty output"
    exit 1
fi

# Use Python to filter and rebuild the JSON
python3 << PYEOF
import json, sys, os
from datetime import datetime, timezone

doctor = json.loads('''$DOCTOR_JSON''')

# Get all pages
all_pages = doctor.get("pages", [])
tag = "$TAG"

# Filter pages tagged with the target tag
zaim_pages = [p for p in all_pages if tag in p.get("tags", [])]
print(f"Found {len(zaim_pages)} pages tagged '{tag}' (out of {len(all_pages)} total)")

# Collect slugs of zaim pages
zaim_slugs = {p["slug"] for p in zaim_pages}

# Filter graph links — only keep links where both ends are zaim pages
all_links = doctor.get("graph_links", [])
zaim_links = [l for l in all_links 
              if l.get("source") in zaim_slugs and l.get("target") in zaim_slugs]
print(f"Graph links: {len(zaim_links)} (out of {len(all_links)} total)")

# Filter entities
entities_raw = doctor.get("entities", {})
entities = {"people": [], "companies": []}
for kind in ["people", "companies"]:
    for slug in entities_raw.get(kind, []):
        if slug in zaim_slugs:
            entities[kind].append(slug)

# Filter artifacts — only those whose source_pages intersect with zaim pages
all_artifacts = doctor.get("artifacts", [])
zaim_artifacts = []
for art in all_artifacts:
    source_pages = art.get("source_pages", [])
    if any(sp in zaim_slugs for sp in source_pages):
        zaim_artifacts.append(art)

# Rebuild summary stats
summary = doctor.get("summary", {})
summary["page_count"] = len(zaim_pages)
summary["people_count"] = len(entities["people"])
summary["company_count"] = len(entities["companies"])
summary["artifact_count"] = len(zaim_artifacts)

# Build output
output = {
    "updated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "summary": summary,
    "pages": zaim_pages,
    "graph_links": zaim_links,
    "entities": entities,
    "doctor": doctor.get("doctor", {}),
    "artifacts": zaim_artifacts,
}

# Write
os.makedirs(os.path.dirname("$OUTPUT"), exist_ok=True)
with open("$OUTPUT", "w") as f:
    json.dump(output, f, indent=2)

print(f"Wrote {len(json.dumps(output))} bytes to $OUTPUT")
PYEOF

echo "=== Done ==="
