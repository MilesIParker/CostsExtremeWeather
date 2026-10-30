/*==============================================================================
01_data_preparation_2026.do

Classifies every NUTS3 region by the extreme weather it experienced in summer
2026 and builds the analysis baseline. Heatwave: summer mean more than 2 C above
the 1991-2020 climatology. Flood: SPI >= 2 on 3-day maximum precipitation.
Drought: 3-month SPI <= -1.5. Regional GVA (2025) and population (2026) come
from the ARDECO API, version 2024.

Reads:    $rawdata/nuts3_climate_full_1990_onward.csv   (ERA5-derived panel,
          not distributed with this package; see the README)
          ARDECO series SUVGE and SNPTD, downloaded over the network
Writes:   output_2026/event_data_2026.dta      region-level event flags
          output_2026/ready_analysis_2026.dta  input to scripts 02-04
          output_2026/{GVA_country,pop_nuts2,nuts1_country,nuts2_country}.dta

Requires: pickyear.ado (in this folder), which selects an ARDECO column by its
          year label rather than its position; tsspell.

This script is skipped by 00_run_all_2026.do unless $rawdata is set. Steps 02-04
run from the supplied ready_analysis_2026.dta and reproduce every published
estimate without it.
==============================================================================*/

**************** Prepare the Data

********************** Set the path
if "$root" == "" global root "`c(pwd)'"
* all output goes to output_2026
global out "$root/output_2026"
capture mkdir "$out"
cd "$out"

* pickyear.ado (in this folder) selects an ARDECO column by its year header
* rather than its position: column order is not stable across vintages.
* Added to the adopath so it survives -clear all-.
adopath ++ "$root"

********************** Import the Data from raw_files folder and merge using combine.ado file 
clear all

import delimited "$rawdata/nuts3_climate_full_1990_onward.csv", clear

********************** Define the global variables 

global year year 
global date date 
global date date
global country country_long
global Country_ID Country_ID
global Territory_ID Territory_ID

********************** Rename variables according to the previous code 
rename cntr_code ${Country_ID}
rename nuts_id ${Territory_ID} // for merging 

* Keep EU27 sample 
*  "AT" "BE" "BG" "HR" "CY" "CZ" "DK" "EE" "FI" "FR" "DE" "EL" "HU" "IE" "IT" "LV" "LT" "LU" "MT"  "NL"  "PL" "PT" "RO" "SK" "SI"  "ES" "SE" 
*** drop non-EU27 Countries 
drop if ${Country_ID} == "CH" 
drop if ${Country_ID} ==  "IS" 
drop if ${Country_ID} ==  "ME"
drop if ${Country_ID} == "NO" 
drop if ${Country_ID} == "TR" 
drop if ${Country_ID} == "UK" 
drop if ${Country_ID} == "RS"
drop if ${Country_ID} == "AL"
drop if ${Country_ID} == "MK"
drop if ${Country_ID} == "LI"


* Formating the Date variable 
gen double date = .
replace date = date(time, "YMD") if strpos(time, "-")
replace date = date(time, "DMY") if strpos(time, "/")
format date %td
gen year = year(date)     // year
gen quarter= quarter(date) // calender quarter 
gen month = month(date) // month 

gen calenderyear = yq(year,quarter) // Time variable for our analysis 
format calenderyear %tq
sort ${Territory_ID} year quarter month // sorting based on calander year variables
gen int t_var = ym(year, month) // integer time variable for panel analysis 
format t_var %tm

* Drop missing data 
drop if pr_mean == . & t_mean == . // drop missing values 
* list Territory_ID if pr_mean ==. // check which territories drop out 

sort ${Territory_ID} month
* Redefine quarters based on Seasons
gen meteo_quarter = . // Seasonal quarters 
replace meteo_quarter  = 1 if month == 12 | month == 1 | month == 2  // winter 
replace meteo_quarter = 2 if month == 3 | month == 4 | month == 5   // spring 
replace meteo_quarter  = 3 if month == 6 | month == 7 | month == 8   // summers 

* Adjust the year for December data for meteorological year 
gen meteo_only_year = year 
replace meteo_only_year= year +1 if month == 12
gen meteoyear = yq(meteo_only_year,meteo_quarter)
format meteoyear %tq

***************** Defining the heatwaves 
bysort ${Country_ID} ${Territory_ID} meteo_only_year: egen annual_avg_temp_dev = mean(t_diff_1991_2020) // average annual temperature deviation from historical mean

