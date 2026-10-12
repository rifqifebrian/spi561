# Bubble charts of ADB country Input-Output Tables (as of June 2023), e.g.
# Indonesia, Malaysia, Thailand, Viet Nam ("<country>-tables-as-of-june-2023.xlsx").
#
# For every country and every year, draws the 35x35 inter-industry block as a
# grid: y = supplying industry (row), x = purchasing industry (column), and a
# circle at each cell whose AREA is proportional to the transaction value
# ($ million, current prices). The country name is read from the sheet titles.
#
# Usage:
#   Rscript scripts/io_bubble_charts.R <xlsx> [<xlsx> ...] [--out <dir>] [--per-year-scale | --shared-scale]
#
# Example (all four countries in one run):
#   Rscript scripts/io_bubble_charts.R indonesia-tables-as-of-june-2023.xlsx \
#     malaysia-tables-as-of-june-2023.xlsx thailand-tables-as-of-june-2023.xlsx \
#     viet-nam-tables-as-of-june-2023.xlsx --out output/io_bubble_charts
#
# Size scale (circle size -> value):
#   default           one scale per country, shared by all its years
#   --per-year-scale  each chart scaled to its own maximum
#   --shared-scale    one scale for every country and year, so circles are
#                     comparable across countries too
#
# Requires: readxl, ggplot2  (install.packages(c("readxl", "ggplot2")))

suppressPackageStartupMessages({
  library(readxl)
  library(ggplot2)
})

usage <- "Usage: Rscript io_bubble_charts.R <xlsx> [<xlsx> ...] [--out <dir>] [--per-year-scale | --shared-scale]"
args <- commandArgs(trailingOnly = TRUE)
per_year_scale <- "--per-year-scale" %in% args
shared_scale <- "--shared-scale" %in% args
if (per_year_scale && shared_scale) stop("Use only one of --per-year-scale and --shared-scale")
args <- setdiff(args, c("--per-year-scale", "--shared-scale"))
out_dir <- "output/io_bubble_charts"
out_flag <- which(args == "--out")
if (length(out_flag) == 1) {
  if (out_flag == length(args)) stop(usage)
  out_dir <- args[out_flag + 1]
  args <- args[-c(out_flag, out_flag + 1)]
}
xlsx_paths <- args
if (length(xlsx_paths) < 1) stop(usage)
missing <- xlsx_paths[!file.exists(xlsx_paths)]
if (length(missing) > 0) stop("File not found: ", toString(missing))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Short labels for the 35 ADB MRIO sectors (c1..c35), in table order.
short_names <- c(
  "Agriculture", "Mining", "Food & beverages", "Textiles", "Leather & footwear",
  "Wood", "Paper & printing", "Petroleum & coke", "Chemicals",
  "Rubber & plastics", "Non-metal minerals", "Metals", "Machinery",
  "Electrical & optical", "Transport equip.", "Other manufacturing",
  "Utilities", "Construction", "Motor vehicle trade", "Wholesale trade",
  "Retail trade", "Hotels & restaurants", "Inland transport", "Water transport",
  "Air transport", "Transport services", "Telecom", "Finance", "Real estate",
  "Business services", "Public admin.", "Education", "Health & social",
  "Other services", "Households (employers)"
)
codes <- paste0("c", 1:35)
labels <- paste0(short_names, " (", codes, ")")

read_range <- function(path, sheet, range) {
  read_excel(path, sheet = sheet, range = range, col_names = FALSE,
             .name_repair = "minimal")
}
last_year <- function(x) as.integer(sub(".*(\\d{4})\\s*$", "\\1", x))

# Sheet -> year from the "Table of Contents" sheet (columns C and D). Used in
# preference to the sheet titles, which contain typos (e.g. Thailand's
# 2022 sheet is titled "..., 2023").
read_toc_years <- function(path) {
  toc <- read_range(path, "Table of Contents", "C1:D60")
  toc <- toc[!is.na(toc[[2]]) & grepl("^Table 1\\.\\d+$", toc[[2]]), ]
  setNames(last_year(toc[[1]]), toc[[2]])
}

