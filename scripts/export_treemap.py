#!/usr/bin/env python3
"""Build an Atlas-of-Economic-Complexity style export treemap from UN Comtrade data.

Reads a UN Comtrade bulk export (CSV, one reporter, one year, flow = Export,
partner = World, HS classification with rows at the 2-, 4- and 6-digit levels)
and writes a self-contained interactive HTML page: a treemap of the export
basket (HS4 products grouped into sectors, drill into a sector for HS6),
sector shares, concentration measures and a top-products table.

    python3 scripts/export_treemap.py data/comtrade_malaysia_exports_1989_hs6.csv \
        --out output/malaysia_exports_1989.html

Only one country's exports are needed. Complexity measures (ECI, PCI, RCA,
product space) need every country's exports for the same year and are not
computed here.
"""
import argparse
import csv
import json
import os
from collections import defaultdict

# Sector grouping by HS chapter, close to the Harvard Atlas sectors.
# Atlas folds wood and paper into other groups; here they are kept separate
# because they matter for Southeast Asian exporters.
SECTORS = [
    ("Electronics", range(85, 86)),
    ("Minerals & fuels", range(25, 28)),
    ("Textiles & apparel", list(range(41, 44)) + list(range(50, 68))),
    ("Agriculture & food", range(1, 25)),
    ("Chemicals, plastics & rubber", range(28, 41)),
    ("Wood & paper", range(44, 50)),
    ("Machinery", range(84, 85)),
    ("Metals & stone", range(68, 84)),
    ("Other", range(86, 100)),
]
CHAPTER_TO_SECTOR = {ch: name for name, chs in SECTORS for ch in chs}


def read_rows(path):
    # Comtrade rows end with a trailing comma, so read by header name.
    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        header = next(reader)
        for row in reader:
            yield dict(zip(header, row))


def build(path):
    hs4_names, hs6 = {}, []
    meta = {}
    for r in read_rows(path):
        if r["flowCode"] != "X" or r["partnerCode"] != "0":
            continue
        meta = {"country": r["reporterDesc"], "iso": r["reporterISO"],
                "year": r["refYear"], "classification": r["classificationCode"]}
        level, code = r["aggrLevel"], r["cmdCode"]
        if level == "4":
            hs4_names[code] = r["cmdDesc"]
        elif level == "6":
            value = float(r["primaryValue"] or 0)
            if value > 0:
                hs6.append((code, r["cmdDesc"], value))

    total = sum(v for _, _, v in hs6)
    groups = defaultdict(lambda: defaultdict(list))
    for code, name, value in hs6:
        sector = CHAPTER_TO_SECTOR.get(int(code[:2]), "Other")
        groups[sector][code[:4]].append({"c": code, "n": name, "v": value})

    tree = []
    for sector, _ in SECTORS:
        hs4s = [{"c": c4, "n": hs4_names.get(c4, c4),
                 "v": sum(p["v"] for p in prods),
                 "k": sorted(prods, key=lambda p: -p["v"])}
                for c4, prods in groups[sector].items()]
        if hs4s:
            tree.append({"n": sector, "k": sorted(hs4s, key=lambda h: -h["v"])})

    shares = sorted((v / total for _, _, v in hs6), reverse=True)
    meta.update({
        "total": total,
        "nHS6": len(hs6),
        "nHS4": sum(len(s["k"]) for s in tree),
        "top10": sum(shares[:10]),
        "hhi": sum(s * s for s in shares),
        "source": os.path.basename(path),
    })
    return {"meta": meta, "tree": tree}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("csv", help="UN Comtrade export CSV")
    ap.add_argument("--out", default="output/export_treemap.html")
    args = ap.parse_args()

    data = build(args.csv)
    template = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "export_treemap_template.html")
    with open(template, encoding="utf-8") as f:
        html = f.read()
    m = data["meta"]
    html = (html.replace("__DATA__", json.dumps(data, separators=(",", ":")))
                .replace("__COUNTRY__", m["country"])
                .replace("__YEAR__", m["year"]))
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"{m['country']} {m['year']}: ${m['total'] / 1e9:.2f}B exports, "
          f"{m['nHS6']} HS6 products -> {args.out}")


if __name__ == "__main__":
    main()
