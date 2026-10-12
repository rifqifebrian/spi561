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
