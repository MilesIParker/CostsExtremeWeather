/*==============================================================================
02_flood_impact_estimation_2026.do

Projects the GVA cost of flood exposure over 2026-2030, applying LP-DiD
cumulative impact coefficients (beta_h, h = 0..4) to the NUTS3 regions
classified as flood-exposed in summer 2026, with 90% confidence intervals.
Losses are reported in mn EUR and as a share of 2025 baseline GVA.

Reads:    output_2026/ready_analysis_2026.dta
Writes:   output_2026/floods2026_{nuts3,country,europe,eurozone}_CI.xlsx
          output_2026/flood2026_{nuts1,nuts2}_CI.xlsx

Coefficients are taken from, not re-estimated in, this script:
  Usman, S., Gonzalez-Torres Fernandez, G., & Parker, M. (2025). "Going NUTS:
  The regional impact of extreme climate events over the medium term."
  European Economic Review. https://doi.org/10.1016/j.euroecorev.2025.105081
  Estimation code: https://github.com/MilesIParker/GoingNUTS
==============================================================================*/

version 18
clear all
set more off

if "$root" == "" global root "`c(pwd)'"
cd "$root\output_2026"
use "ready_analysis_2026", clear

*******************************************************
* FLOODS -- REGIONAL, NUTS1, NUTS2, COUNTRY, EU AGGREGATES (baseline=2025)
*******************************************************

* LP-DiD cumulative coefficients (log points = 100*ln) and SEs, h = 0..4
local betas -0.902  -1.858  -2.968  -3.050  -2.824
local ses   0.308   0.477   0.871   0.883   0.970
local z     1.645                  // 90% CI

local startyear 2026
local base      GVA_2025
local H = wordcount("`betas'") - 1
local endyear = `startyear' + `H'

* Exposure: all flood-exposed regions
capture drop sample_ok_fl
gen byte sample_ok_fl = (flood_event_max3days==1)
quietly count if sample_ok_fl==1
display as result "Flood-exposed NUTS3 regions in summer 2026: " r(N)

*---------------------------*
* Regional losses (mn EUR)
*---------------------------*
local cum  ""
local lo   ""
local hi   ""
local incr ""
local pct  ""
local lo3  ""
local hi3  ""
forvalues h = 0/`H' {
    local y = `startyear' + `h'
    local b : word `=`h'+1' of `betas'
    local s : word `=`h'+1' of `ses'

    gen double fl_cum_pct_`y'  = 100*(exp(`b'/100)-1)                if sample_ok_fl & !missing(`base')
    gen double fl_loss_cum_`y' = `base'*(exp(`b'/100)-1)             if sample_ok_fl & !missing(`base')
    gen double fl_lo_`y'       = `base'*(exp((`b'-`z'*`s')/100)-1)   if sample_ok_fl & !missing(`base')
    gen double fl_hi_`y'       = `base'*(exp((`b'+`z'*`s')/100)-1)   if sample_ok_fl & !missing(`base')
    if `h'==0 {
        gen double fl_loss_incr_`y' = fl_loss_cum_`y'
    }
    else {
        local bp : word `h' of `betas'
        gen double fl_loss_incr_`y' = `base'*(exp(`b'/100)-exp(`bp'/100)) if sample_ok_fl & !missing(`base')
    }
    foreach v in fl_loss_cum_`y' fl_lo_`y' fl_hi_`y' fl_loss_incr_`y' {
        replace `v' = 0 if missing(`v')
    }
    format fl_loss_cum_`y' fl_lo_`y' fl_hi_`y' fl_loss_incr_`y' %12.2fc
    format fl_cum_pct_`y' %9.3f

    local cum  "`cum' fl_loss_cum_`y'"
    local lo   "`lo' fl_lo_`y'"
    local hi   "`hi' fl_hi_`y'"
    local incr "`incr' fl_loss_incr_`y'"
    local pct  "`pct' fl_cum_pct_`y'"
    local lo3  "`lo3' fl_loss_lo_`y'"
    local hi3  "`hi3' fl_loss_hi_`y'"
}

preserve
    keep if sample_ok_fl==1
    forvalues y = `startyear'/`endyear' {
        rename fl_lo_`y' fl_loss_lo_`y'
        rename fl_hi_`y' fl_loss_hi_`y'
    }
    keep  Territory_ID Country_ID name_latn `base' `cum' `lo3' `hi3' `incr' `pct'
    order Territory_ID Country_ID name_latn `base' `cum' `lo3' `hi3' `incr' `pct'
    export excel using "floods2026_nuts3_CI.xlsx", sheet("Sheet1") firstrow(variables) replace
restore

