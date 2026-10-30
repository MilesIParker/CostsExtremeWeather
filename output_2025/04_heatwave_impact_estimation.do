/*==============================================================================
REPLICATION PACKAGE

Paper:    Estimating the Economic Costs of Extreme Weather in Real Time

Authors:  Sehrish Usman (corresponding author) - University of Mannheim
                Sehrish.Usman@uni-mannheim.de
          Guzman Gonzalez-Torres Fernandez - Banca d'Italia
                Guzman.Gonzalez-torres@bancaditalia.it
          Maximilian Kotz - Barcelona Supercomputing Center / Potsdam Institute
                for Climate Impact Research / School of the Environment,
                University of Queensland
                maximilian.kotz@bsc.es
          Friderike Kuik - European Central Bank
                Friderike.Kuik@ecb.europa.eu
          Eliza Lis - European Central Bank
                Eliza.Lis@ecb.europa.eu
          Christiane Nickel - European Central Bank
                Christiane.Nickel@ecb.europa.eu
          Miles Parker - European Central Bank
                Miles.Parker@ecb.europa.eu
          Mathilde Vallat - European Central Bank
                vallatmathilde@gmail.com

Disclaimer: The views expressed here are those of the authors and do not
            necessarily represent those of the Banca d'Italia, the European
            Central Bank, or its Governing Council.

File:     04_heatwave_impact_estimation.do
Purpose:  Projects the GVA cost of heatwave exposure for 2025-2029 by applying
          LP-DiD cumulative impact coefficients (beta_h, h = 0..4) to regions
          classified as heatwave-exposed (and not flood- or drought-exposed)
          in "ready_analysis.dta" (built by 01_data_preparation.do).
          Coefficients are applied separately by regional climate type (cold,
          temperate, hot, via "Baseline_climate") as well as using a single
          pooled "average" coefficient set, and 90% confidence intervals are
          constructed around the point estimates. Produces regional, NUTS1,
          NUTS2, country, EU27, and Eurozone-level loss tables (cumulative,
          in mn EUR and as % of baseline GVA), exported to Excel.

Coefficient source:
          The heatwave impact coefficients (`betas_hw_avg', `betas_hw_cold',
          `betas_hw_temper', `betas_hw_hot', h = 0..4) and their standard
          errors are taken from:

          Usman, S., Gonzalez-Torres Fernandez, G., & Parker, M. (2025).
          "Going NUTS: The regional impact of extreme climate events over
          the medium term." European Economic Review.
          https://doi.org/10.1016/j.euroecorev.2025.105081

          Replication package for that paper (LP-DiD estimation code):
          https://github.com/MilesIParker/GoingNUTS

          The coefficients below are used here only as inputs to translate
          estimated regional GVA responses (and their 90% confidence
          intervals) into euro and percentage loss figures; they are not
          re-estimated in this script.

Note:     Logic and code below are unchanged from the original analysis
          script. Update the "use" path to the local location of
          "ready_analysis.dta" produced by 01_data_preparation.do before
          running (the path below currently points to a personal OneDrive
          folder and should be replaced with the replication package's
          relative path). This script depends on the "Baseline_climate"
          variable (1 = cold, 2 = temperate, 3 = hot region) to assign
          climate-type-specific coefficients; confirm this variable is
          present and correctly coded in the input dataset before running,
          as regions with a missing or unmatched value will be silently
          zero-filled rather than flagged.
==============================================================================*/

*******************************************************  
* HEATWAVES — REGIONAL IMPACTS (baseline=2024) + 90% CI (losses only)
******************************************************* 
/*
Average coefficients 
-0.895***   -0.910*    -1.545**    -1.090    -1.011 
(0.299)     (0.484)     (0.616)    (0.671)   (0.793) 


Cold regions 
  -0.00226          -0.533          -1.600          -0.837          -1.044   
(0.454)         (0.655)         (0.887)     (1.009)         (1.089)  

Temperate regions
-1.223**        -0.795          -0.531       -0.459          -0.778   
(0.435)         (0.716)         (0.868)      (0.917)         (1.208)   

Hot regions 
 -1.446          -1.715          -6.593*      -10.14***       -8.904** 
(1.296)         (2.572)         (2.706)       (2.525)         (2.802)   



*/
use "C:\Users\sehusman\OneDrive - uni-mannheim.de\Climate GSCC\output\ready_analysis", clear
*******************************************************
* HEATWAVES — REGIONAL IMPACTS by climate type (baseline=2024)
* Point estimates in main data; 90% CI only inside PRESERVE
*******************************************************
*---------------------------
* Coefficients (β in log points = 100*ln) and SEs by type
*---------------------------
local betas_hw_avg    -0.895   -0.910   -1.545   -1.090   -1.011
local ses_hw_avg       0.299    0.484    0.616    0.671    0.793

