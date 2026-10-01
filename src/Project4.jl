"""
    Project4

Forecast Spain's monthly solar energy production (SolarCastSpain).
"""
module Project4

# Files to be included
include("validation.jl")
include("forecasting.jl")
include("temperature_scenarios.jl")

# Functions to be exported
export holdout_split, mae, rmse, mape, bias, evaluate
export seasonal_naive, seasonal_naive_growth
export validate, backtest, compare_forecasters
export monthly_temperature_baseline, future_temperature_scenario

end # module Project4