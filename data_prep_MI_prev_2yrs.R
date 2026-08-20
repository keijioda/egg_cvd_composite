
# Required libraries
pacs <- c("tidyverse", "readxl", "lubridate")
sapply(pacs, require, character.only = TRUE)


# ==========================================================================
# SECTION A: Steps that do NOT depend on which imputation is used.
# Run these ONCE, exactly as in the original script.
# ==========================================================================

# Medicare crosswalk ------------------------------------------------------

crosswalk <- read_fwf(
  "./Data/12172/2022/ssn_bene_xwalk_res000058038_req012172_2022.dat",
  fwf_widths(
    c(9, 15, 1, 1, 1),
    c("ORIG_SSN", "BENE_ID", "SSN_MATCH", "SEX_MATCH", "DOB_MATCH")
  )
)

all_matched_bene_ids <- crosswalk %>%
  filter(SSN_MATCH == 1)

mismatches <- crosswalk %>%
  filter(SSN_MATCH == 1 & (SEX_MATCH == 0 | DOB_MATCH == 0)) %>%
  select(BENE_ID)

dup_BENE_IDs <- all_matched_bene_ids %>%
  group_by(BENE_ID) %>%
  summarize(n = sum(n())) %>%
  filter(n > 1)

dup_SSNs <- all_matched_bene_ids %>%
  group_by(ORIG_SSN) %>%
  summarize(n = sum(n())) %>%
  filter(n > 1)

exclude_BENE_IDs <- dup_BENE_IDs %>%
  select(BENE_ID) %>%
  union(all_matched_bene_ids %>%
          filter(ORIG_SSN %in% dup_SSNs$ORIG_SSN) %>%
          select(BENE_ID)
  ) %>%
  union(mismatches)

# Medicare MSBF file ------------------------------------------------------

fts_msbf <- read_excel("./Data/mbsf_format.xlsx")

year <- 2008:2020
fname <- paste0("./Data/12172/", year, "/mbsf_abcd_summary_res000058038_req012172_", year, ".dat")

all_msbf <- fname %>%
  lapply(\(x) read_fwf(x, fwf_widths(fts_msbf$length, fts_msbf$long_name))) %>%
  lapply(\(x) anti_join(x, exclude_BENE_IDs)) %>%
  setNames(year)

year <- 2021:2022
fname <- paste0("./Data/14345/", year, "/mbsf_abcd_summary_res000058038_req014345_", year, ".dat")

add_msbf <- fname %>%
  lapply(\(x) read_fwf(x, fwf_widths(fts_msbf$length, fts_msbf$long_name))) %>%
  lapply(\(x) anti_join(x, exclude_BENE_IDs)) %>%
  setNames(year)

all_msbf2 <- c(all_msbf, add_msbf)

all_msbf_long <- all_msbf2 %>%
  do.call(rbind, .) %>%
  arrange(BENE_ID, BENE_ENROLLMT_REF_YR)

# Medicare chronic condition file -----------------------------------------

fts_cc <- read_excel("./Data/mbsf_cc_format.xlsx")

year <- 2008:2020
fname <- paste0("./Data/12172/", year, "/mbsf_cc_summary_res000058038_req012172_", year, ".dat")

all_cc <- fname %>%
  lapply(\(x) read_fwf(x, fwf_widths(fts_cc$length, fts_cc$long_name))) %>%
  lapply(\(x) anti_join(x, exclude_BENE_IDs)) %>%
  setNames(year)

fts_chronic <- read_excel("./Data/mbsf_chronic_format.xlsx")

year <- 2021:2022
fname <- paste0("./Data/14345/", year, "/mbsf_chronic_summary_res000058038_req014345_", year, ".dat")

add_cc <- fname %>%
  lapply(\(x) read_fwf(x, fwf_widths(fts_chronic$length, fts_chronic$long_name))) %>%
  lapply(\(x) anti_join(x, exclude_BENE_IDs)) %>%
  lapply(\(x) rename(x, HYPERL_EVER = HLP_EVER, CHF_EVER = HF_EVER, HYPERT_EVER = HTN_EVER, HYPOTH_EVER = HYPTHYRD_EVER)) %>%
  setNames(year)

all_cc2 <- c(all_cc, add_cc)

all_cc_long <- all_cc2 %>%
  do.call(bind_rows, .) %>%
  arrange(BENE_ID, BENE_ENROLLMT_REF_YR)

# Last-seen MSBF/CC records (fixed, not imputation-dependent) ------------

msbf_last_seen <- all_msbf_long %>%
  group_by(BENE_ID) %>%
  slice(n())