local betas_hw_cold   -0.00226 -0.533   -1.600   -0.837   -1.044
local ses_hw_cold      0.454     0.655    0.887    1.009    1.089

local betas_hw_temper  -1.223   -0.795   -0.531   -0.459   -0.778
local ses_hw_temper     0.435     0.716    0.868    0.917    1.208

local betas_hw_hot     -1.446   -1.715   -6.593  -10.140   -8.904
local ses_hw_hot        1.296     2.572    2.706    2.525    2.802

*---------------------------
* Settings
*---------------------------
local z          1.645          // 90% CI
local startyear  2025
local baseline_var GVA_2024

* Horizon length from "avg" set
local H = wordcount("`betas_hw_avg'") - 1
local endyear = `startyear' + `H'

* Exposure flag (restrict however you like)
capture drop sample_ok_hw
gen byte sample_ok_hw = (hotsummer_2C==1 & flood_event_max3days==0 & drought_event==0)

*===========================
* Unified variables per year
*===========================
forvalues h = 0/`H' {
    local y = `startyear' + `h'

    * pull the h-th beta/se for each type
    local b_avg   : word `= `h'+1' of `betas_hw_avg'
    local s_avg   : word `= `h'+1' of `ses_hw_avg'
    local b_cold  : word `= `h'+1' of `betas_hw_cold'
    local s_cold  : word `= `h'+1' of `ses_hw_cold'
    local b_temp  : word `= `h'+1' of `betas_hw_temper'
    local s_temp  : word `= `h'+1' of `ses_hw_temper'
    local b_hot   : word `= `h'+1' of `betas_hw_hot'
    local s_hot   : word `= `h'+1' of `ses_hw_hot'

    * ---- unified cumulative % (point)
    capture drop hw_cum_pct_`y'
    gen double hw_cum_pct_`y' = . 
    replace hw_cum_pct_`y' = 100*(exp(`b_cold'/100) - 1)  if sample_ok_hw & Baseline_climate==1 & !missing(`baseline_var')
    replace hw_cum_pct_`y' = 100*(exp(`b_temp'/100) - 1)  if sample_ok_hw & Baseline_climate==2 & !missing(`baseline_var')
    replace hw_cum_pct_`y' = 100*(exp(`b_hot'/100)  - 1)  if sample_ok_hw & Baseline_climate==3 & !missing(`baseline_var')
    replace hw_cum_pct_`y' = 0 if missing(hw_cum_pct_`y')
    format  hw_cum_pct_`y' %9.3f

    * ---- unified cumulative loss (mn €): point + 90% CI
    capture drop hw_loss_cum_`y' hw_loss_cum_lo_`y' hw_loss_cum_hi_`y'
    gen double hw_loss_cum_`y'    = .
    gen double hw_loss_cum_lo_`y' = .
    gen double hw_loss_cum_hi_`y' = .

    * cold
    replace hw_loss_cum_`y'    = `baseline_var'*(exp(`b_cold'/100)                 - 1) if sample_ok_hw & Baseline_climate==1 & !missing(`baseline_var')
    replace hw_loss_cum_lo_`y' = `baseline_var'*(exp((`b_cold' - `z'*`s_cold')/100) - 1) if sample_ok_hw & Baseline_climate==1 & !missing(`baseline_var')
    replace hw_loss_cum_hi_`y' = `baseline_var'*(exp((`b_cold' + `z'*`s_cold')/100) - 1) if sample_ok_hw & Baseline_climate==1 & !missing(`baseline_var')

    * temperate
    replace hw_loss_cum_`y'    = `baseline_var'*(exp(`b_temp'/100)                 - 1) if sample_ok_hw & Baseline_climate==2 & !missing(`baseline_var')
    replace hw_loss_cum_lo_`y' = `baseline_var'*(exp((`b_temp' - `z'*`s_temp')/100) - 1) if sample_ok_hw & Baseline_climate==2 & !missing(`baseline_var')
    replace hw_loss_cum_hi_`y' = `baseline_var'*(exp((`b_temp' + `z'*`s_temp')/100) - 1) if sample_ok_hw & Baseline_climate==2 & !missing(`baseline_var')

    * hot
    replace hw_loss_cum_`y'    = `baseline_var'*(exp(`b_hot'/100)                  - 1) if sample_ok_hw & Baseline_climate==3 & !missing(`baseline_var')
    replace hw_loss_cum_lo_`y' = `baseline_var'*(exp((`b_hot' - `z'*`s_hot')/100)  - 1) if sample_ok_hw & Baseline_climate==3 & !missing(`baseline_var')
    replace hw_loss_cum_hi_`y' = `baseline_var'*(exp((`b_hot' + `z'*`s_hot')/100)  - 1) if sample_ok_hw & Baseline_climate==3 & !missing(`baseline_var')

    * zero-fill for clean aggregation
    replace hw_loss_cum_`y'    = 0 if missing(hw_loss_cum_`y')
    replace hw_loss_cum_lo_`y' = 0 if missing(hw_loss_cum_lo_`y')
    replace hw_loss_cum_hi_`y' = 0 if missing(hw_loss_cum_hi_`y')
    format  hw_loss_cum_`y' hw_loss_cum_lo_`y' hw_loss_cum_hi_`y' %12.2fc

    * ---- "average effects" kept separately (point + 90% CI)
    capture drop hw_avg_cum_pct_`y' hw_avg_loss_cum_`y' hw_avg_loss_cum_lo_`y' hw_avg_loss_cum_hi_`y'
    gen double hw_avg_cum_pct_`y'    = 100*(exp(`b_avg'/100) - 1)                                  if sample_ok_hw & !missing(`baseline_var')
    gen double hw_avg_loss_cum_`y'   = `baseline_var'*(exp(`b_avg'/100) - 1)                       if sample_ok_hw & !missing(`baseline_var')
    gen double hw_avg_loss_cum_lo_`y'= `baseline_var'*(exp((`b_avg' - `z'*`s_avg')/100) - 1)       if sample_ok_hw & !missing(`baseline_var')
    gen double hw_avg_loss_cum_hi_`y'= `baseline_var'*(exp((`b_avg' + `z'*`s_avg')/100) - 1)       if sample_ok_hw & !missing(`baseline_var')

    replace hw_avg_cum_pct_`y'     = 0 if missing(hw_avg_cum_pct_`y')
    replace hw_avg_loss_cum_`y'    = 0 if missing(hw_avg_loss_cum_`y')
    replace hw_avg_loss_cum_lo_`y' = 0 if missing(hw_avg_loss_cum_lo_`y')
    replace hw_avg_loss_cum_hi_`y' = 0 if missing(hw_avg_loss_cum_hi_`y')
    format  hw_avg_cum_pct_`y' %9.3f
    format  hw_avg_loss_cum_`y' hw_avg_loss_cum_lo_`y' hw_avg_loss_cum_hi_`y' %12.2fc
}

* Result:
* - Unified variables per year:   hw_loss_cum_YYYY, hw_loss_cum_lo_YYYY, hw_loss_cum_hi_YYYY, hw_cum_pct_YYYY
* - Average-only variables:       hw_avg_loss_cum_YYYY, hw_avg_loss_cum_lo_YYYY, hw_avg_loss_cum_hi_YYYY, hw_avg_cum_pct_YYYY

preserve 
		keep if sample_ok_hw ==1
        order Territory_ID Country_ID name_latn GVA_2024 ///
              hw_loss_cum_2025 hw_loss_cum_2026 hw_loss_cum_2027 hw_loss_cum_2028 hw_loss_cum_2029 hw_loss_cum_lo_2025 hw_loss_cum_lo_2026 hw_loss_cum_lo_2027 hw_loss_cum_lo_2028 hw_loss_cum_lo_2029 hw_loss_cum_hi_2025 hw_loss_cum_hi_2026 hw_loss_cum_hi_2027 hw_loss_cum_hi_2028 hw_loss_cum_hi_2029 hw_cum_pct_2025 hw_cum_pct_2026 hw_cum_pct_2027 hw_cum_pct_2028 hw_cum_pct_2029

        keep Territory_ID Country_ID name_latn GVA_2024 ///
             hw_loss_cum_2025 hw_loss_cum_2026 hw_loss_cum_2027 hw_loss_cum_2028 hw_loss_cum_2029 hw_loss_cum_lo_2025 hw_loss_cum_lo_2026 hw_loss_cum_lo_2027 hw_loss_cum_lo_2028 hw_loss_cum_lo_2029 hw_loss_cum_hi_2025 hw_loss_cum_hi_2026 hw_loss_cum_hi_2027 hw_loss_cum_hi_2028 hw_loss_cum_hi_2029 hw_cum_pct_2025 hw_cum_pct_2026 hw_cum_pct_2027 hw_cum_pct_2028 hw_cum_pct_2029


        export excel using "heatwaves2025_nuts3_2C_CI.xlsx", ///
            sheet("Sheet1") firstrow(variables) replace
			
restore

preserve 
		keep if sample_ok_hw ==1
        order Territory_ID Country_ID name_latn GVA_2024 ///
              hw_avg_loss_cum_2025 hw_avg_loss_cum_2026 hw_avg_loss_cum_2027 hw_avg_loss_cum_lo_2025 hw_avg_loss_cum_lo_2026 hw_avg_loss_cum_lo_2027 hw_avg_loss_cum_hi_2025 hw_avg_loss_cum_hi_2026 hw_avg_loss_cum_hi_2027 hw_avg_cum_pct_2025 hw_avg_cum_pct_2026 hw_avg_cum_pct_2027

        keep Territory_ID Country_ID name_latn GVA_2024 ///
 hw_avg_loss_cum_2025 hw_avg_loss_cum_2026 hw_avg_loss_cum_2027 hw_avg_loss_cum_lo_2025 hw_avg_loss_cum_lo_2026 hw_avg_loss_cum_lo_2027 hw_avg_loss_cum_hi_2025 hw_avg_loss_cum_hi_2026 hw_avg_loss_cum_hi_2027 hw_avg_cum_pct_2025 hw_avg_cum_pct_2026 hw_avg_cum_pct_2027

        export excel using "heatwaves2025_regions_2C_CI_avg.xlsx", ///
            sheet("Sheet1") firstrow(variables) replace
			
restore
*===========================*
* NUTS1 aggregates (2025–`endyear') — Generic + Average
*===========================*

* Baselines at NUTS1
capture drop nuts1_baseline_2024 hw_exposed_base_n1_2024 hw_nuts1_exposed_base_2024
gen double nuts1_baseline_2024     = GVA_2024_nuts1
gen double hw_exposed_base_n1_2024 = GVA_2024 if sample_ok_hw==1
bys nuts1_ID: egen double hw_nuts1_exposed_base_2024 = total(hw_exposed_base_n1_2024)

* Build lists of variables to sum
local sum_gen ""
local sum_gen_lo ""
local sum_gen_hi ""
local sum_avg ""
local sum_avg_lo ""
local sum_avg_hi ""
forvalues y = `startyear'/`endyear' {
    local sum_gen     "`sum_gen'     hw_loss_cum_`y'"
    local sum_gen_lo  "`sum_gen_lo'  hw_loss_cum_lo_`y'"
    local sum_gen_hi  "`sum_gen_hi'  hw_loss_cum_hi_`y'"
    local sum_avg     "`sum_avg'     hw_avg_loss_cum_`y'"
    local sum_avg_lo  "`sum_avg_lo'  hw_avg_loss_cum_lo_`y'"
    local sum_avg_hi  "`sum_avg_hi'  hw_avg_loss_cum_hi_`y'"
}

preserve
    * Collapse to NUTS1 level, summing losses & CI bounds; carry baseline(s) and names
    collapse (sum) `sum_gen' `sum_gen_lo' `sum_gen_hi' ///
                   `sum_avg' `sum_avg_lo' `sum_avg_hi' ///
             (firstnm) nuts1_baseline_2024 hw_nuts1_exposed_base_2024 nuts1_name, by(nuts1_ID)

    * Keep only NUTS1 units actually exposed (optional; drop this line if you want all)
    keep if hw_nuts1_exposed_base_2024 > 0

    * Percent metrics (generic vs average), relative to total and exposed baselines
    forvalues y = `startyear'/`endyear' {
        gen double hw_pct_nuts1_`y'         = cond(nuts1_baseline_2024>0,        100*hw_loss_cum_`y'/nuts1_baseline_2024, .)
        gen double hw_pct_exposed_nuts1_`y' = cond(hw_nuts1_exposed_base_2024>0, 100*hw_loss_cum_`y'/hw_nuts1_exposed_base_2024, .)

        gen double hw_avg_pct_nuts1_`y'         = cond(nuts1_baseline_2024>0,        100*hw_avg_loss_cum_`y'/nuts1_baseline_2024, .)
        gen double hw_avg_pct_exposed_nuts1_`y' = cond(hw_nuts1_exposed_base_2024>0, 100*hw_avg_loss_cum_`y'/hw_nuts1_exposed_base_2024, .)
    }

    * Share of NUTS1 baseline that is exposed (just for context)
    gen double hw_exposed_share_nuts1_2024 = cond(nuts1_baseline_2024>0, 100*hw_nuts1_exposed_base_2024/nuts1_baseline_2024, .)

    * Labels & formatting
    label var nuts1_baseline_2024           "NUTS1 baseline GVA 2024 (mn €)"
    label var hw_nuts1_exposed_base_2024    "Heatwave-exposed baseline 2024 (mn €)"
    label var hw_exposed_share_nuts1_2024   "Exposed share of baseline (%)"
    format hw_loss_cum_* hw_loss_cum_lo_* hw_loss_cum_hi_* ///
           hw_avg_loss_cum_* hw_avg_loss_cum_lo_* hw_avg_loss_cum_hi_* %12.2fc
    format hw_pct_nuts1_* hw_pct_exposed_nuts1_* ///
           hw_avg_pct_nuts1_* hw_avg_pct_exposed_nuts1_* ///
           hw_exposed_share_nuts1_2024 %9.3f

    * Preview (compact)
    list nuts1_ID nuts1_name nuts1_baseline_2024 hw_nuts1_exposed_base_2024 hw_exposed_share_nuts1_2024 ///
         hw_loss_cum_`startyear' hw_loss_cum_`endyear' ///
         hw_loss_cum_lo_`startyear' hw_loss_cum_hi_`startyear' ///
         hw_avg_loss_cum_`startyear' hw_avg_loss_cum_`endyear', noobs

    * Export a tidy NUTS1 table (generic + average + CIs + %s)
    order nuts1_ID nuts1_name nuts1_baseline_2024 hw_nuts1_exposed_base_2024 hw_exposed_share_nuts1_2024 ///
          hw_loss_cum_* hw_loss_cum_lo_* hw_loss_cum_hi_* ///
          hw_avg_loss_cum_* hw_avg_loss_cum_lo_* hw_avg_loss_cum_hi_* ///
          hw_pct_nuts1_* hw_pct_exposed_nuts1_* hw_avg_pct_nuts1_* hw_avg_pct_exposed_nuts1_*
    export excel using "heatwaves2025_nuts1_2C_CIs.xlsx", sheet("Sheet1") firstrow(variables) replace
