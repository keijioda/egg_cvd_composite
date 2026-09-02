
# Required libraries
pacs <- c("tidyverse", "survival", "mice", "kableExtra")
sapply(pacs, require, character.only = TRUE)


# Read the list of imputed data -------------------------------------------

imputed_data_list <- readRDS("./Data/imputed_data_list.rds")
# imputed_data_list <- readRDS("./Data/imputed_data_list_prev_2yrs.rds")


# Cox models --------------------------------------------------------------

# Model 1 -----------------------------------------------------------------

# Demographics, lifestyles, egg intake (as categorical) and kcal

# Full model
mod1_full_fm <- Surv(agein, ageout, inc_CVD) ~ egg_freq4 + bene_sex_F + rti_race3 + marital +
  educyou2 + bmicat + exercise + sleephrs2 + smokecat6 + alccat + kcal100

# Reduced model
mod1_reduced_fm <- update(mod1_full_fm, . ~ . - egg_freq4)

# Fit both models
fit_mod1_full <- lapply(imputed_data_list, function(d) {
  coxph(mod1_full_fm, data = d, method = "efron")
})

fit_mod1_reduced <- lapply(imputed_data_list, function(d) {
  coxph(mod1_reduced_fm, data = d, method = "efron")
})

# Convert to mira
mira_fit_mod1_full <- as.mira(fit_mod1_full)
mira_fit_mod1_reduced <- as.mira(fit_mod1_reduced)

# Pool the results
pooled <- pool(mira_fit_mod1_full)
summary(pooled)

# Multivariate Wald test for egg frequency 
D1(mira_fit_mod1_full, mira_fit_mod1_reduced)


# Model 2 -----------------------------------------------------------------

# Adjusting for other foods
# Meat as categorical, other food groups as continuous

# Full model
mod2_full_fm <- update(
  mod1_full_fm, 
  . ~ . + meat_gram_ea100 + fish_gram_ea100 + alldairy2_gram_ea100 + totalveg_gram_ea100 +
    fruits_gram_ea100 + refgrains_gram_ea100 + whole_mixed_grains_gram_ea100 +
    nutsseeds_gram_ea100 + legumes_gram_ea100
)

# Reduced model
mod2_reduced_fm <- update(mod2_full_fm, . ~ . - egg_freq4)

# Fit both models
fit_mod2_full <- lapply(imputed_data_list, function(d) {
  coxph(mod2_full_fm, data = d, method = "efron")
})

fit_mod2_reduced <- lapply(imputed_data_list, function(d) {
  coxph(mod2_reduced_fm, data = d, method = "efron")
})

# Convert to mira
mira_fit_mod2_full <- as.mira(fit_mod2_full)
mira_fit_mod2_reduced <- as.mira(fit_mod2_reduced)

# Pool the results
pooled <- pool(mira_fit_mod2_full)
summary(pooled)

D1(mira_fit_mod2_full, mira_fit_mod2_reduced)


# Model 3 -----------------------------------------------------------------

# Further adjusting for comorbidity 

# Full model
mod3_full_fm <- update(
  mod2_full_fm, 
  . ~ . + como_depress + como_disab + como_diabetes + como_hyperl  + como_resp + 
    como_anemia + como_kidney + como_hypoth + como_cancers
)

# Reduced model
mod3_reduced_fm <- update(mod3_full_fm, . ~ . - egg_freq4)

# Fit both models
fit_mod3_full <- lapply(imputed_data_list, function(d) {
  coxph(mod3_full_fm, data = d, method = "efron")
})

fit_mod3_reduced <- lapply(imputed_data_list, function(d) {
  coxph(mod3_reduced_fm, data = d, method = "efron")
})

# Convert to mira
mira_fit_mod3_full <- as.mira(fit_mod3_full)
mira_fit_mod3_reduced <- as.mira(fit_mod3_reduced)

# Pool the results
pooled <- pool(mira_fit_mod3_full)
summary(pooled)

D1(mira_fit_mod3_full, mira_fit_mod3_reduced)


# Checking interactions ---------------------------------------------------

# Based on Model 3
# Check for egg x meat interaction -- Significant p = 0.018
mod4a_full_fm <- update(mod3_full_fm, . ~ . + egg_freq4 * meat_gram_ea100)

fit_mod4a_full <- lapply(imputed_data_list, function(d) {
  coxph(mod4a_full_fm, data = d, method = "efron")
})

mira_fit_mod4a_full <- as.mira(fit_mod4a_full)

# Pool the results
pooled <- pool(mira_fit_mod4a_full)
summary(pooled)

D1(mira_fit_mod4a_full, mira_fit_mod3_full)

# Check for egg x fish interaction -- Not significant p = 0.34  
mod4b_full_fm <- update(mod3_full_fm, . ~ . + egg_freq4 * fish_gram_ea100)

fit_mod4b_full <- lapply(imputed_data_list, function(d) {
  coxph(mod4b_full_fm, data = d, method = "efron")
})

