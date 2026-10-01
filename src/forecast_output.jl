using DataFrames

"""
    create_forecast_output(
        years,
        months,
        temperatures,
        forecasts;
        scenario = "baseline"
    )

Organize forecast results into a structured table.

Returns a DataFrame containing the year, month, temperature scenario,
temperature, and predicted solar production for each forecast month.
"""
function create_forecast_output(
    years,
    months,
    temperatures,
    forecasts;
    scenario::AbstractString = "baseline"
)
    n = length(forecasts)

    length(years) == n ||
        throw(DimensionMismatch("years and forecasts must have the same length"))

    length(months) == n ||
        throw(DimensionMismatch("months and forecasts must have the same length"))

    length(temperatures) == n ||
        throw(DimensionMismatch("temperatures and forecasts must have the same length"))

    return DataFrame(
        year = years,
        month = months,
        scenario = fill(String(scenario), n),
        temperature_c = temperatures,
        forecast_solar_gwh = forecasts
    )
end