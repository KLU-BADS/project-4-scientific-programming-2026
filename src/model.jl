using Statistics, DataFrames
include("data.jl")

# Load data and remove any rows with missing values in our key columns
data = dropmissing(load_data(), [:solar_gwh, :year, :month, :avg_temperature_c, :sunlight_hours])

# Convert calendar year and month into a single continuous time variable
# Example: January 2021 = 0.0, February 2021 = 0.083, January 2022 = 1.0
data.time = (data.year .- 2021) .+ (data.month .- 1) ./ 12

# Temperature effect
const REF_TEMP = 25.0
const TEMP_COEF = -0.004

temperature_efficiency(temp_c) = 1.0 + TEMP_COEF * max(0.0, temp_c - REF_TEMP)

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
    # Temperature efficiency for each month, so it is not absorbed into the seasonal factor
    eff_vals = temperature_efficiency.(data.avg_temperature_c)

    # Compute multiplicative seasonal ratios (Actual / (Trend * Efficiency))
    # Ratio > 1.0 indicates above-average seasonal generation (e.g., Summer)
    # Ratio < 1.0 indicates below-average seasonal generation (e.g., Winter)
    seasonal_ratios = data.solar_gwh ./ (trend_vals .* eff_vals)

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

function estimate_temperature_efficiency(data)
    # Efficiency factor per month (1.0 at or below REF_TEMP, lower when hotter)
    efficiency_factor = temperature_efficiency.(data.avg_temperature_c)

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

function predict_solar(time, month, temp_c, trend, seasonality_df)
    # Base trend value
    trend_val = trend.intercept + trend.slope * time
    
    # Monthly seasonal factor
    s_factor = seasonality_df[seasonality_df.month .== month, :seasonal_factor][1]
    
    # Temperature efficiency factor
    eff_factor = temperature_efficiency(temp_c)
    
    # Combined Multiplicative Model
    return trend_val * s_factor * eff_factor
end


# =============================================================================
# PRINT OUTPUTS (To confirm model execution)
# =============================================================================

println("="^50)
println("1. LINEAR TREND ESTIMATION")
println("="^50)
println("Slope (Growth per year): ", round(trend.slope, digits=2), " GWh/year")
println("Intercept (Base 2021)  : ", round(trend.intercept, digits=2), " GWh")

println("\n" * "="^50)
println("2. SEASONALITY FACTORS (First 6 Months)")
println("="^50)
println(first(seasonality, 6))

println("\n" * "="^50)
println("3. TEMPERATURE EFFICIENCY (Sample Rows)")
println("="^50)
# Showing summer months where temperature effect kicks in
summer_sample = filter(row -> row.month in [1, 7, 8], temp_efficiency)
println(first(summer_sample, 6))

println("\n" * "="^50)
println("4. SAMPLE PREDICTIONS VS ACTUAL DATA")
println("="^50)

# Test predict_solar function on January 2021 (Row 1)
sample_time  = data.time[1]
sample_month = data.month[1]
sample_temp  = data.avg_temperature_c[1]
actual_gwh   = data.solar_gwh[1]

predicted_gwh = predict_solar(sample_time, sample_month, sample_temp, trend, seasonality)

println("Test Date   : Jan 2021 (Year 2021, Month 1)")
println("Actual GWh  : ", round(actual_gwh, digits=2))
println("Predicted   : ", round(predicted_gwh, digits=2))
println("="^50)