restore

*===========================*
* NUTS2 aggregates (2025–`endyear') — Generic + Average
*===========================*

* Baselines at NUTS2
capture drop nuts2_baseline_2024 hw_exposed_base_n2_2024 hw_nuts2_exposed_base_2024
gen double nuts2_baseline_2024     = GVA_2024_nuts2
gen double hw_exposed_base_n2_2024 = GVA_2024 if sample_ok_hw==1
bys nuts2_ID: egen double hw_nuts2_exposed_base_2024 = total(hw_exposed_base_n2_2024)

* Build lists of variables to sum
local sum_gen ""
local sum_gen_lo ""
local sum_gen_hi ""
local sum_avg ""
local sum_avg_lo ""
local sum_avg_hi ""
forvalues y = `startyear'/`endyear' {
    local sum_gen     "`sum_gen'     hw_loss_cum_`y'"
    local sum_gen_lo  "`sum_gen_lo'  hw_loss_cum_lo_`y'"
    local sum_gen_hi  "`sum_gen_hi'  hw_loss_cum_hi_`y'"
    local sum_avg     "`sum_avg'     hw_avg_loss_cum_`y'"
    local sum_avg_lo  "`sum_avg_lo'  hw_avg_loss_cum_lo_`y'"
    local sum_avg_hi  "`sum_avg_hi'  hw_avg_loss_cum_hi_`y'"
}

preserve
    * Collapse to NUTS2 level, summing losses & CI bounds; carry baseline(s) and names
    collapse (sum) `sum_gen' `sum_gen_lo' `sum_gen_hi' ///
                   `sum_avg' `sum_avg_lo' `sum_avg_hi' ///
             (firstnm) nuts2_baseline_2024 hw_nuts2_exposed_base_2024 nuts2_name pop_2025_nuts2, by(nuts2_ID)

    * Keep only NUTS2 units actually exposed (optional; drop this line if you want all)
    keep if hw_nuts2_exposed_base_2024 > 0

    * Percent metrics (generic vs average), relative to total and exposed baselines
    forvalues y = `startyear'/`endyear' {
        gen double hw_pct_nuts2_`y'         = cond(nuts2_baseline_2024>0,        100*hw_loss_cum_`y'/nuts2_baseline_2024, .)
        gen double hw_pct_exposed_nuts2_`y' = cond(hw_nuts2_exposed_base_2024>0, 100*hw_loss_cum_`y'/hw_nuts2_exposed_base_2024, .)

        gen double hw_avg_pct_nuts2_`y'         = cond(nuts2_baseline_2024>0,        100*hw_avg_loss_cum_`y'/nuts2_baseline_2024, .)
        gen double hw_avg_pct_exposed_nuts2_`y' = cond(hw_nuts2_exposed_base_2024>0, 100*hw_avg_loss_cum_`y'/hw_nuts2_exposed_base_2024, .)
    }

    * Share of NUTS2 baseline that is exposed (just for context)
    gen double hw_exposed_share_nuts2_2024 = cond(nuts2_baseline_2024>0, 100*hw_nuts2_exposed_base_2024/nuts2_baseline_2024, .)

    * Labels & formatting
    label var nuts2_baseline_2024           "NUTS2 baseline GVA 2024 (mn €)"
    label var hw_nuts2_exposed_base_2024    "Heatwave-exposed baseline 2024 (mn €)"
    label var hw_exposed_share_nuts2_2024   "Exposed share of baseline (%)"
    format hw_loss_cum_* hw_loss_cum_lo_* hw_loss_cum_hi_* ///
           hw_avg_loss_cum_* hw_avg_loss_cum_lo_* hw_avg_loss_cum_hi_* %12.2fc
    format hw_pct_nuts2_* hw_pct_exposed_nuts2_* ///
           hw_avg_pct_nuts2_* hw_avg_pct_exposed_nuts2_* ///
           hw_exposed_share_nuts2_2024 %9.3f

    * Preview (compact)
    list nuts2_ID nuts2_name nuts2_baseline_2024 hw_nuts2_exposed_base_2024 hw_exposed_share_nuts2_2024 ///
         hw_loss_cum_`startyear' hw_loss_cum_`endyear' ///
         hw_loss_cum_lo_`startyear' hw_loss_cum_hi_`startyear' ///
         hw_avg_loss_cum_`startyear' hw_avg_loss_cum_`endyear', noobs

    * Export a tidy NUTS2 table (generic + average + CIs + %s)
    order nuts2_ID nuts2_name nuts2_baseline_2024 hw_nuts2_exposed_base_2024 hw_exposed_share_nuts2_2024 ///
          hw_loss_cum_* hw_loss_cum_lo_* hw_loss_cum_hi_* ///
          hw_avg_loss_cum_* hw_avg_loss_cum_lo_* hw_avg_loss_cum_hi_* ///
          hw_pct_nuts2_* hw_pct_exposed_nuts2_* hw_avg_pct_nuts2_* hw_avg_pct_exposed_nuts2_*
    export excel using "heatwaves2025_nuts2_2C_CIs.xlsx", sheet("Sheet1") firstrow(variables) replace