* Generate long run mean (1991_2020) for meteorological year in each quarter 
egen aux = mean(t_mean) if meteo_only_year > 1990 & meteo_only_year < 2021 & meteo_only_year !=.  , by (${Territory_ID} meteo_quarter) 
egen meteor_avgtemp_quarter_hist1 = min(aux) , by (${Territory_ID} meteo_quarter) 
drop aux 


****************** Create weather dummies

gen winter = .
replace winter = 1 if meteo_quarter ==1
gen spring = .
replace spring = 1 if meteo_quarter ==2
gen summer = .
replace summer = 1 if meteo_quarter ==3

*** Hot/medium/cold regions terciles (1 "Cold" 2 "Medium" 3 "Hot")
xtile Baseline_climate=meteor_avgtemp_quarter_hist if summer ==1,n(3)
by Territory_ID, sort: fillmissing Baseline_climate, with(max) 

*********** keep only 2026

keep if year > 2025
sort ${Territory_ID} month
* Generate quarterly absolute temperature averages both for meteorological and calendar year 
egen temp_meteo_quarter = mean(t_mean), by (${Territory_ID} meteo_quarter) // seasonal average of abs temperature 

* Generate quarterly deviations from long run mean 
gen temp_meteo_quarter_dev = temp_meteo_quarter -  meteor_avgtemp_quarter_hist   // Quarterly deviations from historical mean based on seasons 




**** variables for heat shocks 


*Baseline 

gen  hotsummer_2C =. 
replace hotsummer_2C = 1 if  temp_meteo_quarter_dev >2 & summer==1 &  temp_meteo_quarter_dev!=.
replace hotsummer_2C = 1 if temp_meteo_quarter_dev == 2 & summer==1 & temp_meteo_quarter_dev!=.
replace hotsummer_2C = 0 if  temp_meteo_quarter_dev<2 & summer==1 &  temp_meteo_quarter_dev!=.

gen  hotwinter_2C =. 
replace hotwinter_2C = 1 if  temp_meteo_quarter_dev >2 & winter==1 &  temp_meteo_quarter_dev!=.
replace hotwinter_2C = 1 if temp_meteo_quarter_dev == 2 & winter==1 & temp_meteo_quarter_dev!=.
replace hotwinter_2C = 0 if  temp_meteo_quarter_dev<2 & winter==1 &  temp_meteo_quarter_dev!=.

gen  hotspring_2C =. 
replace hotspring_2C = 1 if  temp_meteo_quarter_dev >2 & spring==1 &  temp_meteo_quarter_dev!=.
replace hotspring_2C = 1 if temp_meteo_quarter_dev == 2 & spring==1 & temp_meteo_quarter_dev!=.
replace hotspring_2C = 0 if  temp_meteo_quarter_dev<2 & spring==1 &  temp_meteo_quarter_dev!=.

*Robustness check 1.75

gen  hotsummer_175C =. 
replace hotsummer_175C = 1 if  temp_meteo_quarter_dev >1.75 & summer==1 &  temp_meteo_quarter_dev!=.
replace hotsummer_175C = 1 if temp_meteo_quarter_dev == 1.75 & summer==1 & temp_meteo_quarter_dev!=.
replace hotsummer_175C = 0 if  temp_meteo_quarter_dev<1.75 & summer==1 &  temp_meteo_quarter_dev!=.


gen  hotwinter_175C =. 
replace hotwinter_175C = 1 if  temp_meteo_quarter_dev >1.75 & winter==1 &  temp_meteo_quarter_dev!=.
replace hotwinter_175C = 1 if temp_meteo_quarter_dev == 1.75 & winter==1 & temp_meteo_quarter_dev!=.
replace hotwinter_175C = 0 if  temp_meteo_quarter_dev<1.75 & winter==1 &  temp_meteo_quarter_dev!=.

gen  hotspring_175C =. 
replace hotspring_175C = 1 if  temp_meteo_quarter_dev >1.75 & spring==1 &  temp_meteo_quarter_dev!=.
replace hotspring_175C = 1 if temp_meteo_quarter_dev == 1.75 & spring==1 & temp_meteo_quarter_dev!=.
replace hotspring_175C = 0 if  temp_meteo_quarter_dev<1.75 & spring==1 &  temp_meteo_quarter_dev!=.


sort ${Territory_ID} month

******* Declare panel data
egen ID_var = group(Territory_ID)  // temporrarily for time set 
xtset ID_var t_var

