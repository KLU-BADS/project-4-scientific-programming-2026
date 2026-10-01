# Run the validation component on the project's dataset and print the results.
#
# Usage, from the repository folder:
#
#     julia --project=. scripts/run_validation.jl
#
# Loads the data and the team model exactly as src/model.jl does, so it needs
# the CSV and DataFrames packages once, in your default Julia environment:
#
#     julia -e 'using Pkg; Pkg.add(["CSV", "DataFrames"])'

using Project4
using Printf

# ---------------------------------------------------------------------------
# Load the data and the team model
# ---------------------------------------------------------------------------

cd(dirname(@__DIR__))                            # repository folder: data.csv lives here
include(joinpath("..", "src", "model.jl"))       # defines `data` (with `time`), estimate_trend, ...
include(joinpath("..", "src", "train_test.jl"))  # train_model, predict_model, forecast_model, ...

path = "data.csv"
n = length(data.solar_gwh)

label(i) = @sprintf("%04d-%02d", Int(data.year[i]), Int(data.month[i]))

println()
println("Dataset: ", path)
println("Rows:    ", n, " months, ", label(1), " to ", label(n))

# ---------------------------------------------------------------------------
# Forecasters to compare: the team model against the two baselines.
# ---------------------------------------------------------------------------

forecasters = (
    "team model (full)"           => forecast_model,
    "trend x season (no temp)"    => forecast_model_no_temperature,
    "seasonal naive"              => seasonal_naive(:solar_gwh),
    "seasonal naive + growth"     => seasonal_naive_growth(:solar_gwh),
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
    @printf("  %-29s %10s %10s %8s %10s\n", "forecaster", "MAE", "RMSE", "MAPE", "bias")
    for r in rows
        @printf("  %-29s %10.1f %10.1f %7.1f%% %+10.1f\n", r.name, r.mae, r.rmse, r.mape, r.bias)
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
