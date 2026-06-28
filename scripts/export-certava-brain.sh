#!/usr/bin/env bash
# export-certava-brain.sh — Export Certava-tagged pages to dashboard JSON
# Uses the enrichment pipeline then filters by tag.
set -euo pipefail

TAG="${TAG:-certava}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT="${OUTPUT:-$REPO_DIR/certava/gbrain-data.json}"
ENRICH_SCRIPT="$HOME/.hermes/skills/software-development/gbrain-dashboard/references/enrichment-script.py"

# Use a temp export dir so it doesn't conflict with main brain
export CERTAVA_EXPORT="/tmp/certava-brain-export"
export CERTAVA_OUTPUT="/tmp/certava-data.json"
export PATH="$HOME/.bun/bin:$PATH"
export GBRAIN_HOME="/home/ubuntu/.gbrain-certava"

echo "=== Exporting Certava-tagged pages ==="

# Step 1: Export all pages from certava brain
echo "[1/4] Exporting certava brain..."
rm -rf "$CERTAVA_EXPORT"
gbrain export --dir "$CERTAVA_EXPORT" 2>&1 | tail -1

# Step 2: Run enrichment pipeline with custom paths
echo "[2/4] Running enrichment pipeline..."
EXP_DIR="$CERTAVA_EXPORT" python3 -c "
import json, os, sys
sys.path.insert(0, os.path.expanduser('$HOME/.hermes/skills/software-development/gbrain-dashboard/references'))
from enrichment_script import main
" 2>&1 || python3 "$ENRICH_SCRIPT" 2>&1 | tail -1

# Actually the enrichment script is hardcoded — let's do the enrichment ourselves
echo "[2b/4] Building certava data directly..."

python3 << 'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone
from collections import Counter

EXPORT_DIR = "/tmp/certava-brain-export"
OUTPUT_FILE = "/tmp/certava-data.json"

def parse_frontmatter(text):
    """Parse YAML frontmatter from a markdown file."""
    text = text.strip()
    if not text.startswith('---'):
        return {}, text
    end = text.find('---', 3)
    if end == -1:
        return {}, text
    fm_lines = text[3:end].strip().split('\n')
    fm = {}
    current_key = None
    current_list = []
    for line in fm_lines:
        if line.lstrip().startswith('- '):
            if current_key:
                current_list.append(line.lstrip()[2:].strip())
        elif ':' in line:
            if current_key and current_list:
                fm[current_key] = current_list
                current_list = []
            key, _, val = line.partition(':')
            current_key = key.strip()
            val = val.strip()
            if val.startswith('[') and val.endswith(']'):
                fm[current_key] = [v.strip().strip("'\"") for v in val[1:-1].split(',')]
                current_key = None
            elif val:
                fm[current_key] = val
                current_key = None
            else:
                current_list = []
    if current_key and current_list:
        fm[current_key] = current_list
    return fm, text[end+3:].strip()

def to_slug(title):
    """Convert a title to a slug for link resolution."""
    s = title.lower().strip()
    s = re.sub(r'[^a-z0-9]+', '-', s)
    s = s.strip('-')
    return s

def extract_wikilinks(body):
    """Extract [[wikilink]] references from body text."""
    return re.findall(r'\[\[([^\]]+)\]\]', body)

def resolve_wikilink(wl, slug_map):
    """Resolve a wikilink to a slug using the slug_map."""
    wl = wl.strip()
    if '|' in wl:
        target, _ = wl.split('|', 1)
    else:
        target = wl
    target = target.strip()
    # Direct match
    if target in slug_map:
        return slug_map[target]
    # Try as slug
    slug = to_slug(target)
    if slug in slug_map:
        return slug_map[slug]
    # Try reversed slug_map
    rev = {v: k for k, v in slug_map.items()}
    if target in rev:
        return rev[target]
    return None

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

# ── Read export directory ───────────────────────────────────────────────
if not os.path.isdir(EXPORT_DIR):
    eprint(f"Export directory not found: {EXPORT_DIR}")
    # Try alternative locations
    for d in ["/tmp/brain-export", "/tmp/certava-brain-export"]:
        if os.path.isdir(d):
            EXPORT_DIR = d
            eprint(f"Using: {d}")
            break
    else:
        sys.exit(1)

pages_raw = []
for root, dirs, files in os.walk(EXPORT_DIR):
    for f in files:
        if f.endswith('.md'):
            path = os.path.join(root, f)
            with open(path) as fh:
                content = fh.read()
            fm, body = parse_frontmatter(content)
            slug = os.path.splitext(f)[0]
            pages_raw.append({
                'slug': slug,
                'title': fm.get('title', slug),
                'type': fm.get('type', 'page'),
                'tags': fm.get('tags', []),
                'body': body,
                'updated': fm.get('updated', datetime.now(timezone.utc).strftime('%Y-%m-%d')),
            })

eprint(f"  Found {len(pages_raw)} pages in export")

# ── Build slug map ──────────────────────────────────────────────────────
slug_map = {p['slug']: p['slug'] for p in pages_raw}
for p in pages_raw:
    t_slug = to_slug(p['title'])
    if t_slug and t_slug not in slug_map:
        slug_map[t_slug] = p['slug']

# ── Resolve links ───────────────────────────────────────────────────────
link_set = set()
for p in pages_raw:
    wikilinks = extract_wikilinks(p['body'])
    for wl in wikilinks:
        target = resolve_wikilink(wl, slug_map)
        if target:
            edge = (p['slug'], target)
            if edge not in link_set:
                link_set.add(edge)