******************* Estimate SPI index to predict hazard of floods 
/*
estimates parameters for SPI using data from 1995-2022


ML fit of two-parameter gamma distribution        Number of obs   =     456171
                                                  Wald chi2(0)    =          .
Log pseudolikelihood = -1867958.1                 Prob > chi2     =          .

                       (Std. err. adjusted for 1,152 clusters in Territory_ID)
------------------------------------------------------------------------------
             |               Robust
 pr_max_3day | Coefficient  std. err.      z    P>|z|     [95% conf. interval]
-------------+----------------------------------------------------------------
alpha        |
       _cons |   2.560321   .0607792    42.12   0.000     2.441195    2.679446
-------------+----------------------------------------------------------------
beta         |
       _cons |   10.47725   .2862008    36.61   0.000     9.916306    11.03819
------------------------------------------------------------------------------



*/


 *** Baseline metric (flood metric using three days maximum precipitation)
drop if pr_total == 0 // data cleaning

scalar alpha_hat = 2.560321
scalar beta_hat  = 10.47725
gen double Probability_3 = gammap(alpha_hat, pr_max_3day/beta_hat) if !missing(pr_max_3day)

gen SPI_3 = invnorm(Probability_3) // SPI Index using max three days precipitation using three days accumulation period 

gen hazard_max3days = .
replace hazard_max3days = 7 if  SPI_3 >= 2 // extreme wet
replace hazard_max3days = 6 if    inrange(SPI_3,1.5,1.999)  // very wet
replace hazard_max3days = 5 if     inrange(SPI_3,1.0,1.499)  // moderate wet
replace hazard_max3days = 4 if inrange(SPI_3,-0.999,0.999) // near normal
replace hazard_max3days = 3 if inrange(SPI_3,-1.499,-1.0) // moderate dryness 
replace hazard_max3days = 2 if inrange(SPI_3,-1.999,-1.5)  // severe dryness 
replace hazard_max3days = 1 if SPI_3 <=-2 // extreme dryness 
replace hazard_max3days = . if SPI_3 == .
g hazard_max3days_label= word("extremely_dry very_dry moderately_dry normal_precipitation moderately_wet very_wet extremely_wet", hazard_max3days)

gen flood_max3days = .
replace flood_max3days  = 1 if hazard_max3days == 7 
replace flood_max3days  = 0 if flood_max3days ==.


********************Define droughts

******************* Precipitation Anomalies to define droughts

*The parameters for estimated SPI Index with quarterly accumulation period is based on the data from 1995-2022

*keep if month == 1 | month == 4 | month == 7 // dataset is now quarterly data 

/*

ML fit of two-parameter gamma distribution        Number of obs   =     152054
                                                  Wald chi2(0)    =          .
Log pseudolikelihood = -737839.63                 Prob > chi2     =          .

                       (Std. err. adjusted for 1,152 clusters in Territory_ID)
------------------------------------------------------------------------------
             |               Robust
pr_accumul~d | Coefficient  std. err.      z    P>|z|     [95% conf. interval]
-------------+----------------------------------------------------------------
alpha        |
       _cons |   4.743892   .1547031    30.66   0.000     4.440679    5.047104
-------------+----------------------------------------------------------------
beta         |
       _cons |   15.32018    .522732    29.31   0.000     14.29565    16.34472
------------------------------------------------------------------------------

*/
egen pr_accumulated = mean(pr_total), by (${Territory_ID} quarter) // quarterly average of precipitation 
scalar alpha_hat =  4.743892
scalar beta_hat  =  15.32018
gen double Probability_drought = gammap(alpha_hat, pr_accumulated/beta_hat) if !missing(pr_accumulated)
gen SPI_drought = invnorm(Probability_drought) // SPI Index using average precipitaion using monthly accumulation period

** define hazard
******************* define SPI_drought index using accumulated precipitaion for 3 months
gen hazard_drought = .
replace hazard_drought = 7 if  SPI_drought >= 2 // extreme wet 
replace hazard_drought = 6 if    inrange(SPI_drought,1.5,1.999)  // very wet
replace hazard_drought = 5 if     inrange(SPI_drought,1.0,1.499)  // moderate wet
replace hazard_drought = 4 if inrange(SPI_drought,-0.999,0.999) // near normal
replace hazard_drought = 3 if inrange(SPI_drought,-1.499,-1.0) // moderate dryness 
replace hazard_drought = 2 if inrange(SPI_drought,-1.999,-1.5)  // severe dryness 
replace hazard_drought = 1 if SPI_drought <=-2 // extreme dryness 
replace hazard_drought = . if SPI_drought == .
g hazarddrought = word("extremely_dry very_dry moderately_dry normal_precipitation moderately_wet very_wet extremely_wet", hazard_drought)

gen indicator_rainfall = .
replace indicator_rainfall  = 1 if hazard_drought == 1 | hazard_drought == 2
replace indicator_rainfall  = 0 if hazard_drought > 2 // extreme dry conditions based on total monthly precipitation

