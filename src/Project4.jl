"""
    Project4

Forecast Spain's monthly solar energy production (SolarCastSpain).
"""
module Project4

# Files to be included
include("validation.jl")
include("forecasting.jl")
include("temperature_scenarios.jl")
include("forecast_output.jl")

# Functions to be exported
export holdout_split, mae, rmse, mape, bias, evaluate
export seasonal_naive, seasonal_naive_growth
export validate, backtest, compare_forecasters
export monthly_temperature_changes, future_temperature_scenario
export generate_forecast
export create_forecast_output

end # module Project4