# ── Build page data ─────────────────────────────────────────────────────
tag = "certava"
certava_pages = [p for p in pages_raw if tag in p.get('tags', [])]
certava_slugs = {p['slug'] for p in certava_pages}

# Build link data per page
links_out = {p['slug']: [] for p in certava_pages}
for source, target in link_set:
    if source in certava_slugs and target in certava_slugs:
        links_out[source].append({"to": str(target), "type": "wikilink"})

# Count backlinks
backlinks = {s: [] for s in certava_slugs}
for source, target in link_set:
    if source in certava_slugs and target in certava_slugs:
        backlinks[target].append({"from": str(source), "type": "wikilink"})

pages = []
for p in certava_pages:
    pages.append({
        "slug": p['slug'],
        "title": p['title'],
        "type": p['type'],
        "updated": p.get('updated', ''),
        "body": p['body'][:500],  # Truncate for dashboard
        "tags": p.get('tags', []),
        "links_out": links_out.get(p['slug'], []),
        "backlinks": backlinks.get(p['slug'], []),
        "outbound_count": len(links_out.get(p['slug'], [])),
        "inbound_count": len(backlinks.get(p['slug'], [])),
    })

# ── Graph links ─────────────────────────────────────────────────────────
graph_links = []
for source, target in link_set:
    if source in certava_slugs and target in certava_slugs:
        graph_links.append({
            "source": str(source),
            "target": str(target),
            "type": "wikilink",
            "context": "",
        })

# ── Entities ────────────────────────────────────────────────────────────
entities = {"people": [], "companies": []}
for p in certava_pages:
    if p['type'] == 'person':
        entities['people'].append(p['slug'])
    elif p['type'] == 'company':
        entities['companies'].append(p['slug'])

# ── Summary ─────────────────────────────────────────────────────────────
type_counts = Counter(p['type'] for p in certava_pages)
outbound_total = sum(p['outbound_count'] for p in pages)
inbound_total = sum(p['inbound_count'] for p in pages)
pages_with_inbound = sum(1 for p in pages if p['inbound_count'] > 0)
graph_pct = round(pages_with_inbound / max(len(pages), 1) * 100, 1)

summary = {
    "page_count": len(pages),
    "people_count": len(entities['people']),
    "company_count": len(entities['companies']),
    "artifact_count": 0,
    "total_links": len(graph_links),
    "outbound_count": outbound_total,
    "inbound_count": inbound_total,
    "graph_coverage": f"{graph_pct}% of pages have inbound links",
    "concept_count": type_counts.get('concept', 0),
    "meeting_count": type_counts.get('meeting', 0),
    "person_count": type_counts.get('person', 0),
}

# ── Build activity logs ─────────────────────────────────────────────────
now = datetime.now(timezone.utc)
now_ts = now.strftime("%Y-%m-%dT%H:%M:%SZ")

# Load existing logs to preserve history
existing_logs = []
existing_keys = set()
try:
    with open(OUTPUT_FILE) as f:
        old = json.load(f)
        for ev in old.get("logs", []):
            key = (ev.get("ts",""), ev.get("source",""), ev.get("stage",""), ev.get("slug"))
            if key not in existing_keys:
                existing_keys.add(key)
                existing_logs.append(ev)
    eprint(f"  Loaded {len(existing_logs)} existing log entries")
except Exception:
    eprint("  No existing logs (fresh export)")

new_logs = []
for p in certava_pages:
    slug = p['slug']
    title = p.get('title', slug)
    fm_date = p.get('updated', '')
    if fm_date:
        ev = {
            "ts": f"{fm_date}T00:00:00Z",
            "source": "page",
            "stage": "updated",
            "slug": slug,
            "detail": str(title),
            "level": "info",
        }
        key = (ev["ts"], ev["source"], ev["stage"], ev["slug"])
        if key not in existing_keys:
            existing_keys.add(key)
            new_logs.append(ev)

# Export pipeline event
export_ev = {
    "ts": now_ts,
    "source": "export",
    "stage": "deployed",
    "slug": None,
    "detail": f"Dashboard refreshed — {len(pages)} pages, {len(graph_links)} links",
    "level": "info",
}
new_logs.append(export_ev)

logs = existing_logs + new_logs
logs.sort(key=lambda e: (e["ts"], e.get("source","")), reverse=True)
eprint(f"  Logs: {len(new_logs)} new + {len(existing_logs)} existing = {len(logs)} total")

# ── Assemble and write ──────────────────────────────────────────────────
output = {
    "updated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "summary": summary,
    "pages": pages,
    "graph_links": graph_links,
    "entities": entities,
    "doctor": {},
    "artifacts": [],
    "logs": logs,
}

os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
with open(OUTPUT_FILE, 'w') as f:
    json.dump(output, f, indent=2)

eprint(f"  Wrote {len(json.dumps(output))} bytes to {OUTPUT_FILE}")
PYEOF

echo "[3/4] Copying to repo..."
cp /tmp/certava-data.json "$OUTPUT"

echo "[4/4] Done — $OUTPUT"
echo "  Pages: $(python3 -c "import json; d=json.load(open('$OUTPUT')); print(len(d['pages']))")"
echo "  Links: $(python3 -c "import json; d=json.load(open('$OUTPUT')); print(len(d['graph_links']))")"
