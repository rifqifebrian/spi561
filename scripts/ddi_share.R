# Domestic Direct Investment (DDI) share of gross capital formation
#
#   DDI share = 1 - (FDI inflows / Gross capital formation)
#
# Inputs (UNCTADstat exports, both in millions of US$ at current prices):
#   data/raw/US.FdiFlowsStock_*.csv        FDI inward flows, 1990-2025
#   data/raw/US.GDPComponent_10004_*.csv   GDP by expenditure components, 1970-2024
#
# Outputs:
#   output/ddi_share_long.csv   one row per country-year (FDI, GCF, DDI share, flags)
#   output/ddi_share_wide.csv   countries x years matrix of DDI share
#
# Run from the repository root:  Rscript scripts/ddi_share.R

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(stringr)
})

raw_dir <- "data/raw"
out_dir <- "output"
dir.create(out_dir, showWarnings = FALSE)

fdi_file <- list.files(raw_dir, pattern = "^US\\.FdiFlowsStock_.*\\.csv$", full.names = TRUE)
gdp_file <- list.files(raw_dir, pattern = "^US\\.GDPComponent_.*\\.csv$", full.names = TRUE)
stopifnot(length(fdi_file) == 1, length(gdp_file) == 1)

# UNCTADstat wide export -> long table.
# Each year has three columns: <year>_..._Value, <year>_..._Footnote, <year>_..._MissingValue.
unctad_to_long <- function(df, id_cols) {
  df %>%
    pivot_longer(
      cols = -all_of(id_cols),
      names_to = c("year", "field"),
      names_pattern = "^(\\d{4})_.*_(Value|Footnote|MissingValue)$",
      values_transform = as.character
    ) %>%
    pivot_wider(names_from = field, values_from = value) %>%
    mutate(
      year  = as.integer(year),
      value = suppressWarnings(as.numeric(Value))
    )
}

# Historical entities whose series end exactly where the current entity's
# series begins (no overlapping years in either file), so they can be spliced
# into one continuous country series.
predecessors <- c(
  "Indonesia (...2002)" = "Indonesia",  # incl. Timor-Leste until 2002
  "Ethiopia (...1991)"  = "Ethiopia",   # incl. Eritrea until 1991
  "Sudan (...2011)"     = "Sudan"       # incl. South Sudan until 2011
)

clean_economy <- function(x) {
  x <- str_squish(x)
  recode(x, !!!predecessors)
}

# ---- FDI inflows ------------------------------------------------------------
fdi <- read_csv(fdi_file, col_types = cols(.default = col_character()),
                locale = locale(encoding = "UTF-8")) %>%
  rename(economy_raw = Economy_Label) %>%
  filter(economy_raw != "Individual economies") %>%      # section header row
  unctad_to_long("economy_raw") %>%
  mutate(
    economy = clean_economy(economy_raw),
    fdi_footnote = na_if(str_squish(Footnote), "")
  ) %>%
  filter(!is.na(value)) %>%                               # drop blanks / "Not applicable"
  select(economy, year, fdi = value, fdi_footnote)

# ---- Gross capital formation ------------------------------------------------
gcf <- read_csv(gdp_file, col_types = cols(.default = col_character()),
                locale = locale(encoding = "UTF-8")) %>%
  rename(economy_raw = Economy_Label, component = Component_Label) %>%
  filter(economy_raw != "Individual economies",
         str_squish(component) == "Gross capital formation") %>%
  select(-component) %>%
  unctad_to_long("economy_raw") %>%
  mutate(economy = clean_economy(economy_raw)) %>%
  filter(!is.na(value)) %>%
  select(economy, year, gcf = value)

# Splicing must never create two values for the same country-year.
stopifnot(!anyDuplicated(fdi[c("economy", "year")]),
          !anyDuplicated(gcf[c("economy", "year")]))

# ---- Integrate and compute --------------------------------------------------
# Inner join: DDI share needs both FDI and GCF, so only country-years present in
# both sources are kept (years 1990-2024).
ddi <- inner_join(fdi, gcf, by = c("economy", "year")) %>%
  mutate(
    fdi_to_gcf = if_else(gcf > 0, fdi / gcf, NA_real_),  # GCF <= 0: ratio undefined
    ddi_share  = 1 - fdi_to_gcf,
    flag = case_when(
      is.na(ddi_share) ~ "GCF zero or negative: share undefined",
      fdi < 0          ~ "Negative FDI (disinvestment): share > 1",
      fdi > gcf        ~ "FDI exceeds GCF: share < 0",
      TRUE             ~ NA_character_
    )
  ) %>%
  arrange(economy, year)

write_csv(ddi, file.path(out_dir, "ddi_share_long.csv"), na = "")

ddi %>%
  select(economy, year, ddi_share) %>%
  pivot_wider(names_from = year, values_from = ddi_share, names_sort = TRUE) %>%
  write_csv(file.path(out_dir, "ddi_share_wide.csv"), na = "")

# ---- Cleaning report --------------------------------------------------------
fdi_only <- setdiff(unique(fdi$economy), unique(gcf$economy))
gcf_only <- setdiff(unique(gcf$economy), unique(fdi$economy))

cat("Country-years in output :", nrow(ddi), "\n")
cat("Countries in output     :", n_distinct(ddi$economy), "\n")
cat("Years                   :", paste(range(ddi$year), collapse = "-"), "\n")
cat("Dropped (no GCF data)   :", paste(fdi_only, collapse = "; "), "\n")
cat("Dropped (no FDI data)   :", paste(gcf_only, collapse = "; "), "\n")
cat("\nFlagged observations:\n")
print(count(ddi, flag))

cat("\nComparison cases, DDI share:\n")
ddi %>%
  filter(economy %in% c("Indonesia", "Malaysia", "Viet Nam"), year >= 2015) %>%
  select(economy, year, ddi_share) %>%
  pivot_wider(names_from = economy, values_from = ddi_share) %>%
  mutate(across(-year, ~ round(.x, 3))) %>%
  as.data.frame() %>%
  print(row.names = FALSE)