restore


*---------------------------*
* Country aggregates (2025–`endyear') — Generic + Average, with CIs
*---------------------------*

* Country baselines & exposed baseline
capture drop country_baseline_2024 hw_exposed_base_2024 hw_country_exposed_base_2024
gen double country_baseline_2024     = GVA_2024_Country
gen double hw_exposed_base_2024      = `baseline_var' if sample_ok_hw==1   // exposure flag you already created
bys Country_ID: egen double hw_country_exposed_base_2024 = total(hw_exposed_base_2024)

* Build lists to collapse (sum) for generic & average series and their CIs
local sum_gen ""
local sum_gen_lo ""
local sum_gen_hi ""
local sum_avg ""
local sum_avg_lo ""
local sum_avg_hi ""
forvalues y = `startyear'/`endyear' {
    local sum_gen       "`sum_gen'       hw_loss_cum_`y'"
    local sum_gen_lo    "`sum_gen_lo'    hw_loss_cum_lo_`y'"
    local sum_gen_hi    "`sum_gen_hi'    hw_loss_cum_hi_`y'"
    local sum_avg       "`sum_avg'       hw_avg_loss_cum_`y'"
    local sum_avg_lo    "`sum_avg_lo'    hw_avg_loss_cum_lo_`y'"
    local sum_avg_hi    "`sum_avg_hi'    hw_avg_loss_cum_hi_`y'"
}

