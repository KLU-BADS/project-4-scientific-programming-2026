# Result charts for the report (issue #32).
#
# Usage, from the repository folder:
#
#     julia --project=. scripts/plot_results.jl
#
# Needs Plots once, in your default Julia environment:
#
#     julia -e 'using Pkg; Pkg.add("Plots")'
#
# Saves:
#     results/accuracy_comparison.png   team model vs baselines (hold-out and backtest MAPE)
#     results/seasonal_pattern.png      seasonal factor of each calendar month
#     results/sunlight_effect.png       unusual sunlight vs what the model misses

using Project4
using Printf
using Plots
using Statistics

cd(dirname(@__DIR__))                            # repository folder: data.csv lives here
include(joinpath("..", "src", "model.jl"))       # data, trend, seasonality (all months), predict_solar
include(joinpath("..", "src", "train_test.jl"))  # forecast_model

INK, MUTED, GREY, BLUE = "#0b0b0b", "#52514e", "#a9a8a2", "#2a78d6"
default(fontfamily = "Helvetica", titlelocation = :left, titlefontsize = 12,
        guidefontsize = 10, tickfontsize = 9, legendfontsize = 9,
        gridalpha = 0.15, framestyle = :axes, foreground_color_legend = nothing,
        background_color_legend = nothing, left_margin = 6Plots.mm,
        bottom_margin = 6Plots.mm)
mkpath("results")
MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

# ---------------------------------------------------------------------------
# 1. Accuracy: team model vs baselines
# ---------------------------------------------------------------------------

forecasters = ["Team model"              => forecast_model,
               "Seasonal naive + growth" => seasonal_naive_growth(:solar_gwh),
               "Seasonal naive"          => seasonal_naive(:solar_gwh)]
labels   = ["Team\nmodel", "Seasonal naive\n+ growth", "Seasonal\nnaive"]
colors   = [BLUE, GREY, GREY]          # highlight the team model, baselines recede
holdout  = [validate(f, data; test_months = 12).metrics.mape for (_, f) in forecasters]
rolling  = [backtest(f, data; horizon = 12, min_train = 36, step = 3).mean.mape for (_, f) in forecasters]
ymax     = 1.2 * max(maximum(holdout), maximum(rolling))

function mape_panel(values, title)
    p = plot(title = title, ylabel = "MAPE (%)", ylims = (0, ymax), legend = false,
             xticks = (1:length(values), labels), xlims = (0.4, length(values) + 0.6))
    for (i, v) in enumerate(values)
        bar!(p, [i], [v]; color = colors[i], linecolor = colors[i], bar_width = 0.55)
        annotate!(p, i, v + 0.05 * ymax, text(@sprintf("%.1f%%", v), 9, INK, :center))
    end
    return p
end

fig1 = plot(mape_panel(holdout, "Hold-out: last 12 months"),
            mape_panel(rolling, "Rolling backtest: 7 cut-offs"),
            layout = (1, 2), size = (1100, 480),
            plot_title = "Forecast error, lower is better", plot_titlefontsize = 13)
savefig(fig1, joinpath("results", "accuracy_comparison.png"))

# ---------------------------------------------------------------------------
# 2. Seasonal pattern (model fitted on all months)
# ---------------------------------------------------------------------------

order   = sortperm(seasonality.month)
factors = seasonality.seasonal_factor[order]
fig2 = bar(1:12, factors; color = BLUE, linecolor = BLUE, bar_width = 0.6, label = "",
           title = "Seasonal pattern: production of each month relative to an average month",
           ylabel = "Seasonal factor (1.0 = average month)",
           xticks = (1:12, MONTHS[seasonality.month[order]]),
           ylims = (0, 1.2 * maximum(factors)), size = (1100, 480))
hline!(fig2, [1.0]; color = MUTED, lw = 1, ls = :dash, label = "")
for (i, v) in enumerate(factors)
    annotate!(fig2, i, v + 0.05 * maximum(factors), text(@sprintf("%.2f", v), 8, MUTED, :center))
end
savefig(fig2, joinpath("results", "seasonal_pattern.png"))

# ---------------------------------------------------------------------------
# 3. Sunlight: months with unusual sunlight vs what the model misses
# ---------------------------------------------------------------------------

predicted = [predict_solar(t, m, T, trend, seasonality)
             for (t, m, T) in zip(data.time, data.month, data.avg_temperature_c)]
model_gap = 100 .* (data.solar_gwh ./ predicted .- 1)          # > 0: produced more than the model expects
normal_sun = Dict(m => mean(data.sunlight_hours[data.month .== m]) for m in 1:12)
sun_diff   = 100 .* (data.sunlight_hours ./ [normal_sun[m] for m in data.month] .- 1)

slope     = cov(sun_diff, model_gap) / var(sun_diff)
intercept = mean(model_gap) - slope * mean(sun_diff)
r         = cor(sun_diff, model_gap)
xs        = range(minimum(sun_diff), maximum(sun_diff); length = 50)

fig3 = scatter(sun_diff, model_gap; color = BLUE, ms = 5, msw = 0, label = "One month (2021–2026)",
               title = "Months with less sunlight than usual produce less than the model expects",
               xlabel = "Sunlight vs normal for that month (%)",
               ylabel = "Actual vs model (%)", legend = :topleft, size = (1100, 560))
plot!(fig3, xs, intercept .+ slope .* xs; color = MUTED, lw = 1.5, ls = :dash,
      label = @sprintf("Linear fit (correlation %.2f)", r))
hline!(fig3, [0]; color = GREY, lw = 1, label = "")
vline!(fig3, [0]; color = GREY, lw = 1, label = "")
for (y, m) in ((2026, 1), (2026, 2), (2025, 12))
    i = findfirst((data.year .== y) .& (data.month .== m))
    i === nothing && continue
    annotate!(fig3, sun_diff[i] + 2.5, model_gap[i],
              text(string(MONTHS[m], " ", y), 8, MUTED, :left))
end
savefig(fig3, joinpath("results", "sunlight_effect.png"))

# ---------------------------------------------------------------------------

println()
@printf("Hold-out MAPE:  team model %.1f%%, naive + growth %.1f%%, naive %.1f%%\n", holdout...)
@printf("Backtest MAPE:  team model %.1f%%, naive + growth %.1f%%, naive %.1f%%\n", rolling...)
@printf("Sunlight vs model gap: correlation %.2f\n", r)
println("Saved results/accuracy_comparison.png, results/seasonal_pattern.png, results/sunlight_effect.png")
