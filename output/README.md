# Output losses — summer 2026

Replication package for the output-loss (GVA) estimates in:

Sehrish Usman, Guzmán González-Torres Fernández, Maximilian Kotz, Friderike Kuik,
Eliza Lis, Christiane Nickel, Miles Parker, Mathilde Vallat, "European summer
weather extremes lowered economic output and raised food prices" (2026).

The flood, drought and heatwave impact coefficients used here are taken from a
companion paper and are not re-estimated:

Sehrish Usman, Guzmán González-Torres Fernández, Miles Parker, "Going NUTS: The
regional impact of extreme climate events over the medium term", *European
Economic Review*, 2025, 105081, https://doi.org/10.1016/j.euroecorev.2025.105081

Replication package for that paper: https://github.com/MilesIParker/GoingNUTS

The price and inflation material is in [`../inflation/`](../inflation/).

## How to run

Download this repository, unzip it anywhere, then in Stata:

```
cd "<wherever you unzipped it>/output"
do 00_run_all_2026.do
```

No path needs to be edited. Each script takes its root from the current
directory, and all output is written to `output_2026/`.

## Input files

```
output_2026/ready_analysis_2026.dta   analysis-ready dataset used by steps 02-04
output_2026/event_data_2026.dta       NUTS3 event classification for summer 2026
```

Both are provided, so the estimation steps run without any further download.
Regional GVA (2025) and population (2026) are pulled live from the European
Commission's ARDECO database, version 2024, inside step 01.

The NUTS3 climate panel that step 01 reads, `nuts3_climate_full_1990_onward.csv`,
is 278 MB and is not distributed here. It is derived from the ERA5 reanalysis,
available from the Copernicus Climate Data Store.

## Step 1 — data preparation (optional)

`ready_analysis_2026.dta` is provided, so this step is not required. It is
included so users can verify that the preparation reproduces the file supplied.

`01_data_preparation_2026.do` classifies every NUTS3 region by the extreme
weather it experienced in summer 2026 — heatwave (summer mean more than 2 °C
above the 1991-2020 climatology), flood (SPI ≥ 2 on 3-day maximum precipitation),
drought (3-month SPI ≤ −1.5) — merges in ARDECO GVA and population, and writes
`ready_analysis_2026.dta`. Event definitions follow Usman et al. (2025).

The step is skipped automatically unless you set `$rawdata` at the top of
`00_run_all_2026.do` to the folder holding the climate CSV.

## Step 2 — impact estimation

These three scripts project the cost of each hazard over 2026-2030 by applying
the LP-DiD cumulative impact coefficients (β_h, h = 0..4) of Usman,
González-Torres Fernández & Parker (2025) to the regions exposed in summer 2026:

- `02_flood_impact_estimation_2026.do` — floods
- `03_drought_impact_estimation_2026.do` — droughts; regions hit by both a
  drought and a heatwave count as drought-affected, flood regions are excluded
- `04_heatwave_impact_estimation_2026.do` — heatwaves, with coefficients applied
  separately by regional climate type (cold, temperate, hot)

Each reads `ready_analysis_2026.dta` and exports Excel tables of cumulative
losses by horizon at NUTS3, NUTS2, NUTS1, country, EU27 and euro-area level, in
mn € and as a share of 2025 baseline GVA, with 90% confidence intervals.

## Step 3 — figure

`make_figure2_2026.py` writes `output_2026/fig_gva_shares_2026.csv`, the source
data for Figure 2, and draws the figure as published. Needs Python with pandas,
openpyxl and matplotlib.

The map in Figure 1 is drawn from `event_data_2026.dta` with Eurostat GISCO NUTS
2021 geometry; that plotting code is not part of this package.

## Required Stata packages

```
ssc install tsspell
```

`pickyear.ado`, included here, is added to the ado-path by step 01. It selects an
ARDECO column by its year label rather than its position, which is not stable
across database vintages.

## Authors

Sehrish Usman (University of Mannheim), Guzmán González-Torres Fernández (Banca
d'Italia), Maximilian Kotz (Barcelona Supercomputing Center; Potsdam Institute
for Climate Impact Research; University of Queensland), Friderike Kuik, Eliza
Lis, Christiane Nickel, Miles Parker (European Central Bank) and Mathilde Vallat
(Paris School of Economics).

Correspondence: Sehrish Usman, Sehrish.Usman@uni-mannheim.de

The views expressed here are those of the authors and do not necessarily
represent those of the Banca d'Italia, the European Central Bank or its
Governing Council.