preserve
    * Collapse to country level
    collapse (sum) `sum_gen' `sum_gen_lo' `sum_gen_hi'  ///
                   `sum_avg' `sum_avg_lo' `sum_avg_hi' ///
             (firstnm) country_baseline_2024 hw_country_exposed_base_2024, by(Country_ID)

    * Give country-level CI vars distinct names to avoid confusion
    forvalues y = `startyear'/`endyear' {
        rename hw_loss_cum_lo_`y'     hw_cty_loss_cum_lo_`y'
        rename hw_loss_cum_hi_`y'     hw_cty_loss_cum_hi_`y'
        rename hw_avg_loss_cum_lo_`y' hw_cty_avg_loss_cum_lo_`y'
        rename hw_avg_loss_cum_hi_`y' hw_cty_avg_loss_cum_hi_`y'
    }

    * Keep only countries with some exposed baseline (optional)
    keep if hw_country_exposed_base_2024 > 0

    * Percent metrics: generic vs average
    forvalues y = `startyear'/`endyear' {
        gen double hw_pct_country_`y'        = cond(country_baseline_2024>0,        100*hw_loss_cum_`y'/country_baseline_2024, .)
        gen double hw_pct_exposed_`y'        = cond(hw_country_exposed_base_2024>0, 100*hw_loss_cum_`y'/hw_country_exposed_base_2024, .)

        gen double hw_avg_pct_country_`y'    = cond(country_baseline_2024>0,        100*hw_avg_loss_cum_`y'/country_baseline_2024, .)
        gen double hw_avg_pct_exposed_`y'    = cond(hw_country_exposed_base_2024>0, 100*hw_avg_loss_cum_`y'/hw_country_exposed_base_2024, .)
    }

    * Exposed share of country baseline
    gen double hw_exposed_share_2024 = cond(country_baseline_2024>0, 100*hw_country_exposed_base_2024/country_baseline_2024, .)

    * Labels & formats
    label var country_baseline_2024          "Country baseline GVA 2024 (mn €)"
    label var hw_country_exposed_base_2024   "Heatwave-exposed baseline 2024 (mn €)"
    label var hw_exposed_share_2024          "Exposed share of baseline (%)"
    format hw_loss_cum_* hw_cty_loss_cum_lo_* hw_cty_loss_cum_hi_*  ///
           hw_avg_loss_cum_* hw_cty_avg_loss_cum_lo_* hw_cty_avg_loss_cum_hi_* %12.2fc
    format hw_pct_country_* hw_pct_exposed_* hw_avg_pct_country_* hw_avg_pct_exposed_* hw_exposed_share_2024 %9.3f

    * Preview (short)
    list Country_ID country_baseline_2024 hw_country_exposed_base_2024 hw_exposed_share_2024 ///
         hw_loss_cum_`startyear' hw_loss_cum_`endyear' hw_cty_loss_cum_lo_`startyear' hw_cty_loss_cum_hi_`startyear' ///
         hw_avg_loss_cum_`startyear' hw_avg_loss_cum_`endyear', noobs

    * Export tidy country table
    order Country_ID country_baseline_2024 hw_country_exposed_base_2024 hw_exposed_share_2024 ///
          hw_loss_cum_* hw_cty_loss_cum_lo_* hw_cty_loss_cum_hi_* ///
          hw_avg_loss_cum_* hw_cty_avg_loss_cum_lo_* hw_cty_avg_loss_cum_hi_* ///
          hw_pct_country_* hw_pct_exposed_* hw_avg_pct_country_* hw_avg_pct_exposed_*
    export excel using "heatwaves2025_country_2C_CI.xlsx", sheet("Sheet1") firstrow(variables) replace