# Layout of each "Table 1.x" sheet (verified for all four countries):
#   A1      title "Table 1.x: <Country> Input-Output Table (35x35), <year>"
#   row 7-41, col C-AK  the 35x35 intermediate-use block
read_year <- function(path, sheet, toc_year) {
  title <- read_range(path, sheet, "A1")[[1]]
  country <- sub("^[^:]*:\\s*(.*?)\\s+Input-Output Table.*$", "\\1", title, perl = TRUE)
  title_year <- last_year(title)
  year <- if (is.na(toc_year)) title_year else toc_year
  if (!identical(year, title_year)) {
    message("Note: ", basename(path), " '", sheet, "' title says ", title_year,
            "; using ", year, " from the Table of Contents")
  }
  row_codes <- read_range(path, sheet, "B7:B41")[[1]]
  col_codes <- unlist(read_range(path, sheet, "C6:AK6"))
  if (!identical(row_codes, codes) || !identical(unname(col_codes), codes)) {
    stop("Unexpected layout in ", basename(path), " sheet '", sheet, "'")
  }
  m <- as.matrix(read_range(path, sheet, "C7:AK41"))
  data.frame(
    country = country,
    year = year,
    from = factor(rep(codes, times = 35), levels = codes, labels = labels),
    to = factor(rep(codes, each = 35), levels = codes, labels = labels),
    value = as.vector(m)
  )
}

read_workbook <- function(path) {
  toc_years <- read_toc_years(path)
  sheets <- grep("^Table 1\\.\\d+$", excel_sheets(path), value = TRUE)
  years <- unname(toc_years[sheets])
  if (anyDuplicated(years[!is.na(years)])) stop("Duplicate years in ", basename(path))
  d <- do.call(rbind, Map(function(s, y) read_year(path, s, y), sheets, years))
  if (length(unique(d$country)) != 1) {
    stop("Expected one country per workbook in ", basename(path), ", found: ",
         toString(unique(d$country)))
  }
  d[order(d$year), ]
}

io <- do.call(rbind, lapply(xlsx_paths, read_workbook))
rownames(io) <- NULL
all_max <- max(io$value, na.rm = TRUE)

scale_note <- if (per_year_scale) {
  "."
} else if (shared_scale) {
  "; same scale for all countries and years."
} else {
  "; same scale for all years."
}

plot_year <- function(d, limit) {
  d <- d[!is.na(d$value) & d$value > 0, ]
  ggplot(d, aes(x = to, y = from, size = value)) +
    geom_point(shape = 21, fill = "#2a78d6", colour = "white",
               stroke = 0.3, alpha = 0.85) +
    scale_size_area(max_size = 14, limits = c(0, limit),
                    breaks = function(l) setdiff(pretty(l), 0),
                    labels = scales::label_comma(),
                    name = "Value\n($ million)") +
    scale_x_discrete(drop = FALSE, position = "top") +
    scale_y_discrete(drop = FALSE, limits = rev) +
    coord_fixed() +
    labs(
      title = paste0(d$country[1], " Input-Output Table, ", d$year[1]),
      subtitle = paste0("Intermediate transactions between industries ",
                        "(current prices, $ million). Circle area = value",
                        scale_note),
      x = "Purchasing industry (column)",
      y = "Supplying industry (row)",
      caption = paste0("Source: ADB, ", d$country[1],
                       " Input-Output Tables (as of June 2023)")
    ) +
    theme_minimal(base_size = 10) +
    theme(
      axis.text.x = element_text(angle = 90, hjust = 0, vjust = 0.5),
      panel.grid.major = element_line(colour = "grey92", linewidth = 0.3),
      plot.title = element_text(face = "bold", size = 14),
      plot.background = element_rect(fill = "white", colour = NA),
      legend.position = "right"
    )
}

for (cd in split(io, io$country)) {
  country <- cd$country[1]
  file_prefix <- paste0("io_bubble_", gsub("[^a-z0-9]+", "_", tolower(country)), "_")
  write.csv(cd, file.path(out_dir, paste0(file_prefix, "long.csv")), row.names = FALSE)

  country_max <- max(cd$value, na.rm = TRUE)
  plots <- lapply(split(cd, cd$year), function(d) {
    limit <- if (per_year_scale) {
      max(d$value, na.rm = TRUE)
    } else if (shared_scale) {
      all_max
    } else {
      country_max
    }
    plot_year(d, limit)
  })

  for (p in plots) {
    ggsave(file.path(out_dir, paste0(file_prefix, p$data$year[1], ".png")), p,
           width = 13, height = 12, dpi = 150)
  }

  # All years of this country in one PDF, one page per year.
  pdf(file.path(out_dir, paste0(file_prefix, "all_years.pdf")), width = 13, height = 12)
  invisible(lapply(plots, print))
  invisible(dev.off())

  message("Wrote ", length(plots), " ", country, " charts")
}

message("Output folder: ", normalizePath(out_dir))