mira_fit_mod4b_full <- as.mira(fit_mod4b_full)
D1(mira_fit_mod4b_full, mira_fit_mod3_full)

# Check for egg x dairy interaction -- Not significant p =  0.18  
mod4c_full_fm <- update(mod3_full_fm, . ~ . + egg_freq4 * alldairy2_gram_ea100)

fit_mod4c_full <- lapply(imputed_data_list, function(d) {
  coxph(mod4c_full_fm, data = d, method = "efron")
})

mira_fit_mod4c_full <- as.mira(fit_mod4c_full)
D1(mira_fit_mod4c_full, mira_fit_mod3_full)

# Check for egg x race interaction -- Not significant p = 0.69 
mod4d_full_fm <- update(mod3_full_fm, . ~ . + egg_freq4 * rti_race3)

fit_mod4d_full <- lapply(imputed_data_list, function(d) {
  coxph(mod4d_full_fm, data = d, method = "efron")
})

mira_fit_mod4d_full <- as.mira(fit_mod4d_full)
D1(mira_fit_mod4d_full, mira_fit_mod3_full)


# HRs for other variables -------------------------------------------------

# Extract variable names from the formula (preserve model order)
var_names_ordered <- all.vars(mod4a_full_fm)[-(1:3)] %>%   # drop agein, ageout, inc_CVD
  unique()

# Longest-first version, used only for matching (avoids partial-match issues like sleephrs2 vs sleephrs)
var_names_for_match <- var_names_ordered[order(-nchar(var_names_ordered))]

extract_var_level <- function(term, var_names) {
  term <- as.character(term)
  match_idx <- which(startsWith(term, var_names))[1]
  if (is.na(match_idx)) {
    return(tibble(Variable = term, Level = NA_character_))
  }
  v <- var_names[match_idx]
  lvl <- sub(paste0("^", v), "", term)
  tibble(Variable = v, Level = ifelse(lvl == "", NA_character_, lvl))
}

result <- mira_fit_mod4a_full %>% 
  pool() %>% 
  summary(conf.int = TRUE, exp = TRUE, conf.level = .95) %>% 
  select(term, estimate, conf.low, conf.high, p.value) %>% 
  filter(!str_detect(term, "egg|meat")) %>% 
  mutate(
    HR = sprintf("%.2f (%.2f, %.2f)", estimate, conf.low, conf.high),
    p.value = ifelse(p.value < 0.0001, "<.0001", sprintf("%.4f", p.value))
  )

var_level <- purrr::map_dfr(as.character(result$term), extract_var_level, var_names = var_names_for_match)

result %>% 
  bind_cols(var_level) %>% 
  select(Variable, Level, HR, p.value) %>% 
  knitr::kable(row.names = FALSE)


# HRs with egg x meat interaction -----------------------------------------

# Pool coefficient vector + FULL covariance matrix via Rubin's rules
# (this is what pool() does internally before it collapses to per-term
# variances — we need to stop one step earlier and keep the matrix)
pool_coef_vcov <- function(fit_list) {
  m <- length(fit_list)
  coefs <- lapply(fit_list, coef)
  vcovs <- lapply(fit_list, vcov)
  
  qbar <- Reduce(`+`, coefs) / m                      # pooled point estimate
  ubar <- Reduce(`+`, vcovs) / m                       # within-imputation covariance
  b    <- Reduce(`+`, lapply(coefs, function(q) tcrossprod(q - qbar))) / (m - 1)  # between-imputation covariance
  t_mat <- ubar + (1 + 1 / m) * b                      # total pooled covariance
  
  list(qbar = qbar, vcov = t_mat)
}

# Generalized joint HR: egg level e vs "None", meat = m vs 0, from the SAME
# joint reference cell (None, meat=0) -- includes the meat main effect,
# unlike intx_hr_egg_pooled() which held meat fixed across the comparison.
joint_hr_pooled <- function(fit_list, meat_main_term, egg_main_term = NULL,
                            egg_meat_intx_term = NULL, meat_gram_value) {
  p <- pool_coef_vcov(fit_list)
  qbar <- p$qbar
  V    <- p$vcov
  
  L <- qbar
  L[] <- 0
  L[meat_main_term] <- meat_gram_value
  if (!is.null(egg_main_term))      L[egg_main_term]      <- 1
  if (!is.null(egg_meat_intx_term)) L[egg_meat_intx_term] <- meat_gram_value
  
  est <- qbar %*% L
  se  <- sqrt(t(L) %*% V %*% L)
  lwr <- est - qnorm(0.975) * se
  upr <- est + qnorm(0.975) * se
  c(est, lwr, upr) %>% exp()
}

# Egg terms, including "None" (no main/interaction term -- reference level)
egg_terms <- list(
  "None"   = list(main = NULL, intx = NULL),
  "1-3/mo" = list(main = "egg_freq41-3/mo", intx = "egg_freq41-3/mo:meat_gram_ea100"),
  "1-4/wk" = list(main = "egg_freq41-4/wk", intx = "egg_freq41-4/wk:meat_gram_ea100"),
  "5+/wk"  = list(main = "egg_freq45+/wk",  intx = "egg_freq45+/wk:meat_gram_ea100")
)

