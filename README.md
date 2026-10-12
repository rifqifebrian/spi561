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

## Input-Output bubble charts (Viet Nam, Indonesia)

`scripts/io_bubble_charts.R` reads an ADB country *Input-Output Tables*
workbook (e.g. Viet Nam or Indonesia; the country is read from the sheet titles) (one sheet per year, 2000 and 2007-2022) and draws, for every year,
the 35x35 inter-industry block as a bubble matrix: y = supplying industry,
x = purchasing industry, circle area = transaction value ($ million).

```
Rscript scripts/io_bubble_charts.R viet-nam-tables-as-of-june-2023.xlsx output/io_bubble_charts
Rscript scripts/io_bubble_charts.R indonesia-tables-as-of-june-2023.xlsx output/io_bubble_charts
```

Outputs one PNG per year, a multi-page PDF with all years, and a long-format CSV,
all prefixed with the country (e.g. `io_bubble_indonesia_2022.png`). All years share one size scale; add
`--per-year-scale` to scale each year to its own maximum instead.
Requires the `readxl` and `ggplot2` R packages.
