#!/usr/bin/env python3
"""Draw interactive line charts of World Bank WDI indicators for a few countries.

Each input is a World Development Indicators CSV as downloaded from
data.worldbank.org (four metadata lines, then one row per country with a
column per year). Every file becomes one chart; the charts share a year axis
and the countries keep the same color throughout.

    python3 scripts/wdi_line_charts.py \
        data/wdi_gdp_per_capita_current_usd.csv \
        data/wdi_fdi_net_inflows_current_usd.csv \
        data/wdi_fdi_net_inflows_pct_gdp.csv \
        --countries IDN MYS VNM --out output/wdi_idn_mys_vnm.html
"""
import argparse
import csv
import json
import os

# How each known indicator is displayed: short title, unit label, number format.
INDICATORS = {
    "NY.GDP.PCAP.CD": ("GDP per capita", "current US$", "usd"),
    "BX.KLT.DINV.CD.WD": ("Foreign direct investment, net inflows", "current US$", "usd_big"),
    "BX.KLT.DINV.WD.GD.ZS": ("Foreign direct investment, net inflows", "% of GDP", "pct"),
}


def read_wdi(path, countries):
    with open(path, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.reader(f))
    header_at = next(i for i, r in enumerate(rows) if r[:2] == ["Country Name", "Country Code"])
    header = rows[header_at]
    years = [int(y) for y in header[4:] if y.strip().isdigit()]
    series, indicator = [], None
    by_code = {r[1]: r for r in rows[header_at + 1:] if len(r) > 4}
    for code in countries:
        r = by_code.get(code)
        if r is None:
            raise SystemExit(f"{path}: no row for country code {code}")
        indicator = (r[2], r[3])
        points = [[y, float(v)] for y, v in zip(years, r[4:4 + len(years)]) if v.strip()]
        series.append({"code": code, "name": r[0], "points": points})
    name, code = indicator
    title, unit, fmt = INDICATORS.get(code, (name, "", "num"))
    return {"indicator": name, "code": code, "title": title, "unit": unit, "fmt": fmt,
            "source": os.path.basename(path), "series": series}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("csv", nargs="+", help="WDI indicator CSV files, one chart each")
    ap.add_argument("--countries", nargs="+", default=["IDN", "MYS", "VNM"],
                    help="ISO3 country codes, at most 3 (default: IDN MYS VNM)")
    ap.add_argument("--out", default="output/wdi_line_charts.html")
    args = ap.parse_args()
    if len(args.countries) > 3:
        ap.error("at most 3 countries: more lines than that are hard to tell apart")

    charts = [read_wdi(p, args.countries) for p in args.csv]
    names = [s["name"] for s in charts[0]["series"]]
    template = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wdi_line_charts_template.html")
    with open(template, encoding="utf-8") as f:
        html = f.read()
    title = ", ".join(names[:-1]) + " and " + names[-1] if len(names) > 1 else names[0]
    html = html.replace("__DATA__", json.dumps({"charts": charts}, separators=(",", ":"))).replace("__TITLE__", title)
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"{len(charts)} charts for {', '.join(args.countries)} -> {args.out}")


if __name__ == "__main__":
    main()
