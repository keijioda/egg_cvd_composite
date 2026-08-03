Egg composite CVD study
================

## Aim

- Examine associations between egg and meat intake and incident
  cardiovascular disease (CVD)
- Examine whether egg intake modifies the association between meat
  intake and CVD
  - i.e., whether egg and meat intake interact in their effect on CVD
    incidence

## Outcome

- Any of the following incident CVD cases:
  - Ischemic heart disease
  - Stroke/transient ischemic attack
  - Acute myocardial infarction
  - Congestive heart failure (in 27 chronic conditions) or heart failure
    and non-ischemic heart disease (in 30 chronic conditions)
  - Atrial fibrillation
- For disease definition, see [Chronic Conditions Data
  Warehouse](https://www2.ccwdata.org/web/guest/condition-categories-chronic)
  - Note that the definitions may differ between 27 chronic conditions
    (available in 2008-2020 data) and 30 chronic conditions (2021-2022)

## Exposure of interest

- Dietary intake, measured via the AHS baseline questionnaire

- Egg intake frequency

  - Categorized into four groups based on frequency of intake

- Meat intake, gram/day

  - Energy-adjusted

- Multiplicative interaction terms between egg intake category and meat
  intake (g/d) will be assessed in Cox proportional hazards models

## Datasets

- Medicare data

  - For details regarding Medicare data, see [AHS-2 Medicare
    Linkage](https://github.com/keijioda/ahs_medicare_linkage/blob/main/summary.md)
    repository.

  - Master Beneficiary Summary File (MBSF), 2008-2022

    - Contains beneficiary characteristics and enrollment information

  - Chronic Conditions file (CC), 2008-2022

    - Contains the first occurrence date of [27 (or 30) specific chronic
      conditions](https://www2.ccwdata.org/web/guest/condition-categories-chronic)
    - Used to identify prevalent/incident cases of CVD and
    - to identify comorbidities, based on ICD-9 and ICD-10 codes

  - Both files include n = 46,897 unique subjects across years, after
    excluding

    - Gender/DOB mismatch with AHS-2 data
    - Dupulicate beneficiary IDs and SSNs

- AHS-2 baseline data: n = 96,144

- After merging Medicare and AHS-2 data, there were n = 43,467 subjects

  - Participants who opted out from the study or those who live outside
    the U.S were already excluded at this point

## Inclusion/exclusion criteria

- Medicare beneficiaries who did not reach the age of 65 between 2008
  and 2022 (e.g., younger beneficiaries with disabilities or end-stage
  renal disease) were excluded (n = 1238), resulting n = 42,229.

- n = 106 subjects with extreme BMI (\<16 or \>60), according to AHS
  questionnaire, were excluded, resulting n = 42,123.

- Unverified dates of deaths

  - Medicare data include a variable (`VALID_DEATH_DT_SW`) indicating
    whether a beneficiary’s day of death has been verified by the Social
    Security Administration or the Railroad Retirement Board.
  - There were 23 unverified death dates. Excluding these resulted in n
    = 42,100.

- Prevalent CVD cases

  - At this point of analysis, prevalent cases were defined as those who
    were diagnosed with any of the five CVD conditions prior to their
    AHS-2 enrollment
  - There were 3,542 such prevalent cases. Excluding these prevalence
    resulted in n = 38,558

## Incident CVD cases

- Among n = 38,558 subjects, there were 12,890 incident CVD cases
  (33.4%)
  - Among these cases, there were 223 incident cases within 6 months
    after AHS-2 enrollment
  - Similarly, numbers of incident cases within 12, 18, 24 36, and 48
    months are shown below:

| Months after enrollment | N incident CVD cases |
|------------------------:|---------------------:|
|                       6 |                  223 |
|                      12 |                  469 |
|                      18 |                  701 |
|                      24 |                  970 |
|                      36 |                 1415 |
|                      48 |                 1823 |

- For each of the five CVD conditions, the number of incident cases is
  shown below:

|                              | Overall     |
|:-----------------------------|:------------|
| n                            | 38558       |
| ISCHEMICHEART_EVER = Yes (%) | 7767 (20.1) |
| STROKE_TIA_EVER = Yes (%)    | 5101 (13.2) |
| AMI_EVER = Yes (%)           | 1297 ( 3.4) |
| CHF_EVER = Yes (%)           | 6075 (15.8) |
| ATRIAL_FIB_EVER = Yes (%)    | 5404 (14.0) |

- Many of these CVD cases have more than one of the 5 conditions. See
  below for the frequency table of CVD conditions:

| Number of CVD conditions |     n | Percent |
|-------------------------:|------:|--------:|
|                        0 | 25668 |   66.57 |
|                        1 |  5499 |   14.26 |
|                        2 |  3556 |    9.22 |
|                        3 |  2497 |    6.48 |
|                        4 |  1148 |    2.98 |
|                        5 |   190 |    0.49 |

## Descriptive tables

### Person-years of follow-up

| Statistic               |     Value |
|:------------------------|----------:|
| Total person-years      | 612479.78 |
| Follow-up years: Mean   |     15.88 |
| Follow-up years: Median |     17.90 |
| Follow-up years: SD     |      4.96 |

### Age at diagnosis of incident CVD cases

| Statistic                | Value |
|:-------------------------|:------|
| N                        | 12890 |
| Age at diagnosis: Mean   | 78.45 |
| Age at diagnosis: Median | 78.51 |
| Age at diagnosis: SD     | 8.32  |

### By cases/non-cases

|  | level | Overall | Non-case | Case | p | test |
|:---|:---|:---|:---|:---|:---|:---|
| n |  | 38558 | 25668 | 12890 |  |  |
| agecat (%) | 65-69 | 6175 (16.0) | 5648 (22.0) | 527 ( 4.1) | \<0.001 |  |
|  | 70-74 | 6982 (18.1) | 5651 (22.0) | 1331 (10.3) |  |  |
|  | 75-79 | 6638 (17.2) | 4774 (18.6) | 1864 (14.5) |  |  |
|  | 80-84 | 5862 (15.2) | 3648 (14.2) | 2214 (17.2) |  |  |
|  | 85-89 | 4856 (12.6) | 2579 (10.0) | 2277 (17.7) |  |  |
|  | 90-94 | 3842 (10.0) | 1796 ( 7.0) | 2046 (15.9) |  |  |
|  | 95+ | 4203 (10.9) | 1572 ( 6.1) | 2631 (20.4) |  |  |
| bene_age_at_end_2022 (mean (SD)) |  | 80.92 (10.23) | 78.27 (9.41) | 86.21 (9.74) | \<0.001 |  |
| bene_sex_F (%) | F | 24873 (64.5) | 17029 (66.3) | 7844 (60.9) | \<0.001 |  |
|  | M | 13685 (35.5) | 8639 (33.7) | 5046 (39.1) |  |  |
| rti_race3 (%) | NH White | 28063 (72.8) | 17739 (69.1) | 10324 (80.1) | \<0.001 |  |
|  | Black | 7706 (20.0) | 5755 (22.4) | 1951 (15.1) |  |  |
|  | Other | 2789 ( 7.2) | 2174 ( 8.5) | 615 ( 4.8) |  |  |
| marital (%) | Married | 28648 (74.3) | 19352 (75.4) | 9296 (72.1) | \<0.001 |  |
|  | Never | 1421 ( 3.7) | 1006 ( 3.9) | 415 ( 3.2) |  |  |
|  | Div/Wid | 8489 (22.0) | 5310 (20.7) | 3179 (24.7) |  |  |
| educyou (%) | HSch & below | 7704 (20.0) | 4737 (18.5) | 2967 (23.0) | \<0.001 |  |
|  | Some College | 15412 (40.0) | 10390 (40.5) | 5022 (39.0) |  |  |
|  | Bachelors + | 15442 (40.0) | 10541 (41.1) | 4901 (38.0) |  |  |
| vegstat (%) | Vegan | 3226 ( 8.4) | 2197 ( 8.6) | 1029 ( 8.0) | \<0.001 |  |
|  | Lacto-ovo | 12259 (31.8) | 8046 (31.3) | 4213 (32.7) |  |  |
|  | Semi | 2132 ( 5.5) | 1346 ( 5.2) | 786 ( 6.1) |  |  |
|  | Pesco | 3681 ( 9.5) | 2509 ( 9.8) | 1172 ( 9.1) |  |  |
|  | Non-veg | 17260 (44.8) | 11570 (45.1) | 5690 (44.1) |  |  |
| bmicat (%) | Normal | 14905 (38.7) | 10351 (40.3) | 4554 (35.3) | \<0.001 |  |
|  | Overweight | 13855 (35.9) | 9169 (35.7) | 4686 (36.4) |  |  |
|  | Obese | 9798 (25.4) | 6148 (24.0) | 3650 (28.3) |  |  |
| bmi (mean (SD)) |  | 27.32 (5.72) | 27.07 (5.58) | 27.82 (5.96) | \<0.001 |  |
| exercise (%) | None | 7848 (20.4) | 4650 (18.1) | 3198 (24.8) | \<0.001 |  |
|  | ≤0.5 hrs/wk | 9546 (24.8) | 6556 (25.5) | 2990 (23.2) |  |  |
|  | 0.5\<-2 hrs/wk | 10459 (27.1) | 7191 (28.0) | 3268 (25.4) |  |  |
|  | \>2 hrs/wk | 10705 (27.8) | 7271 (28.3) | 3434 (26.6) |  |  |
| sleephrs (%) | \<= 5 hrs | 3762 ( 9.8) | 2489 ( 9.7) | 1273 ( 9.9) | \<0.001 |  |
|  | 6 hrs | 8474 (22.0) | 5755 (22.4) | 2719 (21.1) |  |  |
|  | 7 hrs | 14196 (36.8) | 9761 (38.0) | 4435 (34.4) |  |  |
|  | 8 hrs | 10107 (26.2) | 6448 (25.1) | 3659 (28.4) |  |  |
|  | \>= 9 hrs | 2019 ( 5.2) | 1215 ( 4.7) | 804 ( 6.2) |  |  |
| smokecat6 (%) | A_Never | 30781 (79.8) | 20650 (80.5) | 10131 (78.6) | \<0.001 |  |
|  | B_QuitYrs30Plus | 2965 ( 7.7) | 1717 ( 6.7) | 1248 ( 9.7) |  |  |
|  | C_QuitYrs21To30 | 2084 ( 5.4) | 1433 ( 5.6) | 651 ( 5.1) |  |  |
|  | D_QuitYrs11To20 | 1387 ( 3.6) | 942 ( 3.7) | 445 ( 3.5) |  |  |
|  | E_QuitYrs6To10 | 520 ( 1.3) | 358 ( 1.4) | 162 ( 1.3) |  |  |
|  | F_QuitYrsLesOneTo5YearsNcur | 821 ( 2.1) | 568 ( 2.2) | 253 ( 2.0) |  |  |
| alccat (%) | Never | 36543 (94.8) | 24205 (94.3) | 12338 (95.7) | \<0.001 |  |
|  | Current | 2015 ( 5.2) | 1463 ( 5.7) | 552 ( 4.3) |  |  |
| como_depress (%) | No | 38215 (99.1) | 25579 (99.7) | 12636 (98.0) | \<0.001 |  |
|  | Yes | 343 ( 0.9) | 89 ( 0.3) | 254 ( 2.0) |  |  |
| como_disab (%) | No | 35429 (91.9) | 24881 (96.9) | 10548 (81.8) | \<0.001 |  |
|  | Yes | 3129 ( 8.1) | 787 ( 3.1) | 2342 (18.2) |  |  |
| como_diabetes (%) | No | 37953 (98.4) | 25539 (99.5) | 12414 (96.3) | \<0.001 |  |
|  | Yes | 605 ( 1.6) | 129 ( 0.5) | 476 ( 3.7) |  |  |
| como_hypert (%) | No | 36711 (95.2) | 25273 (98.5) | 11438 (88.7) | \<0.001 |  |
|  | Yes | 1847 ( 4.8) | 395 ( 1.5) | 1452 (11.3) |  |  |
| como_hyperl (%) | No | 37102 (96.2) | 25323 (98.7) | 11779 (91.4) | \<0.001 |  |
|  | Yes | 1456 ( 3.8) | 345 ( 1.3) | 1111 ( 8.6) |  |  |
| como_resp (%) | No | 38172 (99.0) | 25580 (99.7) | 12592 (97.7) | \<0.001 |  |
|  | Yes | 386 ( 1.0) | 88 ( 0.3) | 298 ( 2.3) |  |  |
| como_anemia (%) | No | 37574 (97.4) | 25453 (99.2) | 12121 (94.0) | \<0.001 |  |
|  | Yes | 984 ( 2.6) | 215 ( 0.8) | 769 ( 6.0) |  |  |
| como_kidney (%) | No | 38448 (99.7) | 25645 (99.9) | 12803 (99.3) | \<0.001 |  |
|  | Yes | 110 ( 0.3) | 23 ( 0.1) | 87 ( 0.7) |  |  |
| como_hypoth (%) | No | 37849 (98.2) | 25518 (99.4) | 12331 (95.7) | \<0.001 |  |
|  | Yes | 709 ( 1.8) | 150 ( 0.6) | 559 ( 4.3) |  |  |
| como_cancers (%) | No | 38127 (98.9) | 25566 (99.6) | 12561 (97.4) | \<0.001 |  |
|  | Yes | 431 ( 1.1) | 102 ( 0.4) | 329 ( 2.6) |  |  |
| egg_freq4 (%) | Never | 10295 (26.7) | 6814 (26.5) | 3481 (27.0) | 0.163 |  |
|  | 1-3/mo | 9952 (25.8) | 6670 (26.0) | 3282 (25.5) |  |  |
|  | 1-4/wk | 16123 (41.8) | 10767 (41.9) | 5356 (41.6) |  |  |
|  | 5+/wk | 2188 ( 5.7) | 1417 ( 5.5) | 771 ( 6.0) |  |  |
| meat_gram_ea (mean (SD)) |  | 15.13 (26.55) | 15.40 (26.65) | 14.58 (26.34) | 0.004 |  |
| fish_gram_ea (mean (SD)) |  | 9.23 (16.20) | 9.62 (16.93) | 8.46 (14.61) | \<0.001 |  |
| alldairy2_gram_ea (mean (SD)) |  | 147.42 (185.21) | 144.52 (184.63) | 153.19 (186.23) | \<0.001 |  |
| totalveg_gram_ea (mean (SD)) |  | 300.98 (178.87) | 300.70 (178.82) | 301.54 (178.98) | 0.665 |  |
| fruits_gram_ea (mean (SD)) |  | 319.04 (222.07) | 317.87 (223.73) | 321.35 (218.73) | 0.146 |  |
| refgrains_gram_ea (mean (SD)) |  | 114.92 (115.50) | 119.22 (117.30) | 106.37 (111.34) | \<0.001 |  |
| whole_mixed_grains_gram_ea (mean (SD)) |  | 252.65 (187.68) | 248.28 (186.06) | 261.33 (190.58) | \<0.001 |  |
| nutsseeds_gram_ea (mean (SD)) |  | 23.09 (20.08) | 22.52 (19.73) | 24.23 (20.72) | \<0.001 |  |
| legumes_gram_ea (mean (SD)) |  | 77.77 (69.21) | 78.73 (70.21) | 75.84 (67.14) | \<0.001 |  |

## Cox proportional hazards models

### Egg x meat interaction
