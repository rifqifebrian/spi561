#!/usr/bin/env python3
"""
Find countries with continuous GDP growth above a threshold across a year range,
using World Bank indicator NY.GDP.MKTP.KD.ZG (GDP growth, annual %).

Usage:
    python3 scripts/find_high_growth_countries.py
    python3 scripts/find_high_growth_countries.py --start 2010 --end 2018 --threshold 5
"""

import argparse
import csv
import os

DEFAULT_DATA_FILE = os.path.join(
    os.path.dirname(__file__), "..", "data",
    "API_NY.GDP.MKTP.KD.ZG_DS2_en_csv_v2_346275.csv",
)
DEFAULT_METADATA_FILE = os.path.join(
    os.path.dirname(__file__), "..", "data",
    "Metadata_Country_API_NY.GDP.MKTP.KD.ZG_DS2_en_csv_v2_346275.csv",
)


def load_real_country_codes(metadata_path):
    """World Bank data includes regional/income aggregates (e.g. 'World',
    'East Asia & Pacific') alongside real countries. Aggregates have an
    empty 'Region' field in the metadata file, so we use that to exclude them.
    """
    codes = set()
    with open(metadata_path, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            if row.get("Region", "").strip():
                codes.add(row["Country Code"])
    return codes


def load_growth_data(data_path):
    """Returns {country_name: {year: growth_pct}}."""
    with open(data_path, newline="", encoding="utf-8-sig") as f:
        lines = f.readlines()

    # The World Bank export has 4 metadata lines before the real header row.
    reader = csv.DictReader(lines[4:])
    data = {}
    for row in reader:
        name = row.get("Country Name")
        code = row.get("Country Code")
        if not name or not code:
            continue
        years = {}
        for key, value in row.items():
            if key and key.isdigit() and value not in (None, ""):
                try:
                    years[int(key)] = float(value)
                except ValueError:
                    pass
        data[name] = {"code": code, "years": years}
    return data


def find_continuous_high_growth(data, real_codes, start, end, threshold):
    results = []
    for name, info in data.items():
        if info["code"] not in real_codes:
            continue
        years = info["years"]
        if all(years.get(y, float("-inf")) > threshold for y in range(start, end + 1)):
            results.append((name, [years[y] for y in range(start, end + 1)]))
    results.sort(key=lambda item: min(item[1]), reverse=True)
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start", type=int, default=2010)
    parser.add_argument("--end", type=int, default=2018)
    parser.add_argument("--threshold", type=float, default=5.0)
    parser.add_argument("--data", default=DEFAULT_DATA_FILE)
    parser.add_argument("--metadata", default=DEFAULT_METADATA_FILE)
    args = parser.parse_args()

    real_codes = load_real_country_codes(args.metadata)
    data = load_growth_data(args.data)
    results = find_continuous_high_growth(
        data, real_codes, args.start, args.end, args.threshold
    )

    years = list(range(args.start, args.end + 1))
    header = ["Country"] + [str(y) for y in years]
    print(f"Countries with GDP growth > {args.threshold}% every year from "
          f"{args.start} to {args.end}:\n")
    print(", ".join(header))
    for name, values in results:
        row = [name] + [f"{v:.1f}" for v in values]
        print(", ".join(row))

    if not results:
        print("(none found)")
    else:
        print(f"\n{len(results)} countr{'y' if len(results) == 1 else 'ies'} found.")


if __name__ == "__main__":
    main()