# Meat values in grams/day, as in the table -- converted to the model's
# _100 scale (meat_gram_ea100 = meat_gram_ea / 100) inside the call
meat_values_gramday <- c(0, 10, 30, 100)

hr_table <- expand_grid(
  egg_freq4    = names(egg_terms),
  meat_gramday = meat_values_gramday
) %>%
  pmap_dfr(function(egg_freq4, meat_gramday) {
    terms <- egg_terms[[egg_freq4]]
    hr <- joint_hr_pooled(
      fit_mod4a_full,
      meat_main_term     = "meat_gram_ea100",
      egg_main_term      = terms$main,
      egg_meat_intx_term = terms$intx,
      meat_gram_value    = meat_gramday / 100
    )
    data.frame(egg_freq4 = egg_freq4, meat_gramday = meat_gramday,
               HR = hr[1], lwr = hr[2], upr = hr[3])
  }) %>%
  mutate(egg_freq4 = factor(egg_freq4, levels = names(egg_terms)))

hr_table

hr_table_wide <- hr_table %>%
  mutate(
    is_ref = egg_freq4 == "None" & meat_gramday == 0,
    cell   = ifelse(is_ref, "1.00 (Ref)", sprintf("%.2f (%.2f, %.2f)", HR, lwr, upr))
  ) %>%
  select(meat_gramday, egg_freq4, cell) %>%
  pivot_wider(names_from = egg_freq4, values_from = cell)

hr_table_wide

# Forest plot
meat_values_gramday <- c(0, 10, 30, 100)   # match what you used to build hr_table

plot_data <- hr_table %>%
  mutate(
    egg_label = recode(as.character(egg_freq4),
                       "None"   = "Egg intake: None",
                       "1-3/mo" = "Egg intake: 1-3 times/month",
                       "1-4/wk" = "Egg intake: 1-4 times/week",
                       "5+/wk"  = "Egg intake: 5+ times/week"),
    egg_label = factor(egg_label, levels = c("Egg intake: None",
                                             "Egg intake: 1-3 times/month",
                                             "Egg intake: 1-4 times/week",
                                             "Egg intake: 5+ times/week")),
    meat_label = factor(paste0("Meat: ", meat_gramday, " g/d"),
                        levels = paste0("Meat: ", rev(meat_values_gramday), " g/d")),
    is_ref  = egg_freq4 == "None" & meat_gramday == 0,
    sig_cat = case_when(
      is_ref  ~ "Reference",
      lwr > 1 ~ "HR > 1, significant",
      upr < 1 ~ "HR < 1, significant",
      TRUE    ~ "Not significant"
    ),
    sig_cat = factor(sig_cat, levels = c("HR > 1, significant", "HR < 1, significant",
                                         "Not significant", "Reference")),
    label = ifelse(is_ref, "1.00 (Ref)", sprintf("%.2f (%.2f, %.2f)", HR, lwr, upr))
  )

x_label_pos <- max(plot_data$upr, na.rm = TRUE) * 1.15   # just past the widest CI bar
x_max       <- x_label_pos * 1.20                          # room for the text column itself

p <- ggplot(plot_data, aes(x = HR, y = meat_label, color = sig_cat, shape = sig_cat)) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "grey60") +
  geom_errorbar(aes(xmin = lwr, xmax = upr), width = 0, linewidth = 0.7,
                orientation = "y", data = filter(plot_data, !is_ref)) +
  geom_point(size = 3) +
  geom_text(aes(x = x_label_pos, label = label), color = "black", hjust = 0, size = 3.6) +
  facet_wrap(vars(egg_label), ncol = 1, scales = "free_y", strip.position = "top") +
  scale_x_log10(breaks = c(0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0),
                limits = c(0.75, x_max),
                expand = expansion(mult = c(0.02, 0.02))) +
  scale_color_manual(values = c("HR > 1, significant" = "#D2691E",
                                 "HR < 1, significant" = "#1B5E56",
                                 "Not significant"     = "grey55",
                                 "Reference"            = "black"),
                     breaks = c("HR > 1, significant", "HR < 1, significant")) +
  scale_shape_manual(values = c("HR > 1, significant" = 16,
                                 "HR < 1, significant" = 16,
                                 "Not significant"     = 16,
                                 "Reference"             = 18),
                     breaks = c("HR > 1, significant", "HR < 1, significant")) +
  # labs(x = "Hazard ratio (log scale)", y = NULL,
  #      title = "Hazard ratios for combinations of egg and meat intake",
  #      subtitle = "(Reference: No egg and no meat)") +
   labs(x = "Hazard ratio (log scale)", y = NULL) +
  theme_minimal(base_size = 13) +
  theme(
    strip.placement    = "outside",
    strip.text         = element_text(face = "bold", hjust = 0, size = 13),
    strip.background   = element_rect(fill = "grey93", color = NA),
    panel.spacing      = unit(0.6, "lines"),
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_blank(),
    legend.position    = "bottom",
    legend.title       = element_blank(),
    plot.title         = element_text(face = "bold"),
    axis.text.y        = element_text(size = 11)
  ) +
  coord_cartesian(clip = "off")


