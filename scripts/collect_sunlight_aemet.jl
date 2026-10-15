# collect_sunlight_aemet.jl
#
# Downloads monthly sunshine hours for Spain from AEMET OpenData, averages
# them over several weather stations and saves the result to
# data/sunlight_hours.csv  (columns: year, month, sunlight_hours).
#
# Setup (once):
#   julia -e 'using Pkg; Pkg.add(["HTTP", "JSON3", "CSV", "DataFrames"])'
#   Get a free API key at https://opendata.aemet.es/ and store it as an
#   environment variable. NEVER write the key into this file or commit it to
#   GitHub:
#     export AEMET_API_KEY="your-key"        (Mac / Linux)
#     $env:AEMET_API_KEY = "your-key"        (Windows PowerShell)
#
# Run:  julia --project=. src/collect_sunlight_aemet.jl
#       (or press run in VS Code after setting ENV["AEMET_API_KEY"] in the REPL)

using HTTP
using JSON3
using CSV
using DataFrames
using Dates

const DATA_DIR = joinpath(@__DIR__, "..", "data")

# Period to collect (inclusive)
const FIRST_YEAR = 2021
const LAST_YEAR  = 2026
const LAST_MONTH = 8          # last month available in LAST_YEAR

const AEMET_BASE = "https://opendata.aemet.es/opendata/api"

# AEMET stations (idema) whose monthly sunshine hours are averaged:
# Cordoba, Caceres, Badajoz, Ciudad Real, Toledo, Valladolid, Barcelona,
# Lleida, A Coruna, Madrid (Barajas)
const AEMET_STATIONS = ["5402", "3469A", "4452", "4121", "3260B",
                        "2422", "0076", "9771C", "1387", "3129"]

# Weight of each station in the national average ("national weighted sunshine hours"),
# from the weights in the original Python code (they sum to 1.0):
#   Cordoba 0.20, Caceres 0.15, Badajoz 0.15, Ciudad Real 0.12, Toledo 0.08,
#   Valladolid 0.05, Barcelona 0.10, Lleida 0.05, A Coruna 0.05, Madrid 0.05
# !! The Python code introduced them as an ASSUMPTION ("假設"). Check them: the monthly
# !! weighted_daily_mean in data/sunlight_hours_detail.csv should be about 4.452 for Jan 2021
# !! and 5.297 for Feb 2021 (values in data_original2.numbers).
const STATION_WEIGHTS = Dict("5402" => 0.20, "3469A" => 0.15, "4452" => 0.15, "4121" => 0.12, "3260B" => 0.08,
                             "2422" => 0.05, "0076" => 0.10, "9771C" => 0.05, "1387" => 0.05, "3129" => 0.05)

"""GET a URL and parse the JSON body."""
function fetch_json(url::AbstractString, headers = Pair{String,String}[])
    for attempt in 1:5
        try
            resp = HTTP.get(url, headers; retries = 1, read_idle_timeout = 60)
            return JSON3.read(String(resp.body))
        catch e
            attempt == 5 && rethrow()
            @info "Connection problem, retrying in $(5attempt)s" attempt exception = (e isa HTTP.Exceptions.StatusError ? "HTTP $(e.status)" : string(typeof(e)))
            sleep(5 * attempt)                             # back off: 5, 10, 15, 20 s
        end
    end
end

"""AEMET answers in two steps: first a JSON with a `datos` link, then the data."""
function aemet_get(path::AbstractString)
    key = get(ENV, "AEMET_API_KEY", "")
    isempty(key) && error("Set the AEMET_API_KEY environment variable first (see top of file).")
    meta = fetch_json(AEMET_BASE * path, ["api_key" => key, "Accept" => "application/json"])
    meta.estado == 200 || error("AEMET error $(meta.estado): $(meta.descripcion)")
    return fetch_json(String(meta.datos))
end

"""Mean sunshine hours PER DAY of one station and year (AEMET field `inso`)."""
function fetch_station_year(year::Int, station::AbstractString)
    path = "/valores/climatologicos/mensualesanuales/datos/anioini/$year/aniofin/$year/estacion/$station"
    records = aemet_get(path)
    rows = DataFrame(year = Int[], month = Int[], station = String[], daily = Float64[])
    for r in records
        y, m = parse.(Int, split(String(r.fecha), "-"))   # fecha looks like "2021-1"
        m == 13 && continue                                # month 13 = yearly summary
        haskey(r, :inso) || continue                       # station did not report sunshine
        push!(rows, (y, m, station, parse(Float64, replace(String(r.inso), "," => "."))))
    end
    return rows
end

"""
National weighted mean of the daily sunshine hours (stations that reported, weights
re-normalised), then x days in the month -> monthly total, rounded.
"""
function collect_sunlight()
    parts = DataFrame[]
    for year in FIRST_YEAR:LAST_YEAR, station in AEMET_STATIONS
        @info "AEMET sunlight" year station
        try
            push!(parts, fetch_station_year(year, station))
        catch e
            @warn "SKIPPED after 5 attempts" year station exception = (e isa HTTP.Exceptions.StatusError ? "HTTP $(e.status)" : string(typeof(e)))
        end
        sleep(3)                                           # AEMET limits the request rate
    end
    all_rows = reduce(vcat, parts)
    # keep the raw per-station values for checking, and warn about stations with missing months
    CSV.write(joinpath(DATA_DIR, "sunlight_by_station.csv"), sort(all_rows, [:station, :year, :month]))
    for station in AEMET_STATIONS, year in FIRST_YEAR:LAST_YEAR
        last = year == LAST_YEAR ? LAST_MONTH : 12
        n_months = count(r -> r.station == station && r.year == year && r.month <= last, eachrow(all_rows))
        n_months < last && @warn "Station has missing months (or no data)" station year months_found = n_months months_expected = last
    end
    all_rows.w = [STATION_WEIGHTS[st] for st in all_rows.station]
    detail = combine(groupby(all_rows, [:year, :month]),
                     [:daily, :w] => ((d, w) -> sum(d .* w) / sum(w)) => :weighted_daily_mean,
                     :station => length => :stations_used)
    filter!(r -> (r.year, r.month) <= (LAST_YEAR, LAST_MONTH), detail)
    sort!(detail, [:year, :month])
    detail.sunlight_hours = [round(Int, r.weighted_daily_mean * daysinmonth(r.year, r.month)) for r in eachrow(detail)]
    return detail
end

function main()
    mkpath(DATA_DIR)
    detail = collect_sunlight()
    CSV.write(joinpath(DATA_DIR, "sunlight_hours.csv"), select(detail, :year, :month, :sunlight_hours))
    # extra file for checking: daily mean and number of stations per month
    detail_out = copy(detail)
    detail_out.weighted_daily_mean = round.(detail_out.weighted_daily_mean; digits = 3)
    CSV.write(joinpath(DATA_DIR, "sunlight_hours_detail.csv"), detail_out)
    println("Saved data/sunlight_hours.csv  (", nrow(detail), " months)")
    println(first(detail, 5))
end

main()
