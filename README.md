# CostsExtremeWeather
Replication package for "Estimating the Costs of Extreme Weather in Real Time"

This repository includes replication codes for the paper:

Sehrish Usman, Guzmán González-Torres Fernández, Maximilian Kotz, Friderike Kuik, Eliza Lis, Christiane Nickel, Miles Parker, Mathilde Vallat, "Estimating the Economic Costs of Extreme Weather in Real Time", (Under Review).

The flood, drought, and heatwave impact coefficients used in this package are taken from a companion paper:

Sehrish Usman, Guzmán González-Torres Fernández, Miles Parker, "Going NUTS: The regional impact of extreme climate events over the medium term", European Economic Review, 2025, 105081, ISSN 0014-2921, https://doi.org/10.1016/j.euroecorev.2025.105081, https://www.sciencedirect.com/science/article/pii/S001429212500131X

Replication package for that paper: https://github.com/MilesIParker/GoingNUTS

## Input files (Data preparation)

```
[TO BE FILLED IN — exact raw/input file names]
```

## Output files (for data analysis)

```
ready_analysis.dta
```

## Step 1 (Data preparation)

Run the do-file "01_data_preparation.do". This file imports NUTS3-level European climate data, constructs weather and hazard indicators (heat, flood, drought), pulls in regional GVA and population data from the ARDECO database, and merges everything into a single analysis-ready dataset, "ready_analysis.dta".

## Step 2 (Impact estimation)

Run the following do-files to project the economic costs of each hazard type for 2025-2029, using LP-DiD coefficients from Usman, González-Torres Fernández & Parker (2025), "Going NUTS":

- "02_flood_impact_estimation.do" — flood impacts (regional, NUTS1, country, EU27, Eurozone)
- "03_drought_impact_estimation.do" — drought impacts (regional, NUTS1, country, EU27)
- "04_heatwave_impact_estimation.do" — heatwave impacts by climate type, with 90% confidence intervals (regional, NUTS1, NUTS2, country, EU27, Eurozone)

Each script reads "ready_analysis.dta" and exports Excel tables of cumulative and incremental losses (in mn € and as % of baseline GVA).

## Set the path

```
global github_path "https://raw.githubusercontent.com/MilesIParker/CostsExtremeWeather/main"
```

## Required STATA packages

```
ssc install tsspell
ssc install gammafit
```