cc_last_seen <- all_cc_long %>%
  group_by(BENE_ID) %>%
  slice(n())

# AHS-2 Medicare link file ------------------------------------------------

ahs <- read_csv("./Data/MedicareMatches2022.csv")

exclude_analysisIDs <- ahs %>%
  group_by(AnalysisID) %>%
  tally() %>%
  filter(n > 1) %>%
  select(AnalysisID)

ahs_dup_removed <- ahs %>% anti_join(exclude_analysisIDs)

# AHS-2 baseline data (used only for qreturndate; not imputed) -----------

ahsdata <- read.csv("./Data/BaselineDataForMedicare20190531.csv", header = TRUE)
names(ahsdata) <- tolower(names(ahsdata))

# The 5 imputed datasets ---------------------------------------------------

imputed_file_names <- dir("./Data", full.names = TRUE) %>% grep("07-09.csv", ., value = TRUE)

imputed_data <- imputed_file_names %>%
  lapply(read_csv) %>%
  lapply(select, -1)

# Energy-adjustment helper (unchanged) -------------------------------------

kcal_adjust <- function(data, var, energy, log = TRUE) {
  if (missing(var))
    stop("Need to specify variable for energy-adjustment.")
  if (missing(energy))
    stop("Need to specify energy intake.")
  if (missing(data))
    stop("Need to specify a data frame.")
  df <- data.frame(y = data[[var]], ea_y = data[[var]], kcal = data[[energy]])
  count_negative <- sum(df$y < 0, na.rm = TRUE)
  if (count_negative > 0)
    warning("There are negative values in variable.")
  if (log) df$y[df$y > 0 & !is.na(df$y)] <- log(df$y[df$y > 0 & !is.na(df$y)])
  mod <- lm(y ~ kcal, data = df[df$y != 0, ])
  if (log) {
    ea <- exp(resid(mod) + mean(df$y[df$y != 0], na.rm = TRUE))
    df$ea_y[!is.na(df$y) & df$y != 0] <- ea
  } else {
    ea <- resid(mod) + mean(df$y[df$y != 0], na.rm = TRUE)
    df$ea_y[!is.na(df$y) & df$y != 0] <- ea
  }
  return(df$ea_y)
}

food_vars <- c(
  "meat", "fish", "eggs", "alldairy2", "nutsseeds",
  "totalveg", "fruits", "legumes", "refgrains", "whole_mixed_grains"
)

food_levels <- list(
  meat_gram_ea_4               = c("None", "<11 g/d", "11-<33 g/d", "33+ g/d"),
  fish_gram_ea_4               = c("None", "<9 g/d", "9-<18 g/d", "18+ g/d"),
  eggs_gram_ea_4               = c("None", "<4.5 g/d", "4.5-<16.5 g/d", "16.5+ g/d"),
  eggs_gram_ea_5               = c("None", "<4 g/d", "4-<10 g/d", "10-<23 g/d", "23+ g/d"),
  alldairy2_gram_ea_4          = c("None", "<50 g/d", "50-<180 g/d", "180+ g/d"),
  totalveg_gram_ea_4           = c("<185 g/d", "185-<270 g/d", "270-<380 g/d", "380+ g/d"),
  fruits_gram_ea_4             = c("<170 g/d", "170-<280 g/d", "280-<420 g/d", "420+ g/d"),
  refgrains_gram_ea_4          = c("<40 g/d", "40-<83 g/d", "83-<150 g/d", "150+ g/d"),
  whole_mixed_grains_gram_ea_4 = c("<120 g/d", "120-<210 g/d", "219-<350 g/d", "350+ g/d"),
  nutsseeds_gram_ea_4          = c("<9 g/d", "9-<18 g/d", "18-<32 g/d", "32+ g/d"),
  legumes_gram_ea_4            = c("<33 g/d", "33-<60 g/d", "60-<100 g/d", "100+ g/d")
)

dzvars <- c(
  "cataract", "chronickidney", "copd", "diabetes", "glaucoma",
  "hip_fracture", "depression", "osteoporosis", "ra_oa",
  "cancer_breast", "cancer_colorectal", "cancer_prostate", "cancer_lung",
  "cancer_endometrial", "asthma", "hyperl", "hypert", "hypoth", "anemia"
) %>%
  toupper() %>%
  paste0("_EVER")

cvd_vars <- c("ISCHEMICHEART_EVER", "STROKE_TIA_EVER", "AMI_EVER", "CHF_EVER", "ATRIAL_FIB_EVER")