*===========================*
* NUTS1 and NUTS2 aggregates
*===========================*
foreach L in 1 2 {
    capture drop nuts`L'_baseline_2025 fl_exp_n`L' fl_nuts`L'_exposed_base_2025
    gen double nuts`L'_baseline_2025 = GVA_2025_nuts`L'
    gen double fl_exp_n`L' = `base' if sample_ok_fl==1
    bys nuts`L'_ID: egen double fl_nuts`L'_exposed_base_2025 = total(fl_exp_n`L')

    local extra ""
    if `L'==2 local extra "pop_2026_nuts2"

    preserve
        collapse (sum) `cum' `lo' `hi' `incr' ///
                 (firstnm) nuts`L'_baseline_2025 fl_nuts`L'_exposed_base_2025 nuts`L'_name `extra', by(nuts`L'_ID)
        keep if fl_nuts`L'_exposed_base_2025 > 0

        local loL ""
        local hiL ""
        local pL  ""
        local peL ""
        forvalues y = `startyear'/`endyear' {
            rename fl_lo_`y' fl_n`L'_loss_cum_lo_`y'
            rename fl_hi_`y' fl_n`L'_loss_cum_hi_`y'
            gen double fl_pct_nuts`L'_`y'         = 100*fl_loss_cum_`y'/nuts`L'_baseline_2025
            gen double fl_pct_exposed_nuts`L'_`y' = 100*fl_loss_cum_`y'/fl_nuts`L'_exposed_base_2025
            local loL "`loL' fl_n`L'_loss_cum_lo_`y'"
            local hiL "`hiL' fl_n`L'_loss_cum_hi_`y'"
            local pL  "`pL' fl_pct_nuts`L'_`y'"
            local peL "`peL' fl_pct_exposed_nuts`L'_`y'"
        }
        label var nuts`L'_baseline_2025           "NUTS`L' baseline GVA 2025 (mn EUR)"
        label var fl_nuts`L'_exposed_base_2025   "Flood-exposed baseline 2025 (mn EUR)"

        local id "nuts`L'_ID nuts`L'_name `extra' nuts`L'_baseline_2025 fl_nuts`L'_exposed_base_2025"
        keep  `id' `cum' `loL' `hiL' `incr' `pL' `peL'
        order `id' `cum' `loL' `hiL' `incr' `pL' `peL'
        if `L'==1 export excel using "flood2026_nuts1_CI.xlsx", sheet("Sheet1") firstrow(variables) replace
        if `L'==2 export excel using "flood2026_nuts2_CI.xlsx", sheet("Sheet1") firstrow(variables) replace
    restore
}

*---------------------------*
* Country aggregates
*---------------------------*
capture drop country_baseline_2025 fl_exp_c fl_country_exposed_base_2025
gen double country_baseline_2025 = GVA_2025_Country
gen double fl_exp_c = `base' if sample_ok_fl==1
bys Country_ID: egen double fl_country_exposed_base_2025 = total(fl_exp_c)

preserve
    collapse (sum) `cum' `lo' `hi' `incr' ///
             (firstnm) country_baseline_2025 fl_country_exposed_base_2025, by(Country_ID)
    keep if fl_country_exposed_base_2025 > 0
    local loC ""
    local hiC ""
    local pC  ""
    local peC ""
    forvalues y = `startyear'/`endyear' {
        rename fl_lo_`y' fl_cty_loss_cum_lo_`y'
        rename fl_hi_`y' fl_cty_loss_cum_hi_`y'
        gen double fl_pct_country_`y' = 100*fl_loss_cum_`y'/country_baseline_2025
        gen double fl_pct_exposed_`y' = 100*fl_loss_cum_`y'/fl_country_exposed_base_2025
        local loC "`loC' fl_cty_loss_cum_lo_`y'"
        local hiC "`hiC' fl_cty_loss_cum_hi_`y'"
        local pC  "`pC' fl_pct_country_`y'"
        local peC "`peC' fl_pct_exposed_`y'"
    }
    gen double fl_exposed_share_2025 = 100*fl_country_exposed_base_2025/country_baseline_2025
    local id "Country_ID country_baseline_2025 fl_country_exposed_base_2025 fl_exposed_share_2025"
    keep  `id' `cum' `loC' `hiC' `incr' `pC' `peC'
    order `id' `cum' `loC' `hiC' `incr' `pC' `peC'
    export excel using "floods2026_country_CI.xlsx", sheet("Sheet1") firstrow(variables) replace
restore

*---------------------------*
* EU27 and euro-area aggregates
*---------------------------*
scalar EU_GVA_2025 = EU27_GVA_2025[1]
scalar EZ_GVA_2025s = EZ_GVA_2025[1]

foreach area in EU EZ {
    if "`area'"=="EU" local cond "sample_ok_fl==1"
    if "`area'"=="EZ" local cond "sample_ok_fl==1 & eurozone==1"
    if "`area'"=="EU" local tot = scalar(EU_GVA_2025)
    if "`area'"=="EZ" local tot = scalar(EZ_GVA_2025s)

    quietly count if `cond'
    if r(N)==0 {
        display as text "`area': no flood-exposed regions"
        continue
    }
    preserve
        keep if `cond'
        collapse (sum) `cum' `lo' `hi' `incr' `base', fast
        rename `base' `area'_exposed_base_2025
        local pT ""
        local pE ""
        local loA ""
        local hiA ""
        forvalues y = `startyear'/`endyear' {
            rename fl_lo_`y' fl_loss_cum_lo_`y'
            rename fl_hi_`y' fl_loss_cum_hi_`y'
            gen double `area'_fl_pct_total_`y'   = 100*fl_loss_cum_`y'/`tot'
            gen double `area'_fl_pct_exposed_`y' = 100*fl_loss_cum_`y'/`area'_exposed_base_2025
            local loA "`loA' fl_loss_cum_lo_`y'"
            local hiA "`hiA' fl_loss_cum_hi_`y'"
            local pT  "`pT' `area'_fl_pct_total_`y'"
            local pE  "`pE' `area'_fl_pct_exposed_`y'"
        }
        gen double `area'_total_GVA_2025 = `tot'
        display as result "`area' flood: cum loss " %12.1fc fl_loss_cum_`startyear' " (`startyear')  " ///
                %12.1fc fl_loss_cum_`endyear' " (`endyear') mn EUR"
        keep  `area'_total_GVA_2025 `area'_exposed_base_2025 `cum' `loA' `hiA' `incr' `pT' `pE'
        order `area'_total_GVA_2025 `area'_exposed_base_2025 `cum' `loA' `hiA' `incr' `pT' `pE'
        if "`area'"=="EU" export excel using "floods2026_europe_CI.xlsx", sheet("Sheet1") firstrow(variables) replace
        if "`area'"=="EZ" export excel using "floods2026_eurozone_CI.xlsx", sheet("Sheet1") firstrow(variables) replace
    restore
}
