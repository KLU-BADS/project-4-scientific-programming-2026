"""
    monthly_temperature_baseline(months, temperatures)

Calculate the average historical temperature for each calendar month.
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

Create future monthly temperatures by adding a warming value
to the historical monthly baseline.
"""
function future_temperature_scenario(
    months,
    baseline;
    warming_c::Real = 0.0
)
    return [
        baseline[Int(month)] + warming_c
        for month in months
    ]
end