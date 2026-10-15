"""
    Project4

Forecast Spain's monthly solar energy production (SolarCastSpain).
"""
module Project4

using CSV
using DataFrames
using Statistics

# Files to be included
include("data.jl")
include("model.jl")
include("train_test.jl")
include("validation.jl")
include("forecasting.jl")
include("temperature_scenarios.jl")
include("forecast_output.jl")

# Functions to be exported
export load_data
export temperature_efficiency, estimate_trend, estimate_seasonality
export estimate_temperature_efficiency, predict_solar
export train_model, predict_model, forecast_model, forecast_model_no_temperature
export holdout_split, mae, rmse, mape, bias, evaluate
export seasonal_naive, seasonal_naive_growth
export validate, backtest, compare_forecasters
export monthly_temperature_baseline, future_temperature_scenario
export generate_forecast
export create_forecast_output

end # module Project4