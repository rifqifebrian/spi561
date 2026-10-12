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

## DDI share of gross capital formation

`scripts/ddi_share.R` computes each country's domestic direct investment (DDI)
share as `1 - (FDI inflows / Gross capital formation)`, using two UNCTADstat
exports in `data/raw/` (both in millions of current US$). It removes empty and
"Not applicable" cells, joins the predecessor series for Indonesia, Ethiopia and
Sudan onto their current series, joins the two sources by country and year
(1990-2024), and adds a flag for unusual values (negative FDI, FDI greater than
GCF, GCF of zero or less).

```
Rscript scripts/ddi_share.R
```

Outputs: `output/ddi_share_long.csv` (country-year detail) and
`output/ddi_share_wide.csv` (countries x years).
