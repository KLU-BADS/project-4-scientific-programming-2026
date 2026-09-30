# Run the validation component on the project's dataset and print the results.
#
# Usage, from the repository folder:
#
#     julia --project=. scripts/run_validation.jl                   # finds data/data_solar.csv
#     julia --project=. scripts/run_validation.jl path/to/file.csv
#
# The CSV needs a header row and the columns year, month and solar_gwh.
# No extra packages are needed.

using Project4
using Printf

# ---------------------------------------------------------------------------
# Load the data
# ---------------------------------------------------------------------------

function find_dataset()
    isempty(ARGS) || return ARGS[1]
    here = dirname(@__DIR__)                      # repository folder
    for path in (joinpath(here, "data", "data_solar.csv"),
                 joinpath(here, "data_solar.csv"))
        isfile(path) && return path
    end
    error("data/data_solar.csv not found; pass the CSV path as an argument")
end

"""
Read a comma-separated file into a NamedTuple of columns, sorted by year and
month. Columns that are all numbers become Float64, others stay text. Blank
rows (e.g. `,,,,,` left over from Excel) and stray spaces are ignored.
"""
function load_dataset(path)
    lines = readlines(path)
    lines = [lstrip(l, '\ufeff') for l in lines]             # Excel's UTF-8 marker
    lines = filter(l -> !isempty(strip(replace(l, "," => ""))), lines)

    names = Symbol.(strip.(split(lines[1], ",")))
    rows  = [strip.(split(l, ",")) for l in lines[2:end]]
    all(r -> length(r) == length(names), rows) ||
        error("every row must have $(length(names)) columns")

    columns = map(eachindex(names)) do j
        raw  = [r[j] for r in rows]
        nums = tryparse.(Float64, raw)
        any(isnothing, nums) ? String.(raw) : Float64.(nums)
    end
    data = NamedTuple{Tuple(names)}(Tuple(columns))

    order = sortperm(collect(zip(data.year, data.month)))
    return map(col -> col[order], data)
end

path = find_dataset()
data = load_dataset(path)
n = length(data.solar_gwh)

label(i) = @sprintf("%04d-%02d", Int(data.year[i]), Int(data.month[i]))

println()
println("Dataset: ", path)
println("Rows:    ", n, " months, ", label(1), " to ", label(n))

# ---------------------------------------------------------------------------
# Forecasters to compare. Add the team's model here once it exists:
#     "model" => my_forecaster,
# ---------------------------------------------------------------------------

forecasters = (
    "seasonal naive"          => seasonal_naive(:solar_gwh),
    "seasonal naive + growth" => seasonal_naive_growth(:solar_gwh),
)

# ---------------------------------------------------------------------------
# 1. Hold-out: last 12 months
# ---------------------------------------------------------------------------

hold = holdout_split(n; test_months = 12)
println("Train:   ", label(first(hold.train)), " to ", label(last(hold.train)),
        " (", length(hold.train), " months)")
println("Test:    ", label(first(hold.test)), " to ", label(last(hold.test)),
        " (", length(hold.test), " months)")

function print_metrics_table(title, rows)
    println()
    println(title)
    @printf("  %-26s %10s %10s %8s %10s\n", "forecaster", "MAE", "RMSE", "MAPE", "bias")
    for r in rows
        @printf("  %-26s %10.1f %10.1f %7.1f%% %+10.1f\n", r.name, r.mae, r.rmse, r.mape, r.bias)
    end
end

rows = compare_forecasters(data, forecasters...; test_months = 12)
print_metrics_table("1. Hold-out on the last 12 months (GWh; best first)", rows)

# ---------------------------------------------------------------------------
# 2. Month-by-month for the best forecaster
# ---------------------------------------------------------------------------

best_name = rows[1].name
best = Dict(forecasters)[best_name]
r = validate(best, data; test_months = 12)

println()
println("2. Month by month: ", best_name)
@printf("  %-8s %10s %10s %10s %8s\n", "month", "actual", "forecast", "error", "error%")
for (k, i) in enumerate(r.test)
    err = r.predicted[k] - r.actual[k]
    @printf("  %-8s %10.1f %10.1f %+10.1f %+7.1f%%\n",
            label(i), r.actual[k], r.predicted[k], err, 100 * err / r.actual[k])
end

# ---------------------------------------------------------------------------
# 3. Error by season for the best forecaster
# ---------------------------------------------------------------------------

season_of(m) = m in (12, 1, 2) ? "Winter" : m in (3, 4, 5) ? "Spring" :
               m in (6, 7, 8) ? "Summer" : "Autumn"
seasons = [season_of(Int(data.month[i])) for i in r.test]

println()
println("3. Error by season: ", best_name)
@printf("  %-8s %7s %10s %8s %10s\n", "season", "months", "MAE", "MAPE", "bias")
for s in ("Winter", "Spring", "Summer", "Autumn")
    idx = findall(==(s), seasons)
    isempty(idx) && continue
    m = evaluate(r.actual[idx], r.predicted[idx])
    @printf("  %-8s %7d %10.1f %7.1f%% %+10.1f\n", s, length(idx), m.mae, m.mape, m.bias)
end

# ---------------------------------------------------------------------------
# 4. Rolling backtest: more reliable than one split with short history
# ---------------------------------------------------------------------------

bt_rows = map(collect(forecasters)) do (name, f)
    b = backtest(f, data; horizon = 12, min_train = 36, step = 3)
    merge((name = name, origins = b.origins), b.mean)
end
sort!(bt_rows; by = x -> x.mae)
origins = bt_rows[1].origins
print_metrics_table(
    "4. Rolling backtest: 12-month forecasts from $(length(origins)) cut-offs " *
    "($(label(first(origins))) to $(label(last(origins)))), averaged", bt_rows)

println()
println("Reading the results: MAPE is the average % miss. Bias > 0 means the")
println("forecast is too high on average, < 0 too low. A real model should")
println("have a lower MAE and MAPE than both baselines.")
println()
