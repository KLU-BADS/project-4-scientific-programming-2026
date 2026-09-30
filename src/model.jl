using Statistics, DataFrames
include("data.jl")

# Load data and remove any rows with missing values in our key columns
data = dropmissing(load_data(), [:solar_gwh, :year, :month, :avg_temperature_c, :sunlight_hours])

# Convert calendar year and month into a single continuous time variable
# Example: January 2021 = 0.0, February 2021 = 0.083, January 2022 = 1.0
data.time = (data.year .- 2021) .+ (data.month .- 1) ./ 12

# -----------------------------------------------------------------------------
# 1. Linear Trend Estimation (Ordinary Least Squares)
# -----------------------------------------------------------------------------
# Finds the overall growth line of solar energy over time (slope and intercept)

function estimate_trend(data)
    x = data.time
    y = data.solar_gwh

    # Compute average time and average solar production
    x_mean = mean(x)
    y_mean = mean(y)

    # Standard formula for regression slope: Covariance(x, y) / Variance(x)
    slope = sum((x .- x_mean) .* (y .- y_mean)) /
            sum((x .- x_mean).^2)

    # Calculate intercept so the trend line passes through (x_mean, y_mean)
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
# Calculates how much solar production goes above or below average in each month

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

    # Normalize factors so the average across all 12 months equals 1.0
    seasonal_df.seasonal_factor ./= mean(seasonal_df.seasonal_factor)

    return seasonal_df
end

seasonality = estimate_seasonality(data, trend)

# -----------------------------------------------------------------------------
# 3. Temperature Efficiency Factor Estimation
# -----------------------------------------------------------------------------
# Models efficiency loss when panels get hot in warm months

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

# -----------------------------------------------------------------------------
# 4. Model Prediction Function
# -----------------------------------------------------------------------------
# Combines all three parts into one single forecast function for other files to use