keep if month == 6 | month == 7 | month == 8
**** for flood
tsset ID_var t_var
tsspell, pcond(flood_max3days) 
egen max  = max(_seq), by(ID_var)  
gen flood_event_max3days = .
replace flood_event_max3days = 1 if max > 0
replace flood_event_max3days = 0 if flood_event_max3days == . 

sort ${Territory_ID} t_var
drop _seq _spell _end max


*** for droughts

tsset ID_var t_var
* ssc install tsspell
tsspell, pcond(indicator_rainfall)    // generate sequence, number of spells and end of the spell
egen max  = max(indicator_rainfall), by(ID_var)    // maximum number if sequence of ones in a year 
gen drought_event = .
replace drought_event = 1 if max ==1
replace drought_event = 0 if drought_event == . & max == 0

drop max _end _spell _seq
sort ${Territory_ID} t_var

keep if month == 7 // select any quarter to convert it into annual data

keep time Territory_ID Country_ID name_latn t_mean  hotsummer_2C hotsummer_175C ID_var hazard_max3days_label flood_event_max3days drought_event Baseline_climate

save "event_data_2026", replace

**************** Population data 

*** nuts 2
clear all

global pathpop2 "https://territorial.ec.europa.eu/ardeco-api-v2/rest/export/SNPTD?versions=2024&unit=NR&level_id=2&format=csv-table"

import delimited "$pathpop2", clear
rename territory_id nuts2_ID
* population for the event year
pickyear 2026 pop_2026_nuts2
keep nuts2_ID pop_2026_nuts2

save "pop_nuts2", replace



************* GVA DATA Country level 

clear all

global path1 "https://territorial.ec.europa.eu/ardeco-api-v2/rest/export/SUVGE?versions=2024&unit=MIO_EUR&level_id=0&format=csv-table"
import delimited "$path1", clear
rename territory_id Country_ID
rename name_html Country_name
* select the 2025 column by its year label, not its position
pickyear 2025 GVA_2025_Country
keep Country_ID Country_name GVA_2025_Country

drop if ${Country_ID} == "CH" 
drop if ${Country_ID} ==  "IS" 
drop if ${Country_ID} ==  "ME"
drop if ${Country_ID} == "NO" 
drop if ${Country_ID} == "TR" 
drop if ${Country_ID} == "UK" 
drop if ${Country_ID} == "RS"
drop if ${Country_ID} == "AL"
drop if ${Country_ID} == "MK"
drop if ${Country_ID} == "LI"

save "GVA_country", replace

*********** GVA Data NUTS LEVEL 1


clear all

global path2 "https://territorial.ec.europa.eu/ardeco-api-v2/rest/export/SUVGE?versions=2024&unit=MIO_EUR&level_id=1&format=csv-table"
import delimited "$path2", clear
rename territory_id nuts1_ID
rename name_html nuts1_name
* select the 2025 column by its year label, not its position
pickyear 2025 GVA_2025_nuts1


* Make a 2-letter country code from Territory_ID 
gen str2 Country_ID = substr(nuts1_ID, 1, 2) if !missing(nuts1_ID) & length(nuts1_ID)>=2
replace Country_ID = upper(Country_ID)

keep Country_ID nuts1_ID nuts1_name GVA_2025_nuts1

drop if ${Country_ID} == "CH" 
drop if ${Country_ID} ==  "IS" 
drop if ${Country_ID} ==  "ME"
drop if ${Country_ID} == "NO" 
drop if ${Country_ID} == "TR" 
drop if ${Country_ID} == "UK" 
drop if ${Country_ID} == "RS"
drop if ${Country_ID} == "AL"
drop if ${Country_ID} == "MK"
drop if ${Country_ID} == "LI"

save "nuts1_country", replace

*********** GVA Data NUTS LEVEL 2


clear all

global path3 "https://territorial.ec.europa.eu/ardeco-api-v2/rest/export/SUVGE?versions=2024&unit=MIO_EUR&level_id=2&format=csv-table"

import delimited "$path3", clear
rename territory_id nuts2_ID
rename name_html nuts2_name
* select the 2025 column by its year label, not its position
pickyear 2025 GVA_2025_nuts2


* Make a 2-letter country code from Territory_ID 
gen str2 Country_ID = substr(nuts2_ID, 1, 2) if !missing(nuts2_ID) & length(nuts2_ID)>=2
replace Country_ID = upper(Country_ID)

keep Country_ID nuts2_ID nuts2_name GVA_2025_nuts2

