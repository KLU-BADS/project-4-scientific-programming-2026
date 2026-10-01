# Future forecasting component for SolarCastSpain.
#
# This component is kept separate from:
# - data input and loading
# - model estimation
# - validation
# - forecast output formatting
#
# Future temperature scenarios will be implemented in issue #18.
# Forecast generation will be implemented in issue #19.
# Forecast output formatting will be implemented in issue #20.
"""
    generate_forecast(predictor, times, months, temperatures, trend, seasonality)

Generate one solar production prediction for each future month.

`predictor` is the model function used to calculate solar production for one
month. `times`, `months`, and `temperatures` must contain the same number of
values.

Returns a vector containing one forecast value for each future month.
"""
function generate_forecast(predictor, times, months, temperatures, trend, seasonality)
    n = length(times)

    length(months) == n ||
        throw(DimensionMismatch("times and months must have the same length"))

    length(temperatures) == n ||
        throw(DimensionMismatch("times and temperatures must have the same length"))

    return [
        predictor(time, month, temperature, trend, seasonality)
        for (time, month, temperature) in zip(times, months, temperatures)
    ]
end