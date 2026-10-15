# The forecasting model: trend × seasonal factor × temperature efficiency.
#
# The functions expect a table (a DataFrame from `load_data`, or a NamedTuple of
# columns) with the columns `time`, `month`, `solar_gwh` and `avg_temperature_c`.

# Temperature effect
"""Reference temperature (°C): panels lose no efficiency at or below it."""
const REF_TEMP = 25.0
"""Efficiency change per °C above `REF_TEMP`: −0.4 %."""
const TEMP_COEF = -0.004

"""
    temperature_efficiency(temp_c)

Efficiency factor of the solar panels at a monthly mean temperature of
`temp_c` °C: 1.0 at or below 25 °C, then 0.4 % lower for every degree above.

# Examples

```jldoctest
julia> temperature_efficiency(20.0)
1.0

julia> temperature_efficiency(30.0)
0.98
```
"""
temperature_efficiency(temp_c) = 1.0 + TEMP_COEF * max(0.0, temp_c - REF_TEMP)

# -----------------------------------------------------------------------------
# 1. Linear Trend Estimation (Ordinary Least Squares)
# -----------------------------------------------------------------------------
# Finds the overall growth line of solar energy over time (slope and intercept)

"""
    estimate_trend(data)

Fit a straight line `solar_gwh = intercept + slope × time` by ordinary least
squares. `slope` is the growth of monthly production per year (GWh).

Returns a NamedTuple `(slope, intercept)`.
"""
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

# -----------------------------------------------------------------------------
# 2. Multiplicative Seasonality Estimation
# -----------------------------------------------------------------------------
# Calculates how much solar production goes above or below average in each month

"""
    estimate_seasonality(data, trend)

Estimate one multiplicative factor per calendar month: actual production
divided by (trend × temperature efficiency), averaged per month and scaled so
the 12 factors average 1. The temperature effect is removed first, so it is
not counted twice in [`predict_solar`](@ref).

Returns a DataFrame with the columns `month` and `seasonal_factor`.
"""
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

# -----------------------------------------------------------------------------
# 3. Temperature Efficiency Factor Estimation
# -----------------------------------------------------------------------------
# Models efficiency loss when panels get hot in warm months

"""
    estimate_temperature_efficiency(data)

Table of the temperature efficiency factor (see [`temperature_efficiency`](@ref))
for every month in `data`, for inspection. Returns a DataFrame with the
columns `year`, `month`, `avg_temp` and `efficiency_factor`.
"""
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

# -----------------------------------------------------------------------------
# 4. Model Prediction Function
# -----------------------------------------------------------------------------
# Combines all three parts into one single forecast function for other files to use

"""
    predict_solar(time, month, temp_c, trend, seasonality_df)

Forecast solar production (GWh) for one month:

    (intercept + slope × time) × seasonal factor of `month` × temperature_efficiency(temp_c)

`time` is in years since January 2021, `trend` comes from
[`estimate_trend`](@ref) and `seasonality_df` from [`estimate_seasonality`](@ref).
"""
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