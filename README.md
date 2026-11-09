# SPI561: Comparative Political Economy of Development
Comparative political economy of development between Vietnam, Malaysia, and Indonesia

## GDP growth analysis

`scripts/find_high_growth_countries.py` finds countries whose GDP growth
(annual %, World Bank indicator `NY.GDP.MKTP.KD.ZG`) stayed above a given
threshold for every year in a given range. Data lives in `data/` and was
sourced from the [World Bank World Development Indicators](https://data.worldbank.org/indicator/NY.GDP.MKTP.KD.ZG).

```
python3 scripts/find_high_growth_countries.py --start 2010 --end 2018 --threshold 5
```

## Input-Output bubble charts (Indonesia, Malaysia, Thailand, Viet Nam)

`scripts/io_bubble_charts.R` reads one or more ADB country *Input-Output
Tables* workbooks (`<country>-tables-as-of-june-2023.xlsx`, one sheet per year,
2000 and 2007-2022) and draws, for every country and year, the 35x35
inter-industry block as a bubble matrix: y = supplying industry,
x = purchasing industry, circle area = transaction value ($ million).
The country is read from the sheet titles and the year from each workbook's
Table of Contents.

```
Rscript scripts/io_bubble_charts.R \
  indonesia-tables-as-of-june-2023.xlsx malaysia-tables-as-of-june-2023.xlsx \
  thailand-tables-as-of-june-2023.xlsx viet-nam-tables-as-of-june-2023.xlsx \
  --out output/io_bubble_charts
```

For each country it writes one PNG per year, a multi-page PDF with all years,
and a long-format CSV, prefixed with the country (e.g.
`io_bubble_thailand_2022.png`). By default each country's years share one size
scale; `--shared-scale` puts every country and year on one scale (to compare
countries), and `--per-year-scale` scales each chart to its own maximum.
Requires the `readxl` and `ggplot2` R packages.

## Export basket treemap (Atlas of Economic Complexity style)

`scripts/export_treemap.py` turns a UN Comtrade export download (one reporter,
one year, partner = World, HS at 2/4/6 digits) into a self-contained
interactive HTML page in the style of the Harvard Atlas of Economic
Complexity: a treemap of exports by HS4 product grouped into sectors (click a
sector to see its HS6 products), sector shares, concentration figures and the
top 20 HS6 products. The page template is `scripts/export_treemap_template.html`.

```
python3 scripts/export_treemap.py data/comtrade_malaysia_exports_1989_hs6.csv \
  --out output/malaysia_exports_1989.html
```

`data/comtrade_malaysia_exports_1989_hs6.csv` holds Malaysia's 1989 exports
(HS 1992). Complexity indices (ECI, PCI, RCA, product space) need every
country's exports for the same year and are not computed.

## Export tables by SITC product (Malaysia, Indonesia, 1964-2024)

`scripts/export_share_tables.R` reads `data/export_sitc2.csv` (Harvard Atlas
of Economic Complexity, SITC Rev. 2 two-digit divisions) and writes LaTeX
tables with, for every product and year, the export value (US$ million) and
its share of the country's total goods exports. Divisions are grouped under
their bold 1-digit SITC section with a subtotal; the last row is total
exports. Each country gets one landscape `longtable` per block of about five
years. Product names come from `data/sitc2_names.csv`.

```
Rscript scripts/export_share_tables.R
cd output && pdflatex export_share_document.tex
```

`output/export_share_tables.tex` holds only the tables, so you can `\input`
it into your own document (it needs `array`, `booktabs`, `longtable` and
`pdflscape`). `output/export_share_document.tex` is a minimal wrapper that
compiles them. Edit the settings at the top of the script to add Viet Nam or
change the years. Requires the `dplyr`, `tidyr` and `readr` R packages.

## Line charts by SITC section (Malaysia and Indonesia, 1964-2024)

`scripts/export_section_lines.R` adds up the 2-digit divisions in
`data/export_mys2.csv` (Malaysia) and `data/export_idn2.csv` (Indonesia) into
the ten 1-digit SITC sections and draws, for each country (file prefix `mys_`
or `idn_`), two small-multiple line charts with one panel per section:

- `output/<prefix>sitc1_export_value.png/.pdf`: export value in US$ billion,
  each panel on its own vertical scale;
- `output/<prefix>sitc1_export_share.png/.pdf`: share of total exports, all
  panels on the same scale, with the other nine sections in grey behind.

Add a row to the `countries` table at the top of the script to chart another
country.

```
Rscript scripts/export_section_lines.R
```

Requires the `dplyr`, `readr`, `ggplot2` and `scales` R packages.