pdf("forest_plot_hazard_ratios.pdf", width = 8, height = 9)
print(p)
dev.off()

ggsave("forest_plot_hazard_ratios.png", p, width = 8, height = 9, dpi = 300)


# P-trend for meat intake -------------------------------------------------

# Main effect meat_gram_ea100 is the trend test for ref = "None"
# Trend for meat intake at egg freq = "None"
summary(pooled) %>% filter(term == "meat_gram_ea100")

# Pooled version of get_wald_p() -- uses Rubin's-rules pooled coefficient
# vector and FULL pooled covariance matrix (from pool_coef_vcov(), defined
# earlier), instead of a single model's coef()/vcov().
get_wald_p_pooled <- function(fit_list, coef_names, coef_wt) {
  p    <- pool_coef_vcov(fit_list)
  qbar <- p$qbar
  V    <- p$vcov
  
  # Safety check: every requested name must exist in the pooled coefficient
  # vector, or L[coef_names] <- coef_wt would silently create NA entries
  # instead of erroring.
  missing_terms <- setdiff(coef_names, names(qbar))
  if (length(missing_terms) > 0) {
    stop("Term(s) not found in model coefficients: ",
         paste(missing_terms, collapse = ", "))
  }
  
  L <- qbar
  L[] <- 0
  L[coef_names] <- coef_wt
  
  est    <- qbar %*% L
  se     <- sqrt(t(L) %*% V %*% L)
  wald_p <- as.numeric(2 * (1 - pnorm(abs(est / se))))
  return(wald_p)
}

# Trend for meat intake at egg freq = "1-3x / month"
get_wald_p_pooled(
  fit_mod4a_full,
  coef_names = c("meat_gram_ea100", "egg_freq41-3/mo:meat_gram_ea100"),
  coef_wt    = c(1, 1)
)

# Trend for meat intake at egg freq = "1-4x / week"
get_wald_p_pooled(
  fit_mod4a_full,
  coef_names = c("meat_gram_ea100", "egg_freq41-4/wk:meat_gram_ea100"),
  coef_wt    = c(1, 1)
)

# Trend for meat intake at egg freq = "5x+ / week"
get_wald_p_pooled(
  fit_mod4a_full,
  coef_names = c("meat_gram_ea100", "egg_freq45+/wk:meat_gram_ea100"),
  coef_wt    = c(1, 1)
)


# P-trend for egg intake --------------------------------------------------

# Replace egg_freq4 with its numeric values, 1, 2, 3, 4
mod4b_full_fm <- update(
  mod4a_full_fm, 
  . ~ . - egg_freq4 - egg_freq4:meat_gram_ea100 + as.numeric(egg_freq4) + as.numeric(egg_freq4):meat_gram_ea100
  )

fit_mod4b_full <- lapply(imputed_data_list, function(d) {
  coxph(mod4b_full_fm, data = d, method = "efron")
})

# Main effect as.numeric(egg_freq4) is the trend test for Meat intake = 0
# Trend for egg freq at meat intake = 0
fit_mod4b_full %>% 
  as.mira() %>% 
  pool() %>% 
  summary() %>% 
  filter(term == "as.numeric(egg_freq4)")

# Trend for egg intake at meat intake = 0
get_wald_p_pooled(
  fit_mod4b_full,
  coef_names = c("as.numeric(egg_freq4)", "meat_gram_ea100:as.numeric(egg_freq4)"),
  coef_wt    = c(1, 0)
)

# Trend for egg intake at meat intake = 10
get_wald_p_pooled(
  fit_mod4b_full,
  coef_names = c("as.numeric(egg_freq4)", "meat_gram_ea100:as.numeric(egg_freq4)"),
  coef_wt    = c(1, 10 / 100)
)

# Trend for egg intake at meat intake = 30
get_wald_p_pooled(
  fit_mod4b_full,
  coef_names = c("as.numeric(egg_freq4)", "meat_gram_ea100:as.numeric(egg_freq4)"),
  coef_wt    = c(1, 30 / 100)
)

# Trend for egg intake at meat intake = 100
get_wald_p_pooled(
  fit_mod4b_full,
  coef_names = c("as.numeric(egg_freq4)", "meat_gram_ea100:as.numeric(egg_freq4)"),
  coef_wt    = c(1, 100 / 100)
)


# Incorporate trend p into the table --------------------------------------

