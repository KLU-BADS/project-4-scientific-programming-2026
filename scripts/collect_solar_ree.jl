# collect_solar_ree.jl
#
# Downloads monthly solar PV generation (Solar fotovoltaica) for Spain from the
# public REE open-data API (https://apidatos.ree.es, no token needed) and saves
# it to data/solar_production.csv  (columns: year, month, solar_gwh).
#
# Notes
#  * One request per year (REE refuses very long date ranges).
#  * Peninsular Spain + Canary + Balearic islands (national total, like the project data).
#  * Runs from VS Code (press run), the terminal, or GitHub Actions.
#
# Terminal:  julia --project=scripts scripts/collect_solar_ree.jl
#            (install the packages once with:
#             julia --project=scripts -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()')

using HTTP, JSON, CSV, DataFrames, Dates

const DATA_DIR   = joinpath(@__DIR__, "..", "data")
const URL        = "https://apidatos.ree.es/es/datos/generacion/estructura-generacion"
const FIRST_YEAR = 2021
# Same period as the project dataset: Jan 2021 - Aug 2026 (68 months)
const LAST_DAY   = Date(2026, 8, 31)

# Islands are added on top of the default (peninsular) answer: region => geo_id
const ISLANDS = ["canarias" => 8742, "baleares" => 8743]

function fetch_year(year::Int, island = nothing)
    stop = min(Date(year, 12, 31), LAST_DAY)
    url = "$URL?start_date=$year-01-01T00:00&end_date=$(stop)T23:59&time_trunc=month"
    island === nothing || (url *= "&geo_trunc=electric_system&geo_limit=$(island[1])&geo_ids=$(island[2])")
    resp = try
        HTTP.get(url, ["Accept" => "application/json"]; retries = 3)
    catch e
        e isa HTTP.Exceptions.StatusError &&
            println("FAILED HTTP ", e.status, "\n  URL: ", url, "\n  Body: ", first(String(e.response.body), 400))
        rethrow()
    end
    body = JSON.parse(String(resp.body))
    rows = DataFrame(year = Int[], month = Int[], solar_gwh = Float64[])
    for item in body["included"]
        attrs = item["attributes"]
        occursin("fotovoltaica", lowercase(String(attrs["title"]))) || continue
        for v in attrs["values"]
            dt = String(v["datetime"])                     # "2021-01-01T00:00:00.000+01:00"
            push!(rows, (parse(Int, dt[1:4]), parse(Int, dt[6:7]), round(Float64(v["value"]) / 1000; digits = 2)))
        end
    end
    return rows
end


function main()
    mkpath(DATA_DIR)
    parts = DataFrame[]
    for year in FIRST_YEAR:Dates.year(LAST_DAY)
        @info "REE solar" year
        push!(parts, fetch_year(year))
        sleep(1)
        for island in ISLANDS
            try
                push!(parts, fetch_year(year, island))
            catch e
                @warn "Island data missing - total will be too LOW" year island = island[1]
            end
            sleep(1)
        end
    end
    all_rows = reduce(vcat, parts)
    solar = combine(groupby(all_rows, [:year, :month]), :solar_gwh => (x -> round(sum(x); digits = 2)) => :solar_gwh)
    sort!(solar, [:year, :month])
    isempty(solar) && error("REE returned no solar data")
    CSV.write(joinpath(DATA_DIR, "solar_production.csv"), solar)
    println("Saved data/solar_production.csv  (", nrow(solar), " months, ",
            solar.year[1], "-", solar.month[1], " to ", solar.year[end], "-", solar.month[end], ")")
    println(first(solar, 3))
end

main()