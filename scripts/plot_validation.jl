# Plot actual vs forecast for the validation hold-out (issue #30).
#
# Usage, from the repository folder:
#
#     julia --project=. scripts/plot_validation.jl
#
# Needs CSV, DataFrames and Plots once, in your default Julia environment:
#
#     julia -e 'using Pkg; Pkg.add(["CSV", "DataFrames", "Plots"])'
#
# Saves results/validation_actual_vs_forecast.png

using Project4
using Printf
using Plots

cd(dirname(@__DIR__))                            # repository folder: data.csv lives here
include(joinpath("..", "src", "model.jl"))       # data, estimate_trend, predict_solar, ...
include(joinpath("..", "src", "train_test.jl"))  # forecast_model

# ---------------------------------------------------------------------------
# Validate the team model and the best baseline on the last 12 months
# ---------------------------------------------------------------------------

model_run = validate(forecast_model, data; test_months = 12)
base_run  = validate(seasonal_naive_growth(:solar_gwh), data; test_months = 12)

x      = 2021 .+ data.time                       # decimal years, e.g. 2025.67
x_test = x[model_run.test]
gwh_to_twh = 1 / 1000

# Colours: neutral ink for the actual data, two fixed categorical hues for
# the forecasts, recessive grey for grid and the hidden test period.
INK    = "#0b0b0b"
MUTED  = "#52514e"
SHADE  = "#ecebe7"
BLUE   = "#2a78d6"   # team model
ORANGE = "#eb6834"   # baseline

default(fontfamily = "Helvetica", titlelocation = :left, titlefontsize = 12,
        guidefontsize = 10, tickfontsize = 9, legendfontsize = 9,
        gridalpha = 0.15, framestyle = :axes, foreground_color_legend = nothing,
        background_color_legend = nothing, left_margin = 6Plots.mm,
        bottom_margin = 5Plots.mm)

# ---------------------------------------------------------------------------
# Panel 1: full history, with the forecasts for the hidden months
# ---------------------------------------------------------------------------

p1 = plot(title = "Actual vs forecast solar production in Spain (hold-out: last 12 months)",
          ylabel = "Monthly production (TWh)", legend = :topleft,
          xticks = 2021:2027, xlims = (2021 - 0.1, last(x) + 0.25))
vspan!(p1, [first(x_test) - 1 / 24, last(x_test) + 1 / 24];
       color = SHADE, linecolor = SHADE, label = "Test months (hidden from the model)")
plot!(p1, x, data.solar_gwh .* gwh_to_twh; color = INK, lw = 2, label = "Actual")
plot!(p1, x_test, base_run.predicted .* gwh_to_twh; color = ORANGE, lw = 2, ls = :dash,
      marker = :diamond, ms = 5, msw = 0,
      label = @sprintf("Baseline: seasonal naive + growth (MAPE %.1f%%)", base_run.metrics.mape))
plot!(p1, x_test, model_run.predicted .* gwh_to_twh; color = BLUE, lw = 2,
      marker = :circle, ms = 5, msw = 0,
      label = @sprintf("Team model (MAPE %.1f%%)", model_run.metrics.mape))

# ---------------------------------------------------------------------------
# Panel 2: the team model's error for each test month
# ---------------------------------------------------------------------------

errors = 100 .* (model_run.predicted .- model_run.actual) ./ model_run.actual
MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
labels = [string(MONTHS[Int(data.month[i])], "\n", Int(data.year[i])) for i in model_run.test]

p2 = bar(1:length(errors), errors; color = BLUE, linecolor = BLUE, bar_width = 0.6,
         label = "", title = "Team model error by month (above 0 = forecast too high)",
         ylabel = "Error (%)", xticks = (1:length(errors), labels),
         ylims = (min(minimum(errors), 0) - 8, max(maximum(errors), 0) + 8))
hline!(p2, [0]; color = MUTED, lw = 1, label = "")
for (i, e) in enumerate(errors)
    annotate!(p2, i, e + (e >= 0 ? 3.5 : -3.5),
              text(@sprintf("%+.0f%%", e), 8, MUTED, :center))
end

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

fig = plot(p1, p2; layout = grid(2, 1; heights = [0.58, 0.42]), size = (1100, 850))
mkpath("results")
out = joinpath("results", "validation_actual_vs_forecast.png")
savefig(fig, out)
println("Saved ", out)