# Collect the meat trend p-values, one per egg group (columns)
p_trend_meat <- c(
  "None"   = summary(pooled) %>% filter(term == "meat_gram_ea100") %>% pull(p.value),
  "1-3/mo" = get_wald_p_pooled(fit_mod4a_full,
                               coef_names = c("meat_gram_ea100", "egg_freq41-3/mo:meat_gram_ea100"),
                               coef_wt    = c(1, 1)),
  "1-4/wk" = get_wald_p_pooled(fit_mod4a_full,
                               coef_names = c("meat_gram_ea100", "egg_freq41-4/wk:meat_gram_ea100"),
                               coef_wt    = c(1, 1)),
  "5+/wk"  = get_wald_p_pooled(fit_mod4a_full,
                               coef_names = c("meat_gram_ea100", "egg_freq45+/wk:meat_gram_ea100"),
                               coef_wt    = c(1, 1))
)

# Collect the egg trend p-values, one per meat level (rows)
p_trend_egg <- c(
  "0"   = get_wald_p_pooled(fit_mod4b_full,
                            coef_names = c("as.numeric(egg_freq4)", "meat_gram_ea100:as.numeric(egg_freq4)"),
                            coef_wt    = c(1, 0)),
  "10"  = get_wald_p_pooled(fit_mod4b_full,
                            coef_names = c("as.numeric(egg_freq4)", "meat_gram_ea100:as.numeric(egg_freq4)"),
                            coef_wt    = c(1, 10 / 100)),
  "30"  = get_wald_p_pooled(fit_mod4b_full,
                            coef_names = c("as.numeric(egg_freq4)", "meat_gram_ea100:as.numeric(egg_freq4)"),
                            coef_wt    = c(1, 30 / 100)),
  "100" = get_wald_p_pooled(fit_mod4b_full,
                            coef_names = c("as.numeric(egg_freq4)", "meat_gram_ea100:as.numeric(egg_freq4)"),
                            coef_wt    = c(1, 100 / 100))
)

# Helper to format p-values consistently
fmt_p <- function(p) ifelse(p < 0.0001, "<0.0001", sprintf("%.4f", p))

# Add the right-margin column (egg trend p, one per meat row)
hr_table_wide <- hr_table_wide %>%
  mutate(`P-trend (egg)` = fmt_p(p_trend_egg[as.character(meat_gramday)]))

# Add the bottom-margin row (meat trend p, one per egg column)
bottom_row <- setNames(
  as.list(c(
    NA,
    fmt_p(p_trend_meat[c("None", "1-3/mo", "1-4/wk", "5+/wk")]),
    ""
  )),
  names(hr_table_wide)
) %>% as_tibble()

hr_table_final <- hr_table_wide %>%
  mutate(meat_gramday = as.character(meat_gramday)) %>%
  bind_rows(bottom_row) %>%
  mutate(meat_gramday = ifelse(is.na(meat_gramday), "P-trend (meat)", meat_gramday))

hr_table_final


# HRs for egg freq at meat intake levels ----------------------------------

# Function to estimate pooled HR for egg with interaction
intx_hr_egg_pooled <- function(fit_list, egg_main_term, egg_meat_intx_term, meat_gram_value) {
  p    <- pool_coef_vcov(fit_list)
  qbar <- p$qbar
  V    <- p$vcov
  
  # Safety check, same pattern as get_wald_p_pooled()
  needed <- c(egg_main_term, egg_meat_intx_term)
  missing_terms <- setdiff(needed, names(qbar))
  if (length(missing_terms) > 0) {
    stop("Term(s) not found in model coefficients: ",
         paste(missing_terms, collapse = ", "))
  }
  
  L <- qbar
  L[] <- 0
  L[egg_main_term]      <- 1
  L[egg_meat_intx_term] <- meat_gram_value
  
  est <- qbar %*% L
  se  <- sqrt(t(L) %*% V %*% L)
  lwr <- est - qnorm(0.975) * se
  upr <- est + qnorm(0.975) * se
  c(est, lwr, upr) %>% exp()
}

egg_labels <- c("1-3/mo", "1-4/wk", "5+/wk")
egg_main_terms <- c("egg_freq41-3/mo", "egg_freq41-4/wk", "egg_freq45+/wk")
egg_intx_terms <- c("egg_freq41-3/mo:meat_gram_ea100",
                    "egg_freq41-4/wk:meat_gram_ea100",
                    "egg_freq45+/wk:meat_gram_ea100")

# Helper to build the HR table for one meat value, looping over all 3 egg terms
egg_hr_at_meat <- function(fit_list, meat_gramday) {
  purrr::pmap_dfr(
    list(egg_main_terms, egg_intx_terms, egg_labels),
    function(main_term, intx_term, label) {
      hr <- intx_hr_egg_pooled(fit_list, main_term, intx_term, meat_gramday / 100)
      tibble(Meat = paste0(meat_gramday, " g/d"), Egg = label,
             HR = hr[1], Lower = hr[2], Upper = hr[3])
    }
  )
}

meat_values_gramday <- c(0, 10, 30, 100)
egg_hr_table <- purrr::map_dfr(meat_values_gramday, ~ egg_hr_at_meat(fit_mod4a_full, .x))

