using Statistics, DataFrames
include("data.jl")

# Drop any rows where solar_gwh, year, or month are missing
data = dropmissing(load_data(), [:solar_gwh, :year, :month, :avg_temperature_c, :sunlight_hours])

# Center time relative to 2021
data.time = (data.year .- 2021) .+ (data.month .- 1) ./ 12

# -----------------------------------------------------------------------------
# 1. Linear Trend Estimation (Ordinary Least Squares)
# -----------------------------------------------------------------------------

function estimate_trend(data)
    x = data.time
    y = data.solar_gwh

    # Calculate sample means
    x_mean = mean(x)
    y_mean = mean(y)

    # Slope formula: Covariance(x, y) / Variance(x)
    slope = sum((x .- x_mean) .* (y .- y_mean)) /
            sum((x .- x_mean).^2)

    # Intercept formula: Ensures regression line passes through point (x_mean, y_mean)
    intercept = y_mean - slope * x_mean

    return (
        slope = slope,
        intercept = intercept
    )
end

trend = estimate_trend(data)

# -----------------------------------------------------------------------------
# 2. Multiplicative Seasonality Estimation
# -----------------------------------------------------------------------------

function estimate_seasonality(data, trend)
    # Compute predicted baseline trend values for each point in time
    trend_vals = trend.intercept .+ trend.slope .* data.time

    # Compute multiplicative seasonal ratios (Actual / Trend)
    # Ratio > 1.0 indicates above-average seasonal generation (e.g., Summer)
    # Ratio < 1.0 indicates below-average seasonal generation (e.g., Winter)
    seasonal_ratios = data.solar_gwh ./ trend_vals

    # Map seasonal ratios back to their respective calendar months
    temp_df = DataFrame(month = data.month, ratio = seasonal_ratios)

    # Average ratios by month (1 to 12)
    seasonal_df = combine(
        groupby(temp_df, :month),
        :ratio => mean => :seasonal_factor
    )

    # Rescale seasonal factors so their mean across all 12 months is exactly 1.0
    seasonal_df.seasonal_factor ./= mean(seasonal_df.seasonal_factor)

    return seasonal_df
end

seasonality = estimate_seasonality(data, trend)

# -----------------------------------------------------------------------------
# 3. Temperature Efficiency Factor Estimation
# -----------------------------------------------------------------------------

function estimate_temperature_efficiency(data; ref_temp=20.0, temp_coef=-0.004)
    # Calculate degrees above reference temperature (e.g., 20°C baseline)
    # Temperatures below ref_temp do not reduce efficiency
    temp_above_ref = max.(0.0, data.avg_temperature_c .- ref_temp)

    # Efficiency factor: 1.0 at or below ref_temp, decreasing as temperature rises
    # Default coefficient -0.004 represents a 0.4% efficiency drop per °C
    efficiency_factor = 1.0 .+ (temp_coef .* temp_above_ref)

    return DataFrame(
        year = data.year,
        month = data.month,
        avg_temp = data.avg_temperature_c,
        efficiency_factor = efficiency_factor
    )
end

temp_efficiency = estimate_temperature_efficiency(data)

#= 

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



