# Bubble charts of the Viet Nam Input-Output Tables (ADB, as of June 2023).
#
# For every year in the workbook, draws the 35x35 inter-industry block as a
# grid: y = supplying industry (row), x = purchasing industry (column), and a
# circle at each cell whose AREA is proportional to the transaction value
# ($ million, current prices).
#
# Usage:
#   Rscript scripts/io_bubble_charts.R <path/to/viet-nam-tables.xlsx> [out_dir] [--per-year-scale]
#
# By default every year shares one size scale, so circles are comparable
# across years. Pass --per-year-scale to rescale each year to its own max.
#
# Requires: readxl, ggplot2  (install.packages(c("readxl", "ggplot2")))

suppressPackageStartupMessages({
  library(readxl)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
per_year_scale <- "--per-year-scale" %in% args
args <- setdiff(args, "--per-year-scale")
if (length(args) < 1) {
  stop("Usage: Rscript io_bubble_charts.R <xlsx> [out_dir] [--per-year-scale]")
}
xlsx_path <- args[1]
out_dir <- if (length(args) >= 2) args[2] else "output/io_bubble_charts"
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

# Layout of each "Table 1.x" sheet (verified for all 17 sheets):
#   A1      title ending in the year
#   row 7-41, col C-AK  the 35x35 intermediate-use block
read_year <- function(sheet) {
  title <- read_excel(xlsx_path, sheet = sheet, range = "A1", col_names = FALSE, .name_repair = "minimal")[[1]]
  year <- as.integer(sub(".*(\\d{4})\\s*$", "\\1", title))
  row_codes <- read_excel(xlsx_path, sheet = sheet, range = "B7:B41", col_names = FALSE, .name_repair = "minimal")[[1]]
  col_codes <- unlist(read_excel(xlsx_path, sheet = sheet, range = "C6:AK6", col_names = FALSE, .name_repair = "minimal"))
  if (!identical(row_codes, codes) || !identical(unname(col_codes), codes)) {
    stop("Unexpected layout in sheet '", sheet, "'")
  }
  m <- as.matrix(read_excel(xlsx_path, sheet = sheet, range = "C7:AK41", col_names = FALSE, .name_repair = "minimal"))
  data.frame(
    year = year,
    from = factor(rep(codes, times = 35), levels = codes, labels = labels),
    to = factor(rep(codes, each = 35), levels = codes, labels = labels),
    value = as.vector(m)
  )
}

sheets <- grep("^Table 1\\.\\d+$", excel_sheets(xlsx_path), value = TRUE)
io <- do.call(rbind, lapply(sheets, read_year))
io <- io[order(io$year), ]
write.csv(io, file.path(out_dir, "io_long.csv"), row.names = FALSE)

global_max <- max(io$value, na.rm = TRUE)

plot_year <- function(d) {
  d <- d[!is.na(d$value) & d$value > 0, ]
  limit <- if (per_year_scale) max(d$value) else global_max
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
      title = paste0("Viet Nam Input-Output Table, ", d$year[1]),
      subtitle = paste0("Intermediate transactions between industries ",
                        "(current prices, $ million). Circle area = value",
                        if (!per_year_scale) "; same scale for all years." else "."),
      x = "Purchasing industry (column)",
      y = "Supplying industry (row)",
      caption = "Source: ADB, Viet Nam Input-Output Tables (as of June 2023)"
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

plots <- lapply(split(io, io$year), plot_year)

for (p in plots) {
  yr <- p$data$year[1]
  ggsave(file.path(out_dir, paste0("io_bubble_", yr, ".png")), p,
         width = 13, height = 12, dpi = 150)
}

# All years in one PDF, one page per year.
pdf(file.path(out_dir, "io_bubble_all_years.pdf"), width = 13, height = 12)
invisible(lapply(plots, print))
invisible(dev.off())

message("Wrote ", length(plots), " charts to ", normalizePath(out_dir))
