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

File:     02_flood_impact_estimation.do
Purpose:  Projects the GVA cost of flood exposure for 2025-2029 by applying
          LP-DiD cumulative impact coefficients (beta_h, h = 0..4) to regions
          classified as flood-exposed in "ready_analysis.dta" (built by
          01_data_preparation.do). Produces regional NUTS3, NUTS1, country, EU27,
          and Eurozone-level loss tables (cumulative and incremental, in mn EUR
          and as % of baseline GVA), exported to Excel.

Coefficient source:
          The flood impact coefficients (`betas_fl', h = 0..4) and their
          standard errors are taken from:

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
          script, aside from removing one duplicated section. Reads
          "ready_analysis.dta" directly from this repository via the
          $github_path global, so this script can be run on its own
          without first running 01_data_preparation.do.
==============================================================================*/

global github_path "https://raw.githubusercontent.com/MilesIParker/CostsExtremeWeather/main"

use "$github_path/ready_analysis.dta", clear
*******************************************************
* FLOODS — REGIONAL, COUNTRY, EU AGGREGATES (baseline=2024)

*---------------------------*
* Inputs you customize
*---------------------------*
* LP–DiD cumulative coefficients β_h (log points = 100*ln), h=0..4
* Source: Usman, Gonzalez-Torres Fernandez & Parker (2025), "Going NUTS",
* European Economic Review, https://doi.org/10.1016/j.euroecorev.2025.105081
local betas_fl  -0.902  -1.858  -2.968  -3.050  -2.824
* standard errors (0.308)  (0.477)  (0.871)  (0.883)  (0.970)

* Shock year and baselines (GVA in mn €)
local startyear    2025
local baseline_var GVA_2024

* Derive horizon count and end year
local H = wordcount("`betas_fl'") - 1
local endyear = `startyear' + `H'

* Exposure restriction: flood AND no heatwave AND no flood
capture drop sample_ok_fl
gen byte sample_ok_fl = (flood_event_max3days==1)

*---------------------------*
* Regional losses (mn €)
*---------------------------*
forvalues h = 0/`H' {
    local y = `startyear' + `h'
    local b : word `= `h' + 1' of `betas_fl'

    * Cumulative % vs 2024 baseline (exact)
    capture drop fl_cum_pct_`y'
    gen double fl_cum_pct_`y' = 100*(exp(`b'/100)-1) if sample_ok_fl & !missing(`baseline_var')

    * Cumulative loss vs 2024 baseline (mn €)
    capture drop fl_loss_cum_`y'
    gen double fl_loss_cum_`y' = `baseline_var'*(exp(`b'/100)-1) if sample_ok_fl & !missing(`baseline_var')
    label var fl_loss_cum_`y' "Flood: cumulative loss (mn €), `y'"

    * Incremental loss vs prior year (mn €)
    capture drop fl_loss_incr_`y'
    if `h'==0 {
        gen double fl_loss_incr_`y' = fl_loss_cum_`y' if sample_ok_fl & !missing(`baseline_var')
    }
    else {
        local bprev : word `= `h'' of `betas_fl'
        gen double fl_loss_incr_`y' = `baseline_var'*(exp(`b'/100) - exp(`bprev'/100)) ///
            if sample_ok_fl & !missing(`baseline_var')
    }
    label var fl_loss_incr_`y' "Flood: incremental loss (mn €), `y'"

    * Zero-fill outside exposure so sums work
    replace fl_loss_cum_`y'  = 0 if missing(fl_loss_cum_`y')
    replace fl_loss_incr_`y' = 0 if missing(fl_loss_incr_`y')

    * Regional % of own baseline (cumulative)
    capture drop fl_pct_region_`y'
    gen double fl_pct_region_`y' = cond(`baseline_var'>0, 100*fl_loss_cum_`y'/`baseline_var', .)

    format fl_loss_cum_`y' fl_loss_incr_`y' %12.2fc
    format fl_cum_pct_`y' fl_pct_region_`y' %9.3f
}

* Preview & export regional table (exposed only)
order Territory_ID Country_ID name_latn GVA_2024 ///
      fl_loss_cum_2025 fl_loss_cum_2026 fl_loss_cum_2027 fl_loss_cum_2028 fl_loss_cum_2029 ///
      fl_loss_incr_2025 fl_loss_incr_2026 fl_loss_incr_2027 fl_loss_incr_2028 fl_loss_incr_2029
br Territory_ID Country_ID name_latn GVA_2024 fl_loss_cum_* fl_loss_incr_* if sample_ok_fl==1

preserve
    keep if sample_ok_fl==1
    keep Territory_ID Country_ID name_latn GVA_2024 fl_loss_cum_* fl_loss_incr_* fl_pct_region_*
    export excel using "floods2025.xlsx", sheet("Sheet1") firstrow(variables) replace
restore


*===========================*
* NUTS1 aggregates (2025–`endyear')
*===========================*

 gen double nuts1_baseline_2024 = GVA_2024_nuts1
* Exposed baseline per NUTS1 (sum over exposed regions)
gen double fl_exposed_base_n1_2024 = GVA_2024 if sample_ok_fl==1
bys nuts1_ID: egen double fl_nuts1_exposed_base_2024 = total(fl_exposed_base_n1_2024)

preserve
    * Sum losses by NUTS1
    collapse (sum) fl_loss_cum_* fl_loss_incr_* ///
             (firstnm) nuts1_baseline_2024 fl_nuts1_exposed_base_2024 nuts1_name, by(nuts1_ID)

    * Keep only NUTS1 units actually exposed
    keep if fl_nuts1_exposed_base_2024 > 0

    * % metrics: relative to NUTS1 total baseline and exposed baseline
    forvalues y = `startyear'/`endyear' {
        gen double fl_pct_nuts1_`y'        = 100*fl_loss_cum_`y'/nuts1_baseline_2024
        gen double fl_pct_exposed_nuts1_`y' = 100*fl_loss_cum_`y'/fl_nuts1_exposed_base_2024
    }
    gen double fl_exposed_share_nuts1_2024 = 100*fl_nuts1_exposed_base_2024/nuts1_baseline_2024

    * Labels & formatting
    label var nuts1_baseline_2024             "NUTS1 baseline GVA 2024 (mn €)"
    label var fl_nuts1_exposed_base_2024      "flood-exposed baseline 2024 (mn €)"
    label var fl_exposed_share_nuts1_2024     "Exposed share of baseline (%)"
    format fl_loss_cum_* fl_loss_incr_* %12.2fc
    format fl_pct_nuts1_* fl_pct_exposed_nuts1_* fl_exposed_share_nuts1_2024 %9.3f

    * Preview
    list nuts1_ID nuts1_name nuts1_baseline_2024 fl_nuts1_exposed_base_2024 fl_exposed_share_nuts1_2024 ///
         fl_loss_cum_* fl_loss_incr_* fl_pct_nuts1_* fl_pct_exposed_nuts1_*, noobs
    keep nuts1_ID nuts1_name nuts1_baseline_2024 fl_nuts1_exposed_base_2024 ///
         fl_loss_cum_* fl_loss_incr_* fl_pct_nuts1_* fl_pct_exposed_nuts1_*
    order nuts1_ID nuts1_name nuts1_baseline_2024 fl_nuts1_exposed_base_2024 ///
         fl_loss_cum_* fl_loss_incr_* fl_pct_nuts1_*
    export excel using "flood2025_nuts1.xlsx", sheet("Sheet1") firstrow(variables) replace
restore


*---------------------------*
* Country aggregates (2025–`endyear')
*---------------------------*

* Country baseline (sum over all regions, 2024)
bys Country_ID: egen double country_baseline_2024 = total(`baseline_var')

* Exposed baseline per country (sum over exposed regions)
gen double fl_exposed_base_2024 = `baseline_var' if sample_ok_fl==1
bys Country_ID: egen double fl_country_exposed_base_2024 = total(fl_exposed_base_2024)

preserve
    collapse (sum) fl_loss_cum_* fl_loss_incr_* ///
             (firstnm) country_baseline_2024 fl_country_exposed_base_2024, by(Country_ID)

    * Keep only countries actually exposed
    keep if fl_country_exposed_base_2024 > 0

    * % of total country baseline and % of exposed baseline
    forvalues y = `startyear'/`endyear' {
        gen double fl_pct_country_`y' = 100*fl_loss_cum_`y'/country_baseline_2024
        gen double fl_pct_exposed_`y' = 100*fl_loss_cum_`y'/fl_country_exposed_base_2024
    }
    gen double fl_exposed_share_2024 = 100*fl_country_exposed_base_2024 / country_baseline_2024

    * Show & export
    list Country_ID country_baseline_2024 fl_country_exposed_base_2024 fl_exposed_share_2024 ///
         fl_loss_cum_* fl_loss_incr_* fl_pct_country_* fl_pct_exposed_*, noobs

    keep Country_ID country_baseline_2024 fl_country_exposed_base_2024 fl_exposed_share_2024 ///
         fl_loss_cum_* fl_loss_incr_* fl_pct_country_* fl_pct_exposed_*

    order Country_ID country_baseline_2024 fl_country_exposed_base_2024 ///
          fl_loss_cum_* fl_loss_incr_* fl_pct_country_*
    export excel using "floods2025_country.xlsx", sheet("Sheet1") firstrow(variables) replace
restore

*---------------------------*
* Europe aggregates (2025–`endyear')
*---------------------------*

* EU total baseline (mn €)
scalar EU_GVA_2024 = 16127680.72

preserve
    keep if sample_ok_fl==1
    collapse (sum) fl_loss_cum_* fl_loss_incr_* (sum) `baseline_var', fast
    rename `baseline_var' EU_exposed_base_2024

    * % of EU total baseline and % of EU exposed baseline
    forvalues y = `startyear'/`endyear' {
        gen double EU_fl_pct_total_`y'   = 100*fl_loss_cum_`y'/EU_GVA_2024
        gen double EU_fl_pct_exposed_`y' = 100*fl_loss_cum_`y'/EU_exposed_base_2024
    }

    * Display & export
    list EU_exposed_base_2024 fl_loss_cum_* fl_loss_incr_* EU_fl_pct_total_* EU_fl_pct_exposed_*, noobs

    keep EU_exposed_base_2024 fl_loss_cum_* fl_loss_incr_* EU_fl_pct_total_* EU_fl_pct_exposed_*
    order EU_exposed_base_2024 fl_loss_cum_* fl_loss_incr_* EU_fl_pct_total_*
    export excel using "floods2025_europe.xlsx", sheet("Sheet1") firstrow(variables) replace
restore



*---------------------------*
* Eurozone aggregates (2025–`endyear')
*---------------------------*

* Eurozone total baseline (mn €)
scalar Eurozone_GVA_2024 = 13638343
preserve
    * Keep only Eurozone & exposed to floods
    keep if eurozone==1 & sample_ok_fl==1

    * Collapse to Eurozone totals
    collapse (sum) fl_loss_cum_* fl_loss_incr_* (sum) `baseline_var', fast
    rename `baseline_var' EZ_exposed_base_2024

    * Eurozone total baseline (mn €)
    scalar Eurozone_GVA_2024 = 13638343   // <-- replace with your correct number

    * Percent metrics
    forvalues y = `startyear'/`endyear' {
        gen double EZ_fl_pct_total_`y'   = 100*fl_loss_cum_`y'/Eurozone_GVA_2024
        gen double EZ_fl_pct_exposed_`y' = 100*fl_loss_cum_`y'/EZ_exposed_base_2024
    }

    * Display & export
    list EZ_exposed_base_2024 fl_loss_cum_* fl_loss_incr_* EZ_fl_pct_total_* EZ_fl_pct_exposed_*, noobs

    keep EZ_exposed_base_2024 fl_loss_cum_* fl_loss_incr_* EZ_fl_pct_total_* EZ_fl_pct_exposed_*
    order EZ_exposed_base_2024 fl_loss_cum_* fl_loss_incr_* EZ_fl_pct_total_*
    export excel using "floods2025_eurozone.xlsx", sheet("Sheet1") firstrow(variables) replace
restore
