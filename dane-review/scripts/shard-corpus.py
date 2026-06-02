#!/usr/bin/env python3
"""Split comments.jsonl into readable markdown chunks for parallel analysis.
Groups: frontend/react-leaning, backend/ts-leaning, general (review+conversation).
Each group is split into 2 chunks -> 6 chunk files."""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CORPUS = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "corpus", "comments.jsonl")
OUT = os.path.join(HERE, "..", "corpus", "chunks")
os.makedirs(OUT, exist_ok=True)

rows = [json.loads(l) for l in open(CORPUS) if l.strip()]

def group(r):
    if r["type"] in ("review", "conversation"):
        return "general"
    p = r.get("path") or ""
    if "apps/frontend" in p or "/frontend/" in p or p.endswith((".tsx", ".jsx", ".css", ".scss")):
        return "react"
    return "ts"

buckets = {"react": [], "ts": [], "general": []}
for r in rows:
    buckets[group(r)].append(r)

def trunc(s, n):
    s = s or ""
    return s if len(s) <= n else s[-n:]  # diff_hunk: keep the END (nearest the commented line)

def fmt(r, i):
    out = [f"### Comment {i}", f"- type: `{r['type']}`" + (f" | lang: `{r.get('lang')}`" if r.get('lang') else "")
           + (f" | review_state: `{r.get('state')}`" if r.get('state') else ""),
           f"- pr: #{r['pr']} — {r.get('pr_title','')}",
           f"- url: {r['url']}"]
    if r.get("path"):
        out.append(f"- path: `{r['path']}`")
    if r.get("diff_hunk"):
        out.append("\n_code context (diff hunk, tail):_\n```diff\n" + trunc(r["diff_hunk"], 1400) + "\n```")
    out.append("\n**Dane's comment:**\n" + (r.get("body") or "").strip() + "\n")
    return "\n".join(out)

manifest = []
for g, items in buckets.items():
    half = (len(items) + 1) // 2
    for part, sl in enumerate([items[:half], items[half:]], start=1):
        if not sl:
            continue
        name = f"chunk_{g}_{part}.md"
        path = os.path.join(OUT, name)
        with open(path, "w") as f:
            f.write(f"# Dane's review comments — group: {g} (part {part}), {len(sl)} comments\n\n")
            for i, r in enumerate(sl, 1):
                f.write(fmt(r, i) + "\n---\n\n")
        manifest.append({"path": os.path.abspath(path), "group": g, "count": len(sl)})
        print(f"  {len(sl):4d}  {name}")

json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"), indent=2)
print(f"\nmanifest: {os.path.join(OUT, 'manifest.json')}")
print(f"totals: react={len(buckets['react'])} ts={len(buckets['ts'])} general={len(buckets['general'])}")
