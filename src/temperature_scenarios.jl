"""
    monthly_temperature_changes(years, months, temperatures)

Calculate the average year-to-year temperature change for each month
and store the most recent temperature for that month.
"""
function monthly_temperature_changes(years, months, temperatures)
    n = length(years)

    length(months) == n ||
        throw(DimensionMismatch("years and months must have the same length"))

    length(temperatures) == n ||
        throw(DimensionMismatch("years and temperatures must have the same length"))

    average_changes = Dict{Int, Float64}()
    latest_temperatures = Dict{Int, Float64}()

    for month in 1:12
        indices = findall(months .== month)

        length(indices) >= 2 ||
            throw(ArgumentError("at least two temperature values are required for month $month"))

        month_years = years[indices]
        month_temperatures = temperatures[indices]

        order = sortperm(month_years)
        sorted_temperatures = month_temperatures[order]

        changes = diff(sorted_temperatures)

        average_changes[month] = sum(changes) / length(changes)
        latest_temperatures[month] = sorted_temperatures[end]
    end

    return average_changes, latest_temperatures
end


"""
    future_temperature_scenario(months, latest_temperatures, average_changes)

Estimate the future temperature for each month using the most recent
temperature plus its average historical change.
"""
function future_temperature_scenario(
    months,
    latest_temperatures,
    average_changes
)
    return [
        floor(
            Int,
            latest_temperatures[Int(month)] +
            average_changes[Int(month)] +
            0.5
        )
        for month in months
    ]
end