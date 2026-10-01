"""
    monthly_temperature_baseline(months, temperatures)

Calculate the historical average temperature for each calendar month.

Returns a dictionary where the keys are month numbers (`1` to `12`)
and the values are the corresponding average temperatures.
"""
function monthly_temperature_baseline(months, temperatures)
    length(months) == length(temperatures) ||
        throw(DimensionMismatch("months and temperatures must have the same length"))

    baseline = Dict{Int, Float64}()

    for month in 1:12
        monthly_values = temperatures[months .== month]

        isempty(monthly_values) &&
            throw(ArgumentError("no temperature data available for month $month"))

        baseline[month] = sum(monthly_values) / length(monthly_values)
    end

    return baseline
end


"""
    future_temperature_scenario(months, baseline; warming_c = 0.0)

Create future monthly temperatures from a historical monthly baseline.

`warming_c` is added to each baseline monthly temperature.
"""
function future_temperature_scenario(months, baseline; warming_c::Real = 0.0)
    return [baseline[Int(month)] + warming_c for month in months]
end