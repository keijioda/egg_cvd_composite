
# Required libraries
pacs <- c("tidyverse", "survival", "mice")
sapply(pacs, require, character.only = TRUE)


# Read the list of imputed data -------------------------------------------

imputed_data_list <- readRDS("./Data/imputed_data_list.rds")


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

mod4a_full_fm

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
  mutate(cell = sprintf("%.2f (%.2f, %.2f)", HR, lwr, upr)) %>%
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

