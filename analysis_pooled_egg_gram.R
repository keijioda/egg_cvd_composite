
# Required libraries
pacs <- c("tidyverse", "survival", "mice", "kableExtra", "rms")
sapply(pacs, require, character.only = TRUE)


# Read the list of imputed data -------------------------------------------

imputed_data_list <- readRDS("./Data/imputed_data_list.rds")
# imputed_data_list <- readRDS("./Data/imputed_data_list_prev_2yrs.rds")


# Cox models --------------------------------------------------------------

# Model 1 -----------------------------------------------------------------

# Demographics, lifestyles, egg intake (gram/day, energy-adjusted) and kcal
mod1_full_fm <- Surv(agein, ageout, inc_CVD) ~ eggs_gram_ea + bene_sex_F + rti_race3 + marital +
  educyou2 + bmicat + exercise + sleephrs2 + smokecat6 + alccat + kcal100

# Model 2 -----------------------------------------------------------------

# Adjusting for other foods
# Meat as categorical, other food groups as continuous
mod2_full_fm <- update(
  mod1_full_fm, 
  . ~ . + meat_gram_ea100 + fish_gram_ea100 + alldairy2_gram_ea100 + totalveg_gram_ea100 +
    fruits_gram_ea100 + refgrains_gram_ea100 + whole_mixed_grains_gram_ea100 +
    nutsseeds_gram_ea100 + legumes_gram_ea100
)

# Model 3 -----------------------------------------------------------------

# Further adjusting for comorbidity 
mod3_full_fm <- update(
  mod2_full_fm, 
  . ~ . + como_depress + como_disab + como_diabetes + como_hyperl  + como_resp + 
    como_anemia + como_kidney + como_hypoth + como_cancers
)

# Prep for spline ---------------------------------------------------------

# Fix knots for eggs_gram_ea on the stacked imputed data
stacked_data <- bind_rows(imputed_data_list)

# Using 4 kntos
egg_knots <- rcspline.eval(stacked_data$eggs_gram_ea, nk = 4, knots.only = TRUE)
egg_knots

# Model 4 -----------------------------------------------------------------

# Replace eggs_gram_ea with its spline terms

mod4_egg_rcs_fm <- update(
  mod3_full_fm,
  . ~ . - eggs_gram_ea + rcs(eggs_gram_ea, parms = egg_knots)
)

# Reduced model: main effects only (egg spline + meat, no interaction)
mod4a_reduced_fm <- mod4_egg_rcs_fm

# Full model: + egg spline x meat interaction (expands to 4 terms)
mod4a_full_fm <- update(
  mod4_egg_rcs_fm,
  . ~ . + rcs(eggs_gram_ea, parms = egg_knots):meat_gram_ea100
)

# Fit full & reduced on imputed data --------------------------------------

fit_mod4a_reduced <- lapply(imputed_data_list, function(d) {
  coxph(mod4a_reduced_fm, data = d, method = "efron")
})

fit_mod4a_full <- lapply(imputed_data_list, function(d) {
  coxph(mod4a_full_fm, data = d, method = "efron")
})

# Sanity check: full model should have exactly 3 more coefficients than
# reduced (the 3 spline-basis x meat interaction terms)
length(coef(fit_mod4a_full[[1]])) - length(coef(fit_mod4a_reduced[[1]])) == 3 

# Convert to mira
mira_fit_mod4a_reduced <- as.mira(fit_mod4a_reduced)
mira_fit_mod4a_full    <- as.mira(fit_mod4a_full)

# Omnibus test: are ANY of the 4 spline x meat interaction terms non-zero?
D1(mira_fit_mod4a_full, mira_fit_mod4a_reduced)


# Omnibus test ------------------------------------------------------------
# Test linear and non-linear terms separately as well

