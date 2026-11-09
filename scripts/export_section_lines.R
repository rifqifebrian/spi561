# =============================================================================
# Line charts of Malaysia's exports by 1-digit SITC (Rev. 2) section, by year.
#
# Input : data/export_mys2.csv    (Harvard Atlas download, Malaysia,
#                                  one row per SITC 2-digit division x year)
#         data/sitc2_names.csv    (names of SITC sections and divisions)
# Output: output/mys_sitc1_export_value.png / .pdf
#         output/mys_sitc1_export_share.png / .pdf
#
# Run from the repository root:
#   Rscript scripts/export_section_lines.R
#
# Needs the R packages dplyr, readr, ggplot2 and scales.
# =============================================================================

library(dplyr)
library(readr)
library(ggplot2)


# ---- 1. Settings ------------------------------------------------------------

input_file  <- "data/export_mys2.csv"
names_file  <- "data/sitc2_names.csv"
country     <- "Malaysia"
output_stem <- "output/mys_sitc1_"

line_colour    <- "#2a78d6"   # the highlighted section
context_colour <- "#d6d5d0"   # the other nine sections, in the background
text_colour    <- "#52514e"


# ---- 2. Read the data and add up divisions into sections --------------------

exports <- read_csv(input_file,
                    col_types = cols(product_sitc_code = col_character()))

sitc_names <- read_csv(names_file, col_types = cols(.default = col_character()))

sections <- exports %>%
  # Every code is a 2-digit SITC division, but the Atlas drops the leading
  # zero ("5" is division 05). The section is the first digit of "05" -> "0".
  mutate(division = sprintf("%02d", as.integer(product_sitc_code)),
         section  = substr(division, 1, 1)) %>%
  group_by(year, section) %>%
  summarise(export_value = sum(export_value), .groups = "drop") %>%
  group_by(year) %>%
  mutate(share_pct = 100 * export_value / sum(export_value)) %>%
  ungroup() %>%
  left_join(sitc_names, by = c("section" = "code")) %>%
  # Panel title, e.g. "7  Machinery and transport equipment"
  mutate(panel = factor(paste0(section, "  ", name)),
         value_bn = export_value / 1e9)

first_year <- min(sections$year)
last_year  <- max(sections$year)


# ---- 3. A shared look for both charts ---------------------------------------

chart_theme <- theme_minimal(base_size = 10) +
  theme(
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = "#ebeae6", linewidth = 0.3),
    strip.text         = element_text(hjust = 0, face = "bold", size = 8.5),
    axis.text          = element_text(colour = text_colour, size = 7.5),
    axis.title         = element_text(colour = text_colour, size = 8.5),
    plot.title         = element_text(face = "bold", size = 13),
    plot.subtitle      = element_text(colour = text_colour, size = 9.5),
    plot.caption       = element_text(colour = text_colour, size = 7.5, hjust = 0),
    plot.title.position   = "plot",
    plot.caption.position = "plot",
    panel.spacing      = unit(10, "pt"),
    plot.background    = element_rect(fill = "white", colour = NA)
  )

year_axis <- scale_x_continuous(breaks = seq(1970, 2020, by = 10),
                                expand = expansion(mult = 0.02))

source_note <- paste0(
  "Source: Harvard Growth Lab, Atlas of Economic Complexity (SITC Rev. 2). ",
  "Values in current US$.")

save_chart <- function(plot, name) {
  for (ext in c("png", "pdf")) {
    ggsave(paste0(output_stem, name, ".", ext), plot,
           width = 10, height = 8.5, dpi = 200, bg = "white")
  }
}


# ---- 4. Chart 1: export value, one panel per section ------------------------

# Each panel has its own y-axis: sections differ by two orders of magnitude,
# and a shared axis would flatten the small ones.
value_chart <- ggplot(sections, aes(x = year, y = value_bn)) +
  geom_line(colour = line_colour, linewidth = 0.7) +
  facet_wrap(~ panel, ncol = 2, scales = "free_y",
             labeller = label_wrap_gen(width = 50)) +
  year_axis +
  scale_y_continuous(labels = scales::label_comma(accuracy = 0.1),
                     limits = c(0, NA),
                     expand = expansion(mult = c(0, 0.08))) +
  labs(title    = sprintf("%s: exports by SITC section, %d-%d",
                          country, first_year, last_year),
       subtitle = "Export value, US$ billion. Each panel has its own vertical scale.",
       x = NULL, y = "US$ billion",
       caption = source_note) +
  chart_theme

save_chart(value_chart, "export_value")


# ---- 5. Chart 2: share of total exports, same scale in every panel ----------

# The grey lines are the other nine sections, so each panel shows where its
# section stands relative to the rest.
background <- sections %>%
  rename(other_section = panel) %>%
  select(year, share_pct, other_section)

share_chart <- ggplot(sections, aes(x = year, y = share_pct)) +
  geom_line(data = background,
            aes(group = other_section),
            colour = context_colour, linewidth = 0.35) +
  geom_line(colour = line_colour, linewidth = 0.8) +
  facet_wrap(~ panel, ncol = 2,
             labeller = label_wrap_gen(width = 50)) +
  year_axis +
  scale_y_continuous(labels = function(x) paste0(x, "%"),
                     limits = c(0, NA),
                     expand = expansion(mult = c(0, 0.05))) +
  labs(title    = sprintf("%s: share of total exports by SITC section, %d-%d",
                          country, first_year, last_year),
       subtitle = "Share of total goods exports in each year. Grey lines: the other nine sections.",
       x = NULL, y = "Share of total exports",
       caption = source_note) +
  chart_theme

save_chart(share_chart, "export_share")

cat("Wrote", paste0(output_stem, c("export_value", "export_share"), ".png/.pdf"),
    sep = "\n  ")
