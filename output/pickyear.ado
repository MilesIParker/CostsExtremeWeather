*! pickyear 1.0  -- select an ARDECO year column by its header, not its position
*! Usage: pickyear <year> <newname>
*!
*! ARDECO csv-table exports have numeric year headers ("1980", ..., "2027").
*! -import delimited- cannot use those as variable names, so it names the
*! columns v6, v7, ... by POSITION and stores the original header ("2025") as
*! the variable label. Referring to v50/v51 directly is fragile: v50 is 2024,
*! not 2025, in the 2024 vintage. This program finds the column whose label is
*! the requested year and renames it, and stops with an error if none exists.
program define pickyear
    version 16
    args year newname
    if "`year'" == "" | "`newname'" == "" {
        display as error "syntax: pickyear <year> <newname>"
        exit 198
    }
    local found 0
    foreach v of varlist _all {
        local l : variable label `v'
        if "`l'" == "`year'" {
            rename `v' `newname'
            local found 1
            continue, break
        }
    }
    if !`found' {
        display as error "ARDECO column for year `year' not found"
        exit 111
    }
end
