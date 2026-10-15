# Train / test wrapper around the model in model.jl, so it can be validated:
# fit on the training months only, then forecast the test months.
#
# `train` and `test` are tables (e.g. from `load_data`) with the columns `time`,
# `month` and `avg_temperature_c` (and `solar_gwh` in `train`).

"""
    train_model(train)

Fit the trend × seasonality model on the training months only.

Returns a NamedTuple `(trend, seasonality)`: the linear trend from
`estimate_trend` and the 12 monthly factors from `estimate_seasonality`.
"""
function train_model(train)
    trend = estimate_trend(train)
    seasonality = estimate_seasonality(train, trend)
    return (trend = trend, seasonality = seasonality)
end

"""
    predict_model(model, test; temperature = true)

Forecast `solar_gwh` for each row of `test` with a model from `train_model`,
using [`predict_solar`](@ref):

    forecast = (intercept + slope × time) × seasonal factor × temperature efficiency

With `temperature = false` the efficiency factor is left out (trend × season
only), to measure what the temperature part adds. Never looks at
`test.solar_gwh`.
"""
function predict_model(model, test; temperature::Bool = true)
    if temperature
        return [predict_solar(t, m, T, model.trend, model.seasonality)
                for (t, m, T) in zip(test.time, test.month, test.avg_temperature_c)]
    end
    factor = Dict(zip(model.seasonality.month, model.seasonality.seasonal_factor))
    trend_values = model.trend.intercept .+ model.trend.slope .* test.time
    return trend_values .* [factor[m] for m in test.month]
end

"""
    forecast_model(train, test)

Train on `train`, forecast `test` with the full team model (trend × season ×
temperature efficiency). This is the `forecaster(train, test)` format that
`validate`, `backtest` and `compare_forecasters` expect.
"""
forecast_model(train, test) = predict_model(train_model(train), test)

"""
    forecast_model_no_temperature(train, test)

Like [`forecast_model`](@ref), but without the temperature efficiency factor.
"""
forecast_model_no_temperature(train, test) =
    predict_model(train_model(train), test; temperature = false)