drop if ${Country_ID} == "CH" 
drop if ${Country_ID} ==  "IS" 
drop if ${Country_ID} ==  "ME"
drop if ${Country_ID} == "NO" 
drop if ${Country_ID} == "TR" 
drop if ${Country_ID} == "UK" 
drop if ${Country_ID} == "RS"
drop if ${Country_ID} == "AL"
drop if ${Country_ID} == "MK"
drop if ${Country_ID} == "LI"

save "nuts2_country", replace

***********************************************

global path "https://territorial.ec.europa.eu/ardeco-api-v2/rest/export/SUVGE?versions=2024&unit=MIO_EUR&level_id=3&format=csv-table"
import delimited "$path", clear

rename territory_id Territory_ID
* select the 2025 column by its year label, not its position
pickyear 2025 GVA_2025

* Make a 2-letter country code from Territory_ID 
gen str2 Country_ID = substr(Territory_ID, 1, 2) if !missing(Territory_ID) & length(Territory_ID)>=2
replace Country_ID = upper(Country_ID)

drop if ${Country_ID} == "CH" 
drop if ${Country_ID} ==  "IS" 
drop if ${Country_ID} ==  "ME"
drop if ${Country_ID} == "NO" 
drop if ${Country_ID} == "TR" 
drop if ${Country_ID} == "UK" 
drop if ${Country_ID} == "RS"
drop if ${Country_ID} == "AL"
drop if ${Country_ID} == "MK"
drop if ${Country_ID} == "LI"


keep Territory_ID Country_ID GVA_2025
merge m:1 Country_ID using  "GVA_country"
drop _merge

* Make a 2-letter nuts1 code from Territory_ID 
gen nuts1_ID = substr(Territory_ID, 1, 3)
merge m:1 nuts1_ID using  "nuts1_country"
drop _merge

* Make a 2-letter nuts2 code from Territory_ID 
gen nuts2_ID = substr(Territory_ID, 1, 4)
merge m:1 nuts2_ID using  "nuts2_country"
drop _merge

merge m:1 nuts2_ID using "pop_nuts2"
keep if _merge ==3
drop _merge

merge 1:1 Territory_ID using  "event_data_2026"
keep if _merge ==3
drop time 
drop _merge 


* 1. Define Eurozone countries
* the euro area has 21 members: Bulgaria joined on 1 January 2026
local eurozone "AT BE BG CY DE EE EL ES FI FR HR IE IT LT LU LV MT NL PT SI SK"

* Generate indicator for Eurozone membership
gen byte eurozone = 0
foreach c of local eurozone {
    replace eurozone = 1 if Country_ID == "`c'"
}

* 2. Collapse to country level first (avoid double counting across regions)
preserve
collapse (firstnm) GVA_2025_Country, by(Country_ID eurozone)

* 3. Sum Eurozone baseline (in million €)
egen Euro_GVA_2025 = total(GVA_2025_Country) if eurozone==1
scalar Euro_GVA_2025 = Euro_GVA_2025[1]

display "Eurozone baseline GVA 2025 (mn EUR) = " Euro_GVA_2025
restore

order Territory_ID Country_ID Country_name name_latn nuts1_ID nuts1_name ID_var  t_mean  hotsummer_175C hotsummer_2C flood_event_max3days hazard_max3days_label drought_event GVA_2025 GVA_2025_Country GVA_2025_nuts1 Baseline_climate eurozone nuts2_ID nuts2_name GVA_2025_nuts2 pop_2026_nuts2

* EU27 and euro-area GVA totals (2025) are computed from the data and stored
* as constants, so scripts 02-04 need no hard-coded scalars
preserve
    use "GVA_country", clear
    quietly count
    assert r(N) == 27
    gen byte ez = inlist(Country_ID,"AT","BE","BG","CY","DE","EE","EL","ES","FI") | ///
                  inlist(Country_ID,"FR","HR","IE","IT","LT","LU","LV","MT","NL") | ///
                  inlist(Country_ID,"PT","SI","SK")
    quietly summarize GVA_2025_Country
    scalar EU27_tot = r(sum)
    quietly summarize GVA_2025_Country if ez
    scalar EZ_tot = r(sum)
restore
gen double EU27_GVA_2025 = scalar(EU27_tot)
gen double EZ_GVA_2025   = scalar(EZ_tot)
display "EU27 GVA 2025 (mn EUR)            = " %15.1fc EU27_GVA_2025[1]
display "Euro area (21) GVA 2025 (mn EUR)  = " %15.1fc EZ_GVA_2025[1]

save  "ready_analysis_2026", replace
