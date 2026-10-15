# Reference manual

Every function in the project: what goes in and what comes out. For how the parts fit together and why the model works this way, see [Project design](design.md). The runnable scripts in `scripts/` (data downloads, validation, forecast, charts) are described in the [README](https://github.com/KLU-BADS/project-4-scientific-programming-2026).

```@meta
CurrentModule = Project4
```

```@docs
Project4
```

## Data

This function lives in `src/data.jl`.

| Function | Input | Returns |
|---|---|---|
| `load_data()` | None (reads `data.csv` from the current folder) | DataFrame with one row per month |

## Model

These functions live in `src/model.jl`. 

| Function | Input | Returns |
|---|---|---|
| `temperature_efficiency(temp_c)` | Monthly mean temperature (°C) | Efficiency factor (1.0 at or below 25 °C) |
| `estimate_trend(data)` | Table with `time` and `solar_gwh` | `(slope, intercept)` |
| `estimate_seasonality(data, trend)` | Table with `time`, `month`, `solar_gwh`, `avg_temperature_c`; the fitted trend | DataFrame with `month` and `seasonal_factor` (12 rows) |
| `estimate_temperature_efficiency(data)` | Table with `year`, `month`, `avg_temperature_c` | DataFrame with the efficiency factor per month (for inspection only) |
| `predict_solar(time, month, temp_c, trend, seasonality)` | Time (years since Jan 2021), calendar month, temperature, fitted trend and seasonal factors | Forecast in GWh for that month |

## Validation

### Training and testing the model

These functions live in `src/train_test.jl` and need `model.jl` to be loaded first.

| Function | Input | Returns |
|---|---|---|
| `train_model(train)` | Training months | `(trend, seasonality)` |
| `predict_model(model, test; temperature = true)` | Fitted model, test months; `temperature = false` leaves out the temperature factor | Vector of forecasts (GWh) |
| `forecast_model(train, test)` | Training and test months | Vector of forecasts; the forecaster passed to `validate`, `backtest` and `compare_forecasters` |
| `forecast_model_no_temperature(train, test)` | Training and test months | The same, without the temperature factor |

### Splitting the data

```@docs
holdout_split
```

### Running a validation

```@docs
validate
backtest
compare_forecasters
```

### Benchmark forecasters

```@docs
seasonal_naive
seasonal_naive_growth
```

### Error measures

```@docs
evaluate
mae
rmse
mape
bias
```

## Forecasting

### Temperature scenarios

```@docs
monthly_temperature_baseline
future_temperature_scenario
```

### Generating and saving forecasts

```@docs
generate_forecast
create_forecast_output
```
