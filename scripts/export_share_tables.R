# =============================================================================
# Export tables by SITC (Rev. 2) product: export value and share of total
# exports, for Malaysia and Indonesia, 1964-2024.
#
# Input : data/export_sitc2.csv   (Harvard Atlas download, one row per
#                                  country x SITC 2-digit division x year)
#         data/sitc2_names.csv    (names of SITC sections and divisions)
# Output: output/export_share_tables.tex      (the tables only, to \input)
#         output/export_share_document.tex    (a small document that
#                                              compiles the tables to PDF)
#
# Run from the repository root:
#   Rscript scripts/export_share_tables.R
#
# Needs the R packages dplyr, tidyr and readr.
# The LaTeX needs the packages array, booktabs, longtable and pdflscape.
# =============================================================================

library(dplyr)
library(tidyr)
library(readr)


# ---- 1. Settings you may want to change -------------------------------------

countries <- c(
  MYS = "Malaysia",
  IDN = "Indonesia"
  # VNM = "Viet Nam"   # <- uncomment to add Viet Nam
)

first_year <- 1964
last_year  <- 2024

# The years do not fit side by side on one page, so each country gets one
# table per block of years. These are the first years of each block.
block_starts <- c(1964, seq(1970, 2020, by = 5))  # 1964-69, 1970-74, ..., 2020-24

input_file  <- "data/export_sitc2.csv"
names_file  <- "data/sitc2_names.csv"
tables_file <- "output/export_share_tables.tex"
doc_file    <- "output/export_share_document.tex"


# ---- 2. Read the data -------------------------------------------------------

# Read the SITC code as text, so that "05" keeps its leading zero later.
exports <- read_csv(input_file,
                    col_types = cols(product_sitc_code = col_character()))

sitc_names <- read_csv(names_file, col_types = cols(.default = col_character()))

exports <- exports %>%
  filter(country_iso3_code %in% names(countries),
         year >= first_year, year <= last_year) %>%
  # Every code in the file is a 2-digit SITC division, but the Atlas drops the
  # leading zero ("5" is division 05, Vegetables and fruit). Put it back.
  mutate(division = sprintf("%02d", as.integer(product_sitc_code)),
         section  = substr(division, 1, 1),        # 1-digit SITC section
         country  = countries[country_iso3_code]) %>%
  select(country, year, section, division, export_value)


# ---- 3. Compute values and shares -------------------------------------------

# Total exports of each country in each year = sum over all divisions.
totals <- exports %>%
  group_by(country, year) %>%
  summarise(total = sum(export_value), .groups = "drop")

# Division rows (e.g. 05 Vegetables and fruit).
division_rows <- exports %>%
  rename(code = division) %>%
  select(country, year, section, code, export_value)

# Section rows (e.g. 0 Food and live animals) = sum of their divisions.
section_rows <- exports %>%
  group_by(country, year, section) %>%
  summarise(export_value = sum(export_value), .groups = "drop") %>%
  mutate(code = section)

# Stack both, then add the share of total exports (in percent).
table_data <- bind_rows(section_rows, division_rows) %>%
  left_join(totals, by = c("country", "year")) %>%
  mutate(value_musd = export_value / 1e6,          # US$ millions
         share_pct  = 100 * export_value / total) %>%
  left_join(sitc_names, by = "code") %>%
  mutate(is_section = nchar(code) == 1)

# Sanity check: shares add up to 100 % in every country-year.
check <- table_data %>%
  filter(!is_section) %>%
  group_by(country, year) %>%
  summarise(sum_share = sum(share_pct), .groups = "drop")
stopifnot(all(abs(check$sum_share - 100) < 1e-6))


# ---- 4. Small helpers for writing LaTeX -------------------------------------

# Escape characters that have a special meaning in LaTeX.
latex_escape <- function(text) {
  text <- gsub("&", "\\&", text, fixed = TRUE)
  text <- gsub("%", "\\%", text, fixed = TRUE)
  text
}

# Format numbers; a division a country did not report that year shows "--".
format_value <- function(x) {
  ifelse(is.na(x), "--", formatC(x, format = "f", digits = 1, big.mark = ","))
}
format_share <- function(x) {
  ifelse(is.na(x), "--", formatC(x, format = "f", digits = 2))
}

# Join cells into one LaTeX table row.
latex_row <- function(cells) paste0(paste(cells, collapse = " & "), " \\\\")


# ---- 5. Build one LaTeX table (one country, one block of years) -------------