# Helper functions
pool_coef_vcov <- function(fit_list) {
  m <- length(fit_list)
  coefs <- lapply(fit_list, coef)
  vcovs <- lapply(fit_list, vcov)

  qbar <- Reduce(`+`, coefs) / m
  ubar <- Reduce(`+`, vcovs) / m
  b    <- Reduce(`+`, lapply(coefs, function(q) tcrossprod(q - qbar))) / (m - 1)
  t_mat <- ubar + (1 + 1 / m) * b

  list(qbar = qbar, vcov = t_mat)
}

# Wald test
wald_chisq_pooled <- function(qbar, V, coef_names) {
  L <- matrix(0, nrow = length(coef_names), ncol = length(qbar),
              dimnames = list(coef_names, names(qbar)))
  for (i in seq_along(coef_names)) L[i, coef_names[i]] <- 1

  Lq   <- L %*% qbar
  LVLt <- L %*% V %*% t(L)
  chisq <- as.numeric(t(Lq) %*% solve(LVLt) %*% Lq)
  df    <- length(coef_names)
  p     <- pchisq(chisq, df = df, lower.tail = FALSE)
  c(chisq = chisq, df = df, p = p)
}

fmt_p <- function(p) ifelse(p < 0.0001, "<0.0001", sprintf("%.4f", p))

# Full model
pooled_full <- pool_coef_vcov(fit_mod4a_full)
qbar_full <- pooled_full$qbar
V_full    <- pooled_full$vcov


# Check term names
names(qbar_full)

egg_meat_intx_terms <- names(qbar_full)[
  str_detect(names(qbar_full), fixed("eggs_gram_ea")) &
  str_detect(names(qbar_full), fixed("meat_gram_ea100"))
]

# Should be 3 terms
egg_meat_intx_terms

# Linear component = the one egg x meat term whose egg portion has NO
# trailing prime (') character; nonlinear = the other 3
linear_intx_term     <- egg_meat_intx_terms[!str_detect(egg_meat_intx_terms, "'")]
nonlinear_intx_terms <- egg_meat_intx_terms[ str_detect(egg_meat_intx_terms, "'")]

# There should be one linear term and three non-linear terms
linear_intx_term
nonlinear_intx_terms

omnibus_check <- wald_chisq_pooled(qbar_full, V_full, egg_meat_intx_terms)

# 1 df: linear egg x meat interaction alone
linear_test <- wald_chisq_pooled(qbar_full, V_full, linear_intx_term)

# 3 df: nonlinear egg x meat interactions, jointly, from the full model
nonlinear_test <- wald_chisq_pooled(qbar_full, V_full, nonlinear_intx_terms)

decomposition_results <- tibble(
  test  = c("Omnibus", "Linear interaction",
            "Nonlinear interaction"),
  chisq = c(omnibus_check["chisq"], linear_test["chisq"], nonlinear_test["chisq"]),
  df    = c(omnibus_check["df"], linear_test["df"], nonlinear_test["df"]),
  p     = fmt_p(c(omnibus_check["p"], linear_test["p"], nonlinear_test["p"]))
)

# Linear p = 0.0130; Non-linear p = 0.0506
decomposition_results


# Plot spline curves ------------------------------------------------------

# Extract egg spline main effect terms
egg_main_terms <- names(qbar_full)[
  str_detect(names(qbar_full), fixed("eggs_gram_ea")) &
  !str_detect(names(qbar_full), fixed("meat_gram_ea100"))
]

# Extract egg spline x meat interactions terms
egg_meat_intx_terms <- names(qbar_full)[
  str_detect(names(qbar_full), fixed("eggs_gram_ea")) &
  str_detect(names(qbar_full), fixed("meat_gram_ea100"))
]

# Order both by spline order (0 primes = linear, 1/2 primes = nonlinear)
# so egg_main_terms[j] and egg_meat_intx_terms[j] refer to the SAME basis
# column -- this works regardless of exact naming/prefix conventions
egg_main_terms       <- egg_main_terms[order(str_count(egg_main_terms, "'"))]
egg_meat_intx_terms  <- egg_meat_intx_terms[order(str_count(egg_meat_intx_terms, "'"))]

