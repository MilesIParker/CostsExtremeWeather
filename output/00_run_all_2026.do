/*==============================================================================
Summer 2026 update of "Dry-roasted NUTS" -- run the full pipeline.

HOW TO RUN
  1. Download this repository and unzip it anywhere.
  2. In Stata:  cd "<...>/output"      (the folder holding this do-file)
  3.            do 00_run_all_2026.do

  No path needs to be edited: $root is taken from the current directory.
  All results are written to output_2026\.

  Step 01 rebuilds the inputs from the raw ERA5 climate panel, which is far too
  large to distribute here (278 MB; see the README for the Copernicus source).
  If you have it, set $rawdata below to the folder that holds it and step 01
  will run. Otherwise it is skipped automatically and steps 02-04 run from the
  supplied output_2026/ready_analysis_2026.dta, reproducing every published
  estimate.

Requires: tsspell (ssc install tsspell).
==============================================================================*/

version 18

global root "`c(pwd)'"

* Folder holding nuts3_climate_full_1990_onward.csv; leave empty to skip step 01.
global rawdata ""

capture confirm file "$rawdata/nuts3_climate_full_1990_onward.csv"
if _rc == 0 {
    do "$root/01_data_preparation_2026.do"
}
else {
    display as text "{hline}"
    display as text "Step 01 skipped: raw ERA5 panel not found."
    display as text "Steps 02-04 will run from the supplied ready_analysis_2026.dta."
    display as text "{hline}"
}

do "$root/02_flood_impact_estimation_2026.do"
do "$root/03_drought_impact_estimation_2026.do"
do "$root/04_heatwave_impact_estimation_2026.do"