restore

*---------------------------*
* Europe aggregates (2025–`endyear') — Generic + Average, with CIs
*---------------------------*

* EU total baseline (mn €)
scalar EU_GVA_2024 = 16127680.72

* Build varlists to sum across years
local sum_gen ""
local sum_gen_lo ""
local sum_gen_hi ""
local sum_avg ""
local sum_avg_lo ""
local sum_avg_hi ""
forvalues y = `startyear'/`endyear' {
    local sum_gen    "`sum_gen'    hw_loss_cum_`y'"
    local sum_gen_lo "`sum_gen_lo' hw_loss_cum_lo_`y'"
    local sum_gen_hi "`sum_gen_hi' hw_loss_cum_hi_`y'"
    local sum_avg    "`sum_avg'    hw_avg_loss_cum_`y'"
    local sum_avg_lo "`sum_avg_lo' hw_avg_loss_cum_lo_`y'"
    local sum_avg_hi "`sum_avg_hi' hw_avg_loss_cum_hi_`y'"
}

preserve
    * Keep exposed regions only (your exposure flag for heatwaves)
    keep if sample_ok_hw==1

    * Sum losses and exposed baseline across the EU
    collapse (sum) `sum_gen' `sum_gen_lo' `sum_gen_hi' ///
                   `sum_avg' `sum_avg_lo' `sum_avg_hi' ///
             (sum) `baseline_var', fast
    rename `baseline_var' EU_exposed_base_2024

    * Percent metrics (generic + average)
    forvalues y = `startyear'/`endyear' {
        gen double EU_hw_pct_total_`y'    = 100*hw_loss_cum_`y'/EU_GVA_2024
        gen double EU_hw_pct_exposed_`y'  = 100*hw_loss_cum_`y'/EU_exposed_base_2024

        gen double EU_hw_avg_pct_total_`y'   = 100*hw_avg_loss_cum_`y'/EU_GVA_2024
        gen double EU_hw_avg_pct_exposed_`y' = 100*hw_avg_loss_cum_`y'/EU_exposed_base_2024
    }

    * Labels & formatting
    label var EU_exposed_base_2024 "EU exposed baseline 2024 (mn €)"
    format hw_loss_cum_* hw_loss_cum_lo_* hw_loss_cum_hi_* ///
           hw_avg_loss_cum_* hw_avg_loss_cum_lo_* hw_avg_loss_cum_hi_* %15.2fc
    format EU_hw_pct_total_* EU_hw_pct_exposed_* ///
           EU_hw_avg_pct_total_* EU_hw_avg_pct_exposed_* %9.3f

    * Quick preview
    list EU_exposed_base_2024 hw_loss_cum_`startyear' hw_loss_cum_`endyear' ///
         hw_avg_loss_cum_`startyear' hw_avg_loss_cum_`endyear' ///
         EU_hw_pct_total_`startyear' EU_hw_pct_total_`endyear', noobs

    * Export tidy EU table
    order EU_exposed_base_2024 ///
          hw_loss_cum_* hw_loss_cum_lo_* hw_loss_cum_hi_* ///
          hw_avg_loss_cum_* hw_avg_loss_cum_lo_* hw_avg_loss_cum_hi_* ///
          EU_hw_pct_total_* EU_hw_pct_exposed_* EU_hw_avg_pct_total_* EU_hw_avg_pct_exposed_*
    export excel using "heatwaves2025_europe_2C_CI.xlsx", sheet("Sheet1") firstrow(variables) replace
