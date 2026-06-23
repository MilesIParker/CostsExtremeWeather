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

File:     03_drought_impact_estimation.do
Purpose:  Projects the GVA cost of drought exposure for 2025-2029 by applying
          LP-DiD cumulative impact coefficients (beta_h, h = 0..4) to regions
          classified as drought-exposed (and not flood- or heatwave-exposed)
          in "ready_analysis.dta" (built by 01_data_preparation.do). Produces
          regional, NUTS1, country, and EU27-level loss tables (cumulative
          and incremental, in mn EUR and as % of baseline GVA), exported to
          Excel.

Coefficient source:
          The drought impact coefficients (`betas_dr', h = 0..4) are taken
          from:

          Usman, S., Gonzalez-Torres Fernandez, G., & Parker, M. (2025).
          "Going NUTS: The regional impact of extreme climate events over
          the medium term." European Economic Review.
          https://doi.org/10.1016/j.euroecorev.2025.105081

          Replication package for that paper (LP-DiD estimation code):
          https://github.com/MilesIParker/GoingNUTS

          The coefficients below are used here only as inputs to translate
          estimated regional GVA responses into euro and percentage loss
          figures; they are not re-estimated in this script.

Note:     Logic and code below are unchanged from the original analysis
          script. Reads "ready_analysis.dta" directly from this repository
          via the $github_path global, so this script can be run on its
          own without first running 01_data_preparation.do.
==============================================================================*/

global github_path "https://raw.githubusercontent.com/MilesIParker/CostsExtremeWeather/main"

use "$github_path/ready_analysis.dta", clear
** droughts 
**********************REGIONAL LEVEL
*--------------------------------------------------------------*
* Inputs you customize
*--------------------------------------------------------------*
* Cumulative LP–DiD coefficients β_h in log points (100*ln)
* Order: h = 0 1 2 3 4  ... (edit as needed)
local betas_dr  -1.147  -1.482  -1.499  -2.330  -2.980

*
* Shock year and baseline (GVA in **million €**)
local startyear    2025
local baseline_var GVA_2024 // Baseline counterfactual or the starting point 
local baseline_var_country GVA_2024_Country
* Derive horizon count and end year
local H = wordcount("`betas_dr'") - 1
local endyear = `startyear' + `H'


* Exposure restriction: only for droughts AND no heatwave AND no floods
capture drop sample_ok_dr
gen byte sample_ok_dr = (flood_event_max3days==0 & hotsummer_2C==0 & drought_event==1)


*---------------------------*
* REGIONAL LOSSES (mn €)
*---------------------------*
forvalues h = 0/`H' {
    local y = `startyear' + `h'
    local b : word `= `h' + 1' of `betas_dr'

    * Cumulative % vs baseline (exact)
    capture drop dr_cum_pct_`y'
    gen double dr_cum_pct_`y' = 100*(exp(`b'/100) - 1) if sample_ok_dr & !missing(`baseline_var')

    * Cumulative loss vs baseline (mn €)
    capture drop dr_loss_cum_`y'
    gen double dr_loss_cum_`y' = `baseline_var'*(exp(`b'/100) - 1) if sample_ok_dr & !missing(`baseline_var')
    label var  dr_loss_cum_`y' "Droughts: cumulative loss (mn €), `y'"

    * Incremental (extra) loss vs prior horizon
    capture drop dr_loss_incr_`y'
    if `h'==0 {
        gen double dr_loss_incr_`y' = dr_loss_cum_`y' if sample_ok_dr & !missing(`baseline_var')
    }
    else {
        local bprev : word `= `h'' of `betas_dr'
        gen double dr_loss_incr_`y' = `baseline_var'*(exp(`b'/100) - exp(`bprev'/100)) ///
            if sample_ok_dr & !missing(`baseline_var')
    }
    label var  dr_loss_incr_`y' "Droughts: incremental loss (mn €), `y'"

    * Zero-fill outside exposure so group sums work
    replace dr_loss_cum_`y'  = 0 if missing(dr_loss_cum_`y')
    replace dr_loss_incr_`y' = 0 if missing(dr_loss_incr_`y')

    format dr_loss_cum_`y' dr_loss_incr_`y' %12.2fc
}
order Territory_ID Country_ID name_latn GVA_2024 ///
      dr_loss_cum_2025 dr_loss_cum_2026 dr_loss_cum_2027 dr_loss_cum_2028 dr_loss_cum_2029 ///
      dr_loss_incr_2025 dr_loss_incr_2026 dr_loss_incr_2027 dr_loss_incr_2028 dr_loss_incr_2029

br Territory_ID Country_ID name_latn GVA_2024 ///
   dr_loss_cum_2025 dr_loss_cum_2026 dr_loss_cum_2027 dr_loss_cum_2028 dr_loss_cum_2029 ///
   dr_loss_incr_2025 dr_loss_incr_2026 dr_loss_incr_2027 dr_loss_incr_2028 dr_loss_incr_2029 ///
   if sample_ok_dr==1

preserve
    keep if sample_ok_dr==1
    keep Territory_ID Country_ID name_latn GVA_2024 ///
         dr_loss_cum_* dr_loss_incr_*
    export excel using "droughts2025.xlsx", sheet("Sheet1") firstrow(variables) replace
restore


*===========================*
* NUTS1 aggregates (2025–`endyear')
*===========================*

 gen double nuts1_baseline_2024 = GVA_2024_nuts1
* Exposed baseline per NUTS1 (sum over exposed regions)
gen double dr_exposed_base_n1_2024 = GVA_2024 if sample_ok_dr==1
bys nuts1_ID: egen double dr_nuts1_exposed_base_2024 = total(dr_exposed_base_n1_2024)

preserve
    * Sum losses by NUTS1
    collapse (sum) dr_loss_cum_* dr_loss_incr_* ///
             (firstnm) nuts1_baseline_2024 dr_nuts1_exposed_base_2024 nuts1_name, by(nuts1_ID)

    * Keep only NUTS1 units actually exposed
    keep if dr_nuts1_exposed_base_2024 > 0

    * % metrics: relative to NUTS1 total baseline and exposed baseline
    forvalues y = `startyear'/`endyear' {
        gen double dr_pct_nuts1_`y'        = 100*dr_loss_cum_`y'/nuts1_baseline_2024
        gen double dr_pct_exposed_nuts1_`y' = 100*dr_loss_cum_`y'/dr_nuts1_exposed_base_2024
    }
    gen double dr_exposed_share_nuts1_2024 = 100*dr_nuts1_exposed_base_2024/nuts1_baseline_2024

    * Labels & formatting
    label var nuts1_baseline_2024             "NUTS1 baseline GVA 2024 (mn €)"
    label var dr_nuts1_exposed_base_2024      "Drought-exposed baseline 2024 (mn €)"
    label var dr_exposed_share_nuts1_2024     "Exposed share of baseline (%)"
    format dr_loss_cum_* dr_loss_incr_* %12.2fc
    format dr_pct_nuts1_* dr_pct_exposed_nuts1_* dr_exposed_share_nuts1_2024 %9.3f

    * Preview
    list nuts1_ID nuts1_name nuts1_baseline_2024 dr_nuts1_exposed_base_2024 dr_exposed_share_nuts1_2024 ///
         dr_loss_cum_* dr_loss_incr_* dr_pct_nuts1_* dr_pct_exposed_nuts1_*, noobs
    keep nuts1_ID nuts1_name nuts1_baseline_2024 dr_nuts1_exposed_base_2024 ///
         dr_loss_cum_* dr_loss_incr_* dr_pct_nuts1_* dr_pct_exposed_nuts1_*
    order nuts1_ID nuts1_name nuts1_baseline_2024 dr_nuts1_exposed_base_2024 ///
         dr_loss_cum_* dr_loss_incr_* dr_pct_nuts1_*
    export excel using "drought2025_nuts1.xlsx", sheet("Sheet1") firstrow(variables) replace
restore



*===========================*
* Country aggregates (2025–endyear)
*===========================*

* Baselines (you used a precomputed country baseline var):
generate country_baseline_2024 = `baseline_var_country'

* Exposed baseline per country
gen double dr_exposed_base_2024 = GVA_2024 if sample_ok_dr==1
bys Country_ID: egen double dr_country_exposed_base_2024 = total(dr_exposed_base_2024)

preserve
    collapse (sum) dr_loss_cum_* dr_loss_incr_* ///
             (firstnm) country_baseline_2024 dr_country_exposed_base_2024, by(Country_ID)

    * Keep only countries actually exposed
    keep if dr_country_exposed_base_2024 > 0

    * % of total country baseline and % of exposed baseline
    foreach v of varlist dr_loss_cum_* {
        local y = substr("`v'", -4, 4)
        gen double dr_pct_country_`y' = 100*dr_loss_cum_`y'/country_baseline_2024
        gen double dr_pct_exposed_`y' = 100*dr_loss_cum_`y'/dr_country_exposed_base_2024
    }
    gen double dr_exposed_share_2024 = 100*dr_country_exposed_base_2024 / country_baseline_2024

    * Show and export
    list Country_ID country_baseline_2024 dr_country_exposed_base_2024 dr_exposed_share_2024 ///
         dr_loss_cum_* dr_loss_incr_* dr_pct_country_* dr_pct_exposed_*, noobs

    keep Country_ID country_baseline_2024 dr_country_exposed_base_2024 dr_exposed_share_2024 ///
         dr_loss_cum_* dr_loss_incr_* dr_pct_country_* dr_pct_exposed_*

    order Country_ID country_baseline_2024 dr_country_exposed_base_2024 ///
          dr_loss_cum_* dr_loss_incr_* dr_pct_country_*
    export excel using "droughts2025_country.xlsx", sheet("Sheet1") firstrow(variables) replace
restore

*===========================*
* Europe aggregates (2025–endyear)
*===========================*

* EU total baseline (mn €)
scalar EU_GVA_2024 = 16127680.72

preserve
    keep if sample_ok_dr==1
    collapse (sum) dr_loss_cum_* dr_loss_incr_* (sum) GVA_2024, fast
    rename GVA_2024 EU_exposed_base_2024

    * % of EU total baseline and % of EU exposed baseline
    foreach v of varlist dr_loss_cum_* {
        local y = substr("`v'", -4, 4)
        gen double EU_dr_pct_total_`y'   = 100*dr_loss_cum_`y'/EU_GVA_2024
        gen double EU_dr_pct_exposed_`y' = 100*dr_loss_cum_`y'/EU_exposed_base_2024
    }

    * Display one-row EU table and export
    list EU_exposed_base_2024 dr_loss_cum_* dr_loss_incr_* EU_dr_pct_total_* EU_dr_pct_exposed_*, noobs

    keep EU_exposed_base_2024 dr_loss_cum_* dr_loss_incr_* EU_dr_pct_total_* EU_dr_pct_exposed_*
    order EU_exposed_base_2024 dr_loss_cum_* dr_loss_incr_* EU_dr_pct_total_*
    export excel using "droughts2025_europe.xlsx", sheet("Sheet1") firstrow(variables) replace
restore