# Check
egg_main_terms
egg_meat_intx_terms

# Set the reference for egg (eggs_gram_ea = 0; no egg intake)
ref_val <- 0

# Set up a grid for the x-axis
grid_x <- seq(0, quantile(stacked_data$eggs_gram_ea, 0.99, na.rm = TRUE), length.out = 200)

# Function to calculate egg HRs
egg_dose_response_at_meat <- function(meat_gramday, grid_x = grid_x, ref = ref_val) {
  meat_val <- meat_gramday / 100   # convert g/day -> model scale (meat_gram_ea100)

  basis_grid <- rcspline.eval(grid_x, knots = egg_knots, inclx = TRUE, norm = 2)
  basis_ref  <- rcspline.eval(ref,    knots = egg_knots, inclx = TRUE, norm = 2)
  diff_basis <- sweep(basis_grid, 2, basis_ref, FUN = "-")   # n x 3

  # Combined coefficient at this meat level: main effect + meat_val * interaction
  combined_beta <- qbar_full[egg_main_terms] + meat_val * qbar_full[egg_meat_intx_terms]
  log_hr <- as.numeric(diff_basis %*% combined_beta)

  # Full covariance across BOTH main and interaction terms
  L <- cbind(diff_basis, meat_val * diff_basis)              # n x 6
  full_terms <- c(egg_main_terms, egg_meat_intx_terms)
  Vsub <- V_full[full_terms, full_terms]

  AV <- L %*% Vsub
  var_vec <- rowSums(AV * L)
  se_vec  <- sqrt(var_vec)

  tibble(
    eggs_gram_ea = grid_x,
    meat_gramday = meat_gramday,
    HR    = exp(log_hr),
    lower = exp(log_hr - qnorm(0.975) * se_vec),
    upper = exp(log_hr + qnorm(0.975) * se_vec)
  )
}


stacked_data %>% 
  select(meat_gram_ea) %>% 
  ggplot(aes(x = meat_gram_ea)) +
  geom_histogram() +
  scale_x_continuous(transform = 'log10')

# Meat intake g/d at which egg HRs are calculated
meat_values_gramday <- c(0, 10, 30, 50)

egg_dose_response_by_meat <- map_dfr(
  meat_values_gramday,
  ~ egg_dose_response_at_meat(.x, grid_x = grid_x, ref = ref_val)
) %>%
  mutate(
    meat_label = factor(paste0("Meat: ", meat_gramday, " g/day"),
                         levels = paste0("Meat: ", meat_values_gramday, " g/day"))
  )

# Generate plots at each meat intake -- use ggplot
p_egg_by_meat <- ggplot(egg_dose_response_by_meat, aes(x = eggs_gram_ea, y = HR)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey50") +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.15) +
  geom_line(linewidth = 1) +
  # geom_vline(xintercept = ref_val, linetype = "dotted", color = "grey40") +
  # scale_y_log10() +
  scale_y_continuous(breaks = c(6:10 / 10), transform = "log10") +
  facet_wrap(~ meat_label, nrow = 1) +
  labs(
    x = "Energy-adjusted egg intake (g/day)",
    y = "Hazard ratio (log scale)",
    title = "Egg intake dose-response by meat intake level",
    subtitle = sprintf("Restricted cubic spline, 4 knots | Reference: %.0f g/day egg intake at the same meat level", ref_val)
  ) +
  theme_minimal(base_size = 13) +
  theme(
    strip.background = element_rect(fill = "grey85", color = "grey50"),
    strip.text        = element_text(face = "bold"),
    plot.subtitle     = element_text(size = 10, color = "grey30")
  )

p_egg_by_meat

pdf("./Results/egg_gram_rcs_dose_response_by_meat.pdf", width = 12, height = 4)
print(p_egg_by_meat)
dev.off()

ggsave("./Results/egg_gram_rcs_dose_response_by_meat.png", p_egg_by_meat,
       width = 12, height = 4, dpi = 300)