make_table <- function(country_name, years) {

  # Wide layout: one row per SITC code, two columns (value, share) per year.
  wide <- table_data %>%
    filter(country == country_name, year %in% years) %>%
    select(code, name, is_section, year, value_musd, share_pct) %>%
    pivot_wider(names_from  = year,
                values_from = c(value_musd, share_pct)) %>%
    arrange(code)    # "0", "00", "01", ..., "1", "11", ... keeps sections first

  n_years <- length(years)
  totals_here <- totals %>%
    filter(country == country_name, year %in% years) %>%
    arrange(year)

  # Column layout: code, name, then value + share for every year.
  col_spec <- paste0("@{}l >{\\raggedright\\arraybackslash}p{5cm} ",
                     paste(rep("rr", n_years), collapse = " "), "@{}")

  # Header: years on the first line, "Value | %" under each year.
  year_header <- latex_row(c("", "",
    sprintf("\\multicolumn{2}{c}{%d}", years)))
  rules <- paste(sprintf("\\cmidrule(lr){%d-%d}",
                         seq(3, by = 2, length.out = n_years),
                         seq(4, by = 2, length.out = n_years)),
                 collapse = "")
  unit_header <- latex_row(c("SITC", "Product",
    rep(c("US\\$ m", "\\%"), n_years)))
  header <- c(year_header, rules, unit_header)

  # Body: section rows in bold, division rows indented.
  body <- character(0)
  for (i in seq_len(nrow(wide))) {
    row <- wide[i, ]
    values <- format_value(unlist(row[paste0("value_musd_", years)]))
    shares <- format_share(unlist(row[paste0("share_pct_", years)]))
    numbers <- as.vector(rbind(values, shares))   # value, share, value, share ...

    if (row$is_section) {
      if (i > 1) body <- c(body, "\\addlinespace")
      cells <- c(sprintf("\\textbf{%s}", row$code),
                 sprintf("\\textbf{%s}", latex_escape(row$name)),
                 sprintf("\\textbf{%s}", numbers))
    } else {
      cells <- c(row$code,
                 paste0("\\quad ", latex_escape(row$name)),
                 numbers)
    }
    body <- c(body, latex_row(cells))
  }

  # Last row: total exports (share is 100 % by definition).
  total_cells <- as.vector(rbind(format_value(totals_here$total / 1e6), "100.00"))
  total_row <- latex_row(c("", "\\textbf{Total exports}",
                           sprintf("\\textbf{%s}", total_cells)))

  caption <- sprintf(paste(
    "%s: exports by SITC product, %d--%d.",
    "\\textnormal{Value in US\\$ million and share of the country's total",
    "goods exports in that year (\\%%). SITC Rev.~2 sections in bold,",
    "2-digit divisions indented. -- = not reported.",
    "Source: Harvard Growth Lab, Atlas of Economic Complexity.}"),
    country_name, min(years), max(years))
  label <- sprintf("tab:exports-%s-%d", tolower(gsub(" ", "", country_name)), min(years))

  c("\\begin{landscape}",
    "\\scriptsize",
    "\\setlength{\\tabcolsep}{3pt}",
    sprintf("\\begin{longtable}{%s}", col_spec),
    sprintf("\\caption{%s}\\label{%s}\\\\", caption, label),
    "\\toprule", header, "\\midrule",
    "\\endfirsthead",
    sprintf("\\multicolumn{%d}{@{}l}{\\textit{Table \\thetable{} continued}}\\\\",
            2 + 2 * n_years),
    "\\toprule", header, "\\midrule",
    "\\endhead",
    "\\midrule",
    sprintf("\\multicolumn{%d}{r@{}}{\\textit{Continued on next page}}\\\\",
            2 + 2 * n_years),
    "\\endfoot",
    "\\bottomrule",
    "\\endlastfoot",
    body,
    "\\midrule",
    total_row,
    "\\end{longtable}",
    "\\end{landscape}",
    "")
}


# ---- 6. Write all tables to the output files --------------------------------

year_blocks <- split(first_year:last_year,
                     findInterval(first_year:last_year, block_starts))

all_tables <- character(0)
for (country_name in countries) {
  for (years in year_blocks) {
    all_tables <- c(all_tables, make_table(country_name, years))
  }
}

dir.create(dirname(tables_file), showWarnings = FALSE, recursive = TRUE)
writeLines(c("% Generated by scripts/export_share_tables.R -- do not edit by hand.",
             "% Needs \\usepackage{array, booktabs, longtable, pdflscape}",
             "",
             all_tables),
           tables_file)

# A minimal document so the tables can be compiled straight away.
writeLines(c("\\documentclass[a4paper,10pt]{article}",
             "\\usepackage[margin=1.5cm]{geometry}",
             "\\usepackage[T1]{fontenc}",
             "\\usepackage{array, booktabs, longtable, pdflscape}",
             "\\usepackage[font=small, labelfont=bf, textfont=bf]{caption}",
             "\\begin{document}",
             sprintf("\\input{%s}", basename(tables_file)),
             "\\end{document}"),
           doc_file)

cat("Wrote", length(countries) * length(year_blocks), "tables to", tables_file, "\n")
cat("Compile with:  cd output && pdflatex", basename(doc_file), "\n")
