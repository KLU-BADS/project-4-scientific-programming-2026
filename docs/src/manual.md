# Reference manual

Every function in the project: what goes in and what comes out. For how the parts fit together and why the model works this way, see [Project design](design.md). The runnable scripts in `scripts/` (data downloads, validation, forecast, charts) are described in the [README](https://github.com/KLU-BADS/project-4-scientific-programming-2026).

```@meta
CurrentModule = Project4
```

```@docs
Project4
```

## Data

```@docs
load_data
```

## Model

```@docs
temperature_efficiency
estimate_trend
estimate_seasonality
estimate_temperature_efficiency
predict_solar
```

## Validation

### Training and testing the model

```@docs
train_model
predict_model
forecast_model
forecast_model_no_temperature
```

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