egg_hr_wide <- egg_hr_table %>%
  mutate(
    meat_gramday = as.numeric(sub(" g/d", "", Meat)),
    cell = sprintf("%.2f (%.2f, %.2f)", HR, Lower, Upper)
  ) %>%
  select(meat_gramday, Egg, cell) %>%
  pivot_wider(names_from = Egg, values_from = cell) %>%
  mutate(None = "1.00 (Ref)") %>%
  select(meat_gramday, None, `1-3/mo`, `1-4/wk`, `5+/wk`) %>%
  arrange(meat_gramday) %>%
  mutate(`P-trend` = fmt_p(p_trend_egg[as.character(meat_gramday)]))

egg_hr_wide

egg_hr_wide %>%
  kable(
    col.names = c("Meat intake (gram/day)", "None", "1-3 times/month",
                  "1-4 times/week", "5+ times/week", "P-trend"),
    align = "lccccc",
    caption = "Hazard ratio for egg intake at various meat intake (at each meat intake level, the reference is those who do not eat any eggs)"
  ) %>%
  kable_styling(full_width = FALSE) %>%
  add_header_above(c(" " = 1, "Egg frequency" = 4, " " = 1))

# Add "None" reference rows (HR = 1, no CI) for each meat level
none_rows <- tibble(
  Meat = paste0(c(0, 10, 30, 100), " g/d"),
  Egg  = "None",
  HR = 1, Lower = NA, Upper = NA,
  meat_gramday = c(0, 10, 30, 100)
)

egg_hr_plot_data <- egg_hr_table %>%
  mutate(meat_gramday = as.numeric(sub(" g/d", "", Meat))) %>%
  bind_rows(none_rows) %>%
  mutate(Egg = factor(Egg, levels = c("None", "1-3/mo", "1-4/wk", "5+/wk")))

