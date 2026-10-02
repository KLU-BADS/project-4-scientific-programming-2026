# Final forecast results under warming scenarios (issue #32).
#
# Usage, from the repository folder:
#
#     julia --project=. scripts/run_forecast.jl
#
# Needs Plots once, in your default Julia environment:
#
#     julia -e 'using Pkg; Pkg.add("Plots")'
#
# Uses the model fitted on ALL historical months (src/model.jl) and the
# forecasting functions of the package (generate_forecast, ...). Saves:
#
#     results/forecast_monthly_scenarios.csv   one row per future month and scenario
#     results/forecast_annual_summary.csv      yearly totals and change vs no warming
#     results/forecast_scenarios.png           history + forecast, and the warming effect

using Project4
using CSV
using DataFrames
using Printf
using Plots

cd(dirname(@__DIR__))                            # repository folder: data.csv lives here
include(joinpath("..", "src", "model.jl"))       # data, trend, seasonality (all months), predict_solar

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

END_YEAR = 2028                  # last forecast year (the linear trend is less reliable further out)
WARMING  = [0.0, 1.0, 2.0, 3.0]  # °C added to the typical temperature of each month

scenario_name(w) = w == 0 ? "no warming" : @sprintf("+%.0f °C", w)

# ---------------------------------------------------------------------------
# Future months, from the month after the last observation to December END_YEAR
# ---------------------------------------------------------------------------

last_year, last_month = Int(data.year[end]), Int(data.month[end])
future = [(y, m) for y in last_year:END_YEAR for m in 1:12 if (y, m) > (last_year, last_month)]
years  = first.(future)
months = last.(future)
times  = (years .- 2021) .+ (months .- 1) ./ 12   # same time scale as model.jl

# Typical temperature of each calendar month, from all historical data
baseline = monthly_temperature_baseline(data.month, data.avg_temperature_c)

# ---------------------------------------------------------------------------
# Forecast every scenario
# ---------------------------------------------------------------------------

tables = DataFrame[]
for w in WARMING
    temps    = future_temperature_scenario(months, baseline; warming_c = w)
    forecast = generate_forecast(predict_solar, times, months, temps, trend, seasonality)
    push!(tables, create_forecast_output(years, months, temps, forecast;
                                         scenario = scenario_name(w)))
end
monthly = vcat(tables...)

# Yearly totals (complete years only) and change compared with no warming
annual = combine(groupby(monthly, [:year, :scenario]),
                 :forecast_solar_gwh => sum => :total_gwh, nrow => :months)
filter!(r -> r.months == 12, annual)
no_warming = Dict(r.year => r.total_gwh for r in eachrow(annual) if r.scenario == scenario_name(0))
annual.total_twh = annual.total_gwh ./ 1000
annual.change_vs_no_warming_pct = [100 * (r.total_gwh / no_warming[r.year] - 1) for r in eachrow(annual)]
select!(annual, :year, :scenario, :total_twh, :change_vs_no_warming_pct)

mkpath("results")
CSV.write(joinpath("results", "forecast_monthly_scenarios.csv"), monthly)
CSV.write(joinpath("results", "forecast_annual_summary.csv"), annual)

# ---------------------------------------------------------------------------
# Print
# ---------------------------------------------------------------------------

println()
@printf("Model fitted on %d months (%d-%02d to %d-%02d)\n", length(data.solar_gwh),
        Int(data.year[1]), Int(data.month[1]), last_year, last_month)
@printf("Forecast: %d-%02d to %d-12, scenarios: %s\n", years[1], months[1], END_YEAR,
        join(scenario_name.(WARMING), ", "))
println()
println("Annual solar production (complete years)")
@printf("  %-6s %-12s %12s %18s\n", "year", "scenario", "total (TWh)", "vs no warming")
for r in eachrow(annual)
    @printf("  %-6d %-12s %12.2f %17.2f%%\n", r.year, r.scenario, r.total_twh, r.change_vs_no_warming_pct)
end

# ---------------------------------------------------------------------------
# Plot
# ---------------------------------------------------------------------------

INK, MUTED, SHADE, BLUE = "#0b0b0b", "#52514e", "#ecebe7", "#2a78d6"
default(fontfamily = "Helvetica", titlelocation = :left, titlefontsize = 12,
        guidefontsize = 10, tickfontsize = 9, legendfontsize = 9,
        gridalpha = 0.15, framestyle = :axes, foreground_color_legend = nothing,
        background_color_legend = nothing, left_margin = 6Plots.mm,
        bottom_margin = 5Plots.mm)

x_hist = 2021 .+ data.time
x_fut  = 2021 .+ times
base_fc = tables[1].forecast_solar_gwh

p1 = plot(title = "Spain's monthly solar production: history and forecast (no warming)",
          ylabel = "Monthly production (TWh)", legend = :topleft,
          xticks = 2021:(END_YEAR + 1), xlims = (2021 - 0.1, END_YEAR + 1.05))
vspan!(p1, [first(x_fut) - 1 / 24, last(x_fut) + 1 / 24];
       color = SHADE, linecolor = SHADE, label = "Forecast period")
plot!(p1, x_hist, data.solar_gwh ./ 1000; color = INK, lw = 2, label = "Actual")
plot!(p1, x_fut, base_fc ./ 1000; color = BLUE, lw = 2, label = "Forecast")

# Effect of each warming scenario on the last forecast year
last_full = maximum(annual.year)
effect = filter(r -> r.year == last_full && r.scenario != scenario_name(0), annual)
p2 = bar(1:nrow(effect), effect.change_vs_no_warming_pct; color = BLUE, linecolor = BLUE,
         bar_width = 0.5, label = "",
         title = "Effect of warming on $(last_full) production (vs no warming)",
         ylabel = "Change (%)", xticks = (1:nrow(effect), effect.scenario),
         ylims = (min(minimum(effect.change_vs_no_warming_pct), 0) * 1.35, 0.0001))
hline!(p2, [0]; color = MUTED, lw = 1, label = "")
for (i, v) in enumerate(effect.change_vs_no_warming_pct)
    annotate!(p2, i, v * 1.12, text(@sprintf("%.2f%%", v), 8, MUTED, :center))
end

fig = plot(p1, p2; layout = grid(2, 1; heights = [0.62, 0.38]), size = (1100, 850))
out = joinpath("results", "forecast_scenarios.png")
savefig(fig, out)
println()
println("Saved results/forecast_monthly_scenarios.csv, results/forecast_annual_summary.csv, ", out)