# ==========================================================================
# SECTION B: Everything that DOES depend on which imputed dataset is used.
# Wrapped in a function so it can be applied identically to each of the 5.
# ==========================================================================

build_analytic_dataset <- function(imp_df) {

  ahsdata2 <- imp_df %>%
    rename(agein = calc_baseline_age) %>%
    inner_join(ahsdata %>% select(analysisid, qreturndate), by = "analysisid") %>%
    mutate(
      qreturndate = as.Date(qreturndate),
      bmicat    = cut(bmi, breaks = c(0, 25, 30, Inf), right = FALSE),
      bmicat    = factor(bmicat, labels = c("Normal", "Overweight", "Obese")),
      marital   = recode(marital, "Never", "Married", "Married", "Married", "Div/Wid", "Div/Wid", "Div/Wid"),
      marital   = factor(marital, levels = c("Married", "Never", "Div/Wid")),
      educyou   = factor(educat3, labels = c("Bachelors +", "HSch & below", "Some College")),
      educyou   = fct_relevel(educyou, "HSch & below", "Some College", "Bachelors +"),
      educyou2  = relevel(educyou, ref = "Bachelors +"),
      sleephrs  = recode(sleephrs, "<= 5 hrs", "<= 5 hrs", "<= 5 hrs", "6 hrs", "7 hrs",
                          "8 hrs", ">= 9 hrs", ">= 9 hrs", ">= 9 hrs"),
      sleephrs  = factor(sleephrs, levels = c("<= 5 hrs", "6 hrs", "7 hrs", "8 hrs", ">= 9 hrs")),
      sleephrs2 = relevel(sleephrs, ref = "7 hrs"),
      vegstat   = 1 * vegan + 2 * lacto + 3 * semi + 4 * pesco + 5 * nonveg,
      vegstat   = factor(vegstat, labels = c("Vegan", "Lacto-ovo", "Semi", "Pesco", "Non-veg")),
      vegstat2  = relevel(vegstat, ref = "Non-veg"),
      exercise  = cut(exermin_week, breaks = c(-Inf, 0, 30, 120, Inf), right = TRUE),
      exercise  = factor(exercise, labels = c("None", "\u22640.5 hrs/wk", "0.5<-2 hrs/wk", ">2 hrs/wk")),
      smokecat6 = factor(smokecat6),
      alccat    = ifelse(winegd == 0 & beergd == 0 & liquorgd == 0, "Never", "Current"),
      alccat    = factor(alccat, levels = c("Never", "Current")),
      egg_freq  = recode(eggbetrf, 1, 2, 3, 4, 5, 5, 5, 5, 5),
      egg_freq4 = recode(eggbetrf, 1, 2, 3, 3, 4, 4, 4, 4, 4),
      egg_freq  = factor(egg_freq, labels = c("Never", "1-3/mo", "1/wk", "2-4/wk", "5+/wk")),
      egg_freq4 = factor(egg_freq4, labels = c("Never", "1-3/mo", "1-4/wk", "5+/wk")),
      kcal      = kcaldiet + kcalsupp,
      meat_gramdiet = procredmeat_gramdiet + unprocredmeat_gramdiet + procpoultry_gramdiet + unprocpoultry_gramdiet,
      grains_gramdiet = wholegrains_gramdiet + mixedgrains_gramdiet + refgrains_gramdiet,
      whole_mixed_grains_gramdiet = wholegrains_gramdiet + mixedgrains_gramdiet
    )

  # Merge AHS data with Medicare (fixed pieces from Section A) -------------

  ahs_medic <- msbf_last_seen %>%
    inner_join(
      cc_last_seen %>% select(-BENE_ENROLLMT_REF_YR),
      by = "BENE_ID"
    ) %>%
    inner_join(
      ahs_dup_removed %>%
        rename(BENE_ID = Bene_ID) %>%
        mutate(analysisid = parse_number(AnalysisID)),
      by = "BENE_ID"
    ) %>%
    inner_join(ahsdata2, by = "analysisid") %>%
    ungroup()

  # Inclusion/exclusion criteria --------------------------------------------
  # NOTE: bmi comes from the imputed dataset, so this filter can, in
  # principle, keep/drop different subjects across the 5 imputations.
  # We reconcile that below in Section C.

  ahs_medic <- ahs_medic %>% filter(AGE_AT_END_REF_YR >= 65)
  ahs_medic <- ahs_medic %>% filter(bmi >= 16, bmi <= 60)

  unverified_deaths <- ahs_medic %>%
    filter(!is.na(BENE_DEATH_DT)) %>%
    filter(is.na(VALID_DEATH_DT_SW)) %>%
    select(analysisid)

  ahs_medic <- ahs_medic %>%
    anti_join(unverified_deaths, by = "analysisid")

  # Hyperlipidemia ----------------------------------------------------------

  ahs_medic <- ahs_medic %>%
    mutate(HYPERL_YN = ifelse(is.na(HYPERL_EVER), 0, 1),
           HYPERL_YN = factor(HYPERL_YN, label = c("No", "Yes")),
           BENE_BIRTH_DT = ymd(BENE_BIRTH_DT),
           BENE_DEATH_DT = ymd(BENE_DEATH_DT),
           HYPERL_EVER = ymd(HYPERL_EVER))

  # CVD case definition -------------------------------------------------------

  ahs_medic2 <- ahs_medic %>%
    mutate(CVD_EVER = pmin(ISCHEMICHEART_EVER, STROKE_TIA_EVER, AMI_EVER, CHF_EVER, ATRIAL_FIB_EVER, na.rm = TRUE),
           CVD_EVER = ymd(CVD_EVER),
           CVD_YN = ifelse(is.na(CVD_EVER), 0, 1),
           CVD_YN = factor(CVD_YN, labels = c("No", "Yes")))

  cvd_diag_date <- ahs_medic2 %>%
    filter(CVD_YN == "Yes") %>%
    mutate(DateDiff = interval(qreturndate, CVD_EVER),
           DateDiff_days = as.numeric(DateDiff, 'days'))

  # Prevalent cases: Diagnosed before enrollment or within 2 years after enrollment
  prev_cvd <- cvd_diag_date %>%
    filter(DateDiff_days <= 365 * 2) %>%
    select(analysisid)

  ahs_medic2 <- ahs_medic2 %>%
    anti_join(prev_cvd, by = "analysisid")

  # Model variables -----------------------------------------------------------

  ahs_medic_inc <- ahs_medic2 %>%
    mutate(
      age_last_seen = time_length(interval(BENE_BIRTH_DT, make_date(BENE_ENROLLMT_REF_YR, 12, 31)), "year"),
      ageout = case_when(
        CVD_YN == "Yes" ~ time_length(interval(BENE_BIRTH_DT, CVD_EVER), "year"),
        CVD_YN == "No" & !is.na(BENE_DEATH_DT) ~ time_length(interval(BENE_BIRTH_DT, BENE_DEATH_DT), "year"),
        CVD_YN == "No" & is.na(BENE_DEATH_DT) ~ age_last_seen
      ),
      hyperl_age = case_when(
        HYPERL_YN == "Yes" ~ time_length(interval(BENE_BIRTH_DT, HYPERL_EVER), "year"),
        .default = NA
      ),
      hyperl_age = if_else(hyperl_age > ageout, NA, hyperl_age),
      fuyear     = ageout - agein,
      bene_sex_F = factor(SEX_IDENT_CD, labels = c("M", "F")),
      bene_age_at_end_2022 = time_length(interval(BENE_BIRTH_DT, make_date(2022, 12, 31)), "year"),
      agecat     = cut(bene_age_at_end_2022, breaks = c(65, 70, 75, 80, 85, 90, 95, 130), right = FALSE),
      agecat     = factor(agecat, labels = c("65-69", "70-74", "75-79", "80-84", "85-89", "90-94", "95+")),
      rti_race3  = recode(RTI_RACE_CD + 1, 3, 1, 2, 3, 3, 3, 3),
      rti_race3  = factor(rti_race3, labels = c("NH White", "Black", "Other"))
    ) %>% 
    filter(ageout > agein + 2)     # Exclude those who died/censored before reaching the landmark

  # Co-morbidity ----------------------------------------------------------------

  ahs_medic_inc2 <- ahs_medic_inc %>%
    mutate(across(all_of(dzvars), ~ as.integer(ymd(.) <= qreturndate & !is.na(.)))) %>%
    mutate(
      como_depress  = DEPRESSION_EVER,
      como_diabetes = DIABETES_EVER,
      como_kidney   = CHRONICKIDNEY_EVER,
      como_hypoth   = HYPOTH_EVER,
      como_anemia   = ANEMIA_EVER,
      como_hypert   = HYPERT_EVER,
      como_hyperl   = HYPERL_EVER,
      como_cancers  = pmax(CANCER_BREAST_EVER, CANCER_COLORECTAL_EVER, CANCER_PROSTATE_EVER,
                            CANCER_LUNG_EVER, CANCER_ENDOMETRIAL_EVER),
      como_disab    = pmax(CATARACT_EVER, GLAUCOMA_EVER, HIP_FRACTURE_EVER, OSTEOPOROSIS_EVER, RA_OA_EVER),
      como_hthl     = pmax(HYPERT_EVER, HYPERL_EVER),
      como_resp     = pmax(COPD_EVER, ASTHMA_EVER),
      across(starts_with("como_"), ~ factor(., labels = c("No", "Yes")))
    )

  # Dietary variables -------------------------------------------------------------
  # NOTE: kcal_adjust() fits a fresh lm() on THIS imputation's data each time,
  # which is the correct behavior -- energy adjustment should reflect each
  # imputed dataset's own diet/kcal relationship.

  ea_results <- lapply(food_vars, function(v) {
    kcal_adjust(data = ahs_medic_inc2, var = paste0(v, "_gramdiet"), energy = "kcal", log = TRUE)
  })
  names(ea_results) <- paste0(food_vars, "_gram_ea")
  ahs_medic_inc2[names(ea_results)] <- ea_results

  ahs_medic_inc2 <- ahs_medic_inc2 %>%
    mutate(
      meat_gram_ea_4      = cut(meat_gram_ea,      breaks = c(-Inf, 0, 11, 33, Inf),   right = TRUE),
      fish_gram_ea_4      = cut(fish_gram_ea,      breaks = c(-Inf, 0,  9, 18, Inf),   right = TRUE),
      alldairy2_gram_ea_4 = cut(alldairy2_gram_ea, breaks = c(-Inf, 0,  50, 180, Inf), right = TRUE),
      totalveg_gram_ea_4  = cut(totalveg_gram_ea,  breaks = c(-Inf, 185, 270, 380, Inf), right = TRUE),
      fruits_gram_ea_4    = cut(fruits_gram_ea,    breaks = c(-Inf, 170, 280, 420, Inf), right = TRUE),
      nutsseeds_gram_ea_4 = cut(nutsseeds_gram_ea, breaks = c(-Inf, 9, 18, 32, Inf),   right = TRUE),
      legumes_gram_ea_4   = cut(legumes_gram_ea,   breaks = c(-Inf, 33, 60, 100, Inf), right = TRUE),
      refgrains_gram_ea_4 = cut(refgrains_gram_ea, breaks = c(-Inf, 40, 83, 150, Inf), right = TRUE),
      whole_mixed_grains_gram_ea_4 = cut(whole_mixed_grains_gram_ea, breaks = c(-Inf, 120, 210, 350, Inf), right = TRUE),
      eggs_gram_ea_4      = cut(eggs_gram_ea,      breaks = c(-Inf, 0, 4.5, 16.5, Inf), right = TRUE),
      eggs_gram_ea_5      = cut(eggs_gram_ea,      breaks = c(-Inf, 0, 4, 10, 23, Inf), right = TRUE)
    )

  for (var in names(food_levels)) {
    levels(ahs_medic_inc2[[var]]) <- food_levels[[var]]
  }

  # Cox model variables -----------------------------------------------------------

  ahs_medic_inc2 <- ahs_medic_inc2 %>%
    mutate(bene_sex_F = relevel(bene_sex_F, ref = "F"),
           bmicat     = relevel(bmicat, ref = "Normal"),
           inc_CVD    = ifelse(CVD_YN == "Yes", 1, 0),
           kcal100    = kcal / 100,
           meat_gram_ea100      = meat_gram_ea / 100,
           fish_gram_ea100      = fish_gram_ea / 100,
           alldairy2_gram_ea100 = alldairy2_gram_ea / 100,
           totalveg_gram_ea100  = totalveg_gram_ea / 100,
           fruits_gram_ea100    = fruits_gram_ea / 100,
           refgrains_gram_ea100 = refgrains_gram_ea / 100,
           whole_mixed_grains_gram_ea100 = whole_mixed_grains_gram_ea / 100,
           nutsseeds_gram_ea100 = nutsseeds_gram_ea / 100,
           legumes_gram_ea100   = legumes_gram_ea / 100)

  return(ahs_medic_inc2)
}


# ==========================================================================
# SECTION C: Apply to all 5 imputations, keep each imputation's OWN sample
# (no reconciliation to a common subject set / no mids object), fit the Cox
# model separately within each, and wrap the 5 fits into a `mira` object
# for manual pooling.
# ==========================================================================

processed_list <- lapply(imputed_data, build_analytic_dataset)

# N per imputation -- kept as-is; not forced to match across imputations
sapply(processed_list, nrow)

saveRDS(processed_list, "./Data/imputed_data_list_prev_2yrs.rds")
