using Statistics
include("data.jl")

data = load_data()

# Center time relative to 2021
data.time = (data.year .- 2021) .+ (data.month .- 1) ./ 12

function estimate_trend(data)
    # Collect only complete pairs without any missing values
    valid_idx = .!ismissing.(data.time) .& .!ismissing.(data.solar_gwh)
    x = data.time[valid_idx]
    y = data.solar_gwh[valid_idx]

    x_mean = mean(x)
    y_mean = mean(y)

    slope = sum((x .- x_mean) .* (y .- y_mean)) /
            sum((x .- x_mean).^2)

    intercept = y_mean - slope * x_mean

    return (
        slope = slope,
        intercept = intercept
    )
end

trend = estimate_trend(data)

#= function estimate_seasonality(data)
    return combine(
        groupby(data, :month),
        :solar_gwh => mean => :mean_production
    )
end

seasonal = estimate_seasonality(data)
println(seasonal)

function estimate_temperature_effect(data)
    # TODO
end

function build_model(data)
    trend = estimate_trend(data)
    seasonal = estimate_seasonality(data)
    temperature_effect = estimate_temperature_effect(data)

    return SolarModel(
        trend,
        seasonal,
        temperature_effect
    )
end

=#



