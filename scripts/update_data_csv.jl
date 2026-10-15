# update_data_csv.jl
#
# Writes the downloaded solar generation and sunlight hours into the team's
# data.csv. Only the columns solar_gwh and sunlight_hours are replaced; the
# other columns (avg_temperature_c, season) are left as they are.
#
# Run the two download scripts first, so data/solar_production.csv and
# data/sunlight_hours.csv exist.
#
# Usage, from the repository folder:
#
#     julia --project=. scripts/update_data_csv.jl --dry-run    (only shows the changes)
#     julia --project=. scripts/update_data_csv.jl              (changes data.csv)

using CSV
using DataFrames

const ROOT = joinpath(@__DIR__, "..")
const DATA_CSV = joinpath(ROOT, "data.csv")

function main()
    dry_run = "--dry-run" in ARGS

    old = CSV.read(DATA_CSV, DataFrame)
    dropmissing!(old, [:year, :month])                       # data.csv ends with empty rows
    old.solar_gwh = parse.(Float64, strip.(string.(old.solar_gwh)))   # values have a trailing space

    solar = CSV.read(joinpath(ROOT, "data", "solar_production.csv"), DataFrame)
    sun = CSV.read(joinpath(ROOT, "data", "sunlight_hours.csv"), DataFrame)
    solar_by = Dict((r.year, r.month) => Float64(r.solar_gwh) for r in eachrow(solar))
    sun_by = Dict((r.year, r.month) => Int(r.sunlight_hours) for r in eachrow(sun))

    changed = 0
    for r in eachrow(old)
        k = (r.year, r.month)
        if haskey(solar_by, k) && abs(solar_by[k] - r.solar_gwh) > 0.015
            println("$(k[1])-$(lpad(k[2], 2, '0'))  solar_gwh       $(r.solar_gwh) -> $(solar_by[k])")
            r.solar_gwh = solar_by[k]
            changed += 1
        end
        if haskey(sun_by, k) && sun_by[k] != r.sunlight_hours
            println("$(k[1])-$(lpad(k[2], 2, '0'))  sunlight_hours  $(r.sunlight_hours) -> $(sun_by[k])")
            r.sunlight_hours = sun_by[k]
            changed += 1
        end
    end
    missing_months = [k for k in sort(collect(keys(solar_by))) if !any(r -> (r.year, r.month) == k, eachrow(old))]
    isempty(missing_months) || @warn "Months not in data.csv (not added)" missing_months

    if dry_run
        println(changed, " value(s) would change. Nothing was written.")
    else
        CSV.write(DATA_CSV, old)
        println(changed, " value(s) changed. Saved ", DATA_CSV)
    end
end

main()