restore
*---------------------------*
* Eurozone aggregates (2025–`endyear') — Generic + Average, with CIs
*---------------------------*

* Eurozone total baseline (mn €)
scalar Eurozone_GVA_2024 = 13638343

* Build varlists to sum across years
local sum_gen ""
local sum_gen_lo ""
local sum_gen_hi ""
local sum_avg ""
local sum_avg_lo ""
local sum_avg_hi ""
forvalues y = `startyear'/`endyear' {
    local sum_gen    "`sum_gen'    hw_loss_cum_`y'"
    local sum_gen_lo "`sum_gen_lo' hw_loss_cum_lo_`y'"
    local sum_gen_hi "`sum_gen_hi' hw_loss_cum_hi_`y'"
    local sum_avg    "`sum_avg'    hw_avg_loss_cum_`y'"
    local sum_avg_lo "`sum_avg_lo' hw_avg_loss_cum_lo_`y'"
    local sum_avg_hi "`sum_avg_hi' hw_avg_loss_cum_hi_`y'"
}

preserve
    * Keep Eurozone & exposed heatwave regions (your "avg" exposure flag covers all HW with filters)
    keep if eurozone==1 & sample_ok_hw==1

    * Sum losses and exposed baseline across Eurozone
    collapse (sum) `sum_gen' `sum_gen_lo' `sum_gen_hi' ///
                   `sum_avg' `sum_avg_lo' `sum_avg_hi' ///
             (sum) `baseline_var', fast
    rename `baseline_var' EZ_exposed_base_2024

    * Percent metrics (generic + average)
    forvalues y = `startyear'/`endyear' {
        gen double EZ_hw_pct_total_`y'      = 100*hw_loss_cum_`y'/Eurozone_GVA_2024
        gen double EZ_hw_pct_exposed_`y'    = 100*hw_loss_cum_`y'/EZ_exposed_base_2024

        gen double EZ_hw_avg_pct_total_`y'   = 100*hw_avg_loss_cum_`y'/Eurozone_GVA_2024
        gen double EZ_hw_avg_pct_exposed_`y' = 100*hw_avg_loss_cum_`y'/EZ_exposed_base_2024
    }

    * Labels & formatting
    label var EZ_exposed_base_2024 "Eurozone exposed baseline 2024 (mn €)"
    format hw_loss_cum_* hw_loss_cum_lo_* hw_loss_cum_hi_* ///
           hw_avg_loss_cum_* hw_avg_loss_cum_lo_* hw_avg_loss_cum_hi_* %15.2fc
    format EZ_hw_pct_total_* EZ_hw_pct_exposed_* ///
           EZ_hw_avg_pct_total_* EZ_hw_avg_pct_exposed_* %9.3f

    * Quick preview
    list EZ_exposed_base_2024 hw_loss_cum_`startyear' hw_loss_cum_`endyear' ///
         hw_avg_loss_cum_`startyear' hw_avg_loss_cum_`endyear' ///
         EZ_hw_pct_total_`startyear' EZ_hw_pct_total_`endyear', noobs

    * Export tidy Eurozone table
    order EZ_exposed_base_2024 ///
          hw_loss_cum_* hw_loss_cum_lo_* hw_loss_cum_hi_* ///
          hw_avg_loss_cum_* hw_avg_loss_cum_lo_* hw_avg_loss_cum_hi_* ///
          EZ_hw_pct_total_* EZ_hw_pct_exposed_* EZ_hw_avg_pct_total_* EZ_hw_avg_pct_exposed_*
    export excel using "heatwaves2025_eurozone_2C_CI.xlsx", sheet("Sheet1") firstrow(variables) replace
restore