p2 <- ggplot(egg_hr_plot_data, aes(x = Egg, y = HR)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey50") +
  geom_point(aes(shape = Egg == "None", color = Egg == "None"),
             size = 3, show.legend = FALSE) +
  geom_errorbar(aes(ymin = Lower, ymax = Upper), width = 0.2) +
  scale_shape_manual(values = c("TRUE" = 18, "FALSE" = 16)) +
  scale_color_manual(values = c("TRUE" = "red", "FALSE" = "black")) +
  scale_x_discrete(labels = c("None" = "None\n(Ref)", "1-3/mo" = "1-3/mo",
                              "1-4/wk" = "1-4/wk", "5+/wk" = "5+/wk")) +
  scale_y_log10(breaks = c(0.6, 0.7, 0.8, 0.9, 1, 1.5, 2)) +
  facet_wrap(~ factor(meat_gramday, levels = c(0, 10, 30, 100),
                      labels = paste0("Meat: ", c(0, 10, 30, 100), " g/d")),
             nrow = 1) +
  labs(x = "Egg intake frequency", y = "Hazard ratio (log scale)") +
  theme_minimal() +
  theme(
    strip.background = element_rect(fill = "grey85", color = "grey50"),
    strip.text = element_text(face = "bold")
  )

pdf("./Results/egg_HR_by_meat_line_plot.pdf", width = 10, height = 3)
print(p2)
dev.off()

ggsave("./Results/egg_HR_by_meat_line_plot.png", p2, width = 10, height = 3, dpi = 300)


# Substitution analysis ---------------------------------------------------

fit_mod4a_full %>% pool() %>% summary()

# Function to extract betas and vcov(beta)
get_pooled_estimates <- function(fit_mira) {
  pooled_summary <- fit_mira %>% pool() %>% summary(conf.int = TRUE)
  bhat <- pooled_summary$estimate
  names(bhat) <- pooled_summary$term
  
  fit_analyses <- fit_mira$analyses
  m <- length(fit_analyses)
  qhats <- sapply(fit_analyses, coef)
  qbar <- rowMeans(qhats)
  vw <- Reduce("+", lapply(fit_analyses, vcov)) / m
  vb <- (1 / (m - 1)) * (qhats - qbar) %*% t(qhats - qbar)
  vt <- vw + (1 + 1 / m) * vb
  dimnames(vt) <- list(names(bhat), names(bhat))
  
  list(bhat = bhat, vt = vt)
}

est <- get_pooled_estimates(fit_mod4a_full %>% as.mira())
bhat <- est$bhat
vt   <- est$vt

# loc    : character vector of term names entering the linear combination
# weight : numeric vector of same length, the multiplier for each term
get_est_beta_substitute <- function(bhat, vt, loc, weight) {
  a <- weight
  b <- bhat[loc]
  est_cbeta <- sum(a * b)
  
  v <- vt[loc, loc]
  subs_b_var <- as.numeric(t(a) %*% v %*% a)
  
  ci <- est_cbeta + qnorm(c(.025, .975)) * sqrt(subs_b_var)
  out <- exp(c(est = est_cbeta, lower = ci[1], upper = ci[2]))
  return(out)
}

# Evaluate at a grid of meat levels
meat_grid <- c(0, 10, 30, 100) / 100

# Names for egg terms and their interaction with meat
egg_terms <- c("egg_freq41-3/mo", "egg_freq41-4/wk", "egg_freq45+/wk")
int_terms <- paste0(egg_terms, ":meat_gram_ea100")

## Substitution with legumes ----------------------------------------------

# calorie-equivalent for each category's midpoint frequency (eggs/month -> legume g/day)
egg_freq <- c(2/30, 2.5/7, 1) 
gram_equivs <- 60 * egg_freq / 100

all_results <- lapply(seq_along(egg_terms), function(i) {
  loc <- c(egg_terms[i], int_terms[i], "legumes_gram_ea100")
  t(sapply(meat_grid, function(m_val) {
    weight <- c(1, m_val, -gram_equivs[i])
    get_est_beta_substitute(bhat, vt, loc, weight)
  }))
})
names(all_results) <- egg_terms

# Format "est (lower, upper)" strings, 2 decimals
fmt_hr <- function(mat) {
  sprintf("%.2f (%.2f, %.2f)", mat[, "est"], mat[, "lower"], mat[, "upper"])
}

# convert to actual grams/day for the table
meat_gramday <- meat_grid * 100

# Wide format
subs_egg_for_legumes_hr_wide <- tibble(
  meat_gramday = meat_gramday,
  None = "1.00 (Ref)",
  `1-3/mo` = fmt_hr(all_results[["egg_freq41-3/mo"]]),
  `1-4/wk` = fmt_hr(all_results[["egg_freq41-4/wk"]]),
  `5+/wk`  = fmt_hr(all_results[["egg_freq45+/wk"]])
)

subs_egg_for_legumes_hr_wide


## Substitution with nuts/seeds -------------------------------------------

# calorie-equivalent for each category's midpoint frequency (eggs/month -> nuts g/day)
egg_freq <- c(2/30, 2.5/7, 1) 
gram_equivs <- 14 * egg_freq / 100

all_results <- lapply(seq_along(egg_terms), function(i) {
  loc <- c(egg_terms[i], int_terms[i], "nutsseeds_gram_ea100")
  t(sapply(meat_grid, function(m_val) {
    weight <- c(1, m_val, -gram_equivs[i])
    get_est_beta_substitute(bhat, vt, loc, weight)
  }))
})
names(all_results) <- egg_terms

# Format "est (lower, upper)" strings, 2 decimals
fmt_hr <- function(mat) {
  sprintf("%.2f (%.2f, %.2f)", mat[, "est"], mat[, "lower"], mat[, "upper"])
}

# convert to actual grams/day for the table
meat_gramday <- meat_grid * 100

# Wide format
subs_egg_for_nuts_hr_wide <- tibble(
  meat_gramday = meat_gramday,
  None = "1.00 (Ref)",
  `1-3/mo` = fmt_hr(all_results[["egg_freq41-3/mo"]]),
  `1-4/wk` = fmt_hr(all_results[["egg_freq41-4/wk"]]),
  `5+/wk`  = fmt_hr(all_results[["egg_freq45+/wk"]])
)

subs_egg_for_nuts_hr_wide


# Checking for PH assumptions ---------------------------------------------

# Using the 1st imputed data
imp1 <- imputed_data_list[[1]]

cox_imp1 <- coxph(
  formula(fit_mod4a_full[[1]]),
  data = imp1,
  model = TRUE
)

# zph p-values are too sensitive when you have a large sample...
zph_result <- cox.zph(cox_imp1)
zph_result

# Scatter plot of the scaled Schoenfeld residuals for meat
# Ignore some outliers
# Should scatter randomly around zero with no trend over time
plot(
  zph_result, 
  var = "meat_gram_ea100", 
  ylim = c(-20, 20),
  col = c("gray70", "red"), 
  lwd = 3
  )

# Scatter plot of the scaled Schoenfeld residuals for egg
plot(
  zph_result, 
  var = "egg_freq4",
  col = c("gray70", "red"), 
  lwd = 3
)

pdf("./Results/cox_zph_all_plots.pdf", width = 8, height = 6)
  plot(zph_result, col = c("gray70", "red"), lwd = 2)
dev.off()

# Using ggplot
plot_zph_gg <- function(zph_obj, term, ylim = NULL, point_alpha = 0.3, 
                        point_size = 1, spline_df = 4) {
  time_vals <- zph_obj$x
  resid_vals <- zph_obj$y[, term]
  
  df <- data.frame(time = time_vals, resid = resid_vals)
  
  p <- ggplot(df, aes(x = time, y = resid)) +
    geom_point(alpha = point_alpha, size = point_size, color = "gray30") +
    geom_smooth(
      method = "loess",
      se = TRUE,
      color = "red",
      fill = "red",
      alpha = 0.3,        # transparency of the CI ribbon
      linewidth = 1
    ) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    labs(
      x = "Time",
      y = paste("Beta(t) for", term),
      title = term
    ) +
    theme_minimal()
  
  if (!is.null(ylim)) {
    p <- p + coord_cartesian(ylim = ylim)
  }
  
  return(p)
}

# Build individual panels
p_meat <- plot_zph_gg(zph_result, "meat_gram_ea100", ylim = c(-20, 20))
p_egg  <- plot_zph_gg(zph_result, "egg_freq4")

# Combine side by side with patchwork
library(patchwork)
p_meat + p_egg

# For each of egg_freq4 categorical variable
zph_bylevel <- cox.zph(cox_imp1, terms = FALSE)
egg_dummy_terms <- grep("^egg_freq4", colnames(zph_bylevel$y), value = TRUE)
egg_dummy_terms <- egg_dummy_terms[1:3]

# Check
egg_dummy_terms

# Produce zph plots
egg_zph_plots <- lapply(egg_dummy_terms, function(term) {
  plot_zph_gg(zph_bylevel, term, ylim = c(-30, 50))
})

# Combine them
p_egg_zph_bylevel <- wrap_plots(egg_zph_plots, ncol = 1)

pdf("./Results/egg_freq4_zph_by_level.pdf", width = 7, height = 12)
print(p_egg_zph_bylevel)
dev.off()

# Checking the linearity on dietary variables -----------------------------

library(rms)
library(Hmisc)

# --- Step 1: Fix knot locations across all imputed datasets --------------
vars_rcs <- c("meat_gram_ea", "fish_gram_ea", "alldairy2_gram_ea",
              "totalveg_gram_ea", "fruits_gram_ea", "refgrains_gram_ea",
              "whole_mixed_grains_gram_ea", "nutsseeds_gram_ea", "legumes_gram_ea")

stacked_data <- bind_rows(imputed_data_list)

knot_list <- lapply(vars_rcs, function(v) {
  rcspline.eval(stacked_data[[v]], nk = 4, knots.only = TRUE)
})
names(knot_list) <- vars_rcs

# --- Step 2: Fit cph with FIXED knots on each imputed dataset ------------
# Build the rcs terms programmatically with explicit knot locations
rcs_terms <- sapply(vars_rcs, function(v) {
  k <- paste(round(knot_list[[v]], 4), collapse = ",")
  sprintf("rcs(%s, parms = c(%s))", v, k)
})

rcs_formula_rhs <- paste(rcs_terms, collapse = " + ")

mod3_rcs_fm <- as.formula(paste(
  "Surv(agein, ageout, inc_CVD) ~ bene_sex_F + rti_race3 + marital + educyou2 +",
  "bmicat + exercise + sleephrs2 + smokecat6 + alccat + kcal100 +", rcs_formula_rhs
))

fit_mod3_rcs_list <- lapply(imputed_data_list, function(d) {
  dd <- datadist(d)
  options(datadist = "dd")
  cph(mod3_rcs_fm, data = d, method = "efron", x = TRUE, y = TRUE)
})

# --- Step 3: Pool coefficients + covariance via Rubin's rules -------------
pooled_rcs <- pool_coef_vcov(fit_mod3_rcs_list)
qbar <- pooled_rcs$qbar
V    <- pooled_rcs$vcov

# --- Step 4: Multi-df Wald chi-square test for nonlinearity --------------
wald_chisq_pooled <- function(qbar, V, coef_names) {
  L <- matrix(0, nrow = length(coef_names), ncol = length(qbar),
              dimnames = list(coef_names, names(qbar)))
  for (i in seq_along(coef_names)) L[i, coef_names[i]] <- 1
  
  Lq   <- L %*% qbar
  LVLt <- L %*% V %*% t(L)
  chisq <- as.numeric(t(Lq) %*% solve(LVLt) %*% Lq)
  df    <- length(coef_names)
  p     <- pchisq(chisq, df = df, lower.tail = FALSE)
  c(chisq = chisq, df = df, p_nonlinear = p)
}

# Nonlinear terms for a given rcs variable are all basis columns EXCEPT the
# first (linear) one -- with 4 knots, rcs() produces 3 basis columns total:
# 1 linear + 2 nonlinear. Term names follow the pattern "var", "var'", "var''"
nonlinear_terms <- function(varname, all_names) {
  grep(paste0("^", varname, "'"), all_names, value = TRUE)
}

# --- Step 5: Run nonlinearity test for each rcs variable ------------------
nonlin_results <- lapply(vars_rcs, function(v) {
  nl_terms <- nonlinear_terms(v, names(qbar))
  res <- wald_chisq_pooled(qbar, V, nl_terms)
  data.frame(variable = v, chisq = res["chisq"], df = res["df"], p_nonlinear = res["p_nonlinear"])
}) %>% bind_rows()

nonlin_results %>% 
  as_tibble() %>% 
  knitr::kable(digits = c(0, 2, 0, 4))
