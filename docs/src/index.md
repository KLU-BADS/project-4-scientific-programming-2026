# SolarCastSpain.jl

## About the project

How much solar electricity will Spain produce each month up to 2028, and how much could a warmer climate change that?

This project answers that question with a simple, transparent forecasting model written in Julia. It uses real monthly data on Spain's solar electricity production and temperature, and combines three effects:

* **Solar capacity growth**: Spain keeps installing panels, so production rises over time.
* **Seasonality**: summer months produce far more than winter months.
* **Temperature**: solar panels lose a little efficiency when it is very hot, so warmer months, and a warmer future, reduce output slightly.

## What the project does

1. Loads monthly solar production and weather data for Spain (January 2021 – August 2026).
2. Fits a long-term growth trend and 12 monthly seasonal factors.
3. Applies a temperature efficiency adjustment for hot months.
4. Validates the model on held-out months and compares it with two benchmark forecasts.
5. Forecasts monthly solar production from September 2026 to December 2028 under 0, +1, +2 and +3 °C of warming.

## Data

| Variable | Source | Unit | Period |
|---|---|---|---|
| Solar generation | REE (Red Eléctrica) open data, [apidatos.ree.es](https://apidatos.ree.es) | GWh per month | Jan 2021 – Aug 2026 |
| Average temperature | AEMET OpenData, [opendata.aemet.es](https://opendata.aemet.es) | °C, monthly mean | Jan 2021 – Aug 2026 |
| Sunshine hours | AEMET OpenData (weighted average of 10 stations) | hours per month | Jan 2021 – Aug 2026 |

The cleaned dataset is stored as `data.csv`, with one row per month and the columns `year`, `month`, `solar_gwh`, `avg_temperature_c` and `sunlight_hours`.

## The model in one line

```
forecast = trend(time) × seasonal factor(month) × temperature efficiency(temperature)
```

* **Trend**: a straight line fitted by ordinary least squares through all months.
* **Seasonal factor**: one number per calendar month, measuring how far that month usually sits above or below the trend. The 12 factors average 1.
* **Temperature efficiency**: 1.0 up to 25 °C, then −0.4 % for every degree above 25 °C. This is a fixed assumption based on typical panel behaviour, not estimated from the data.

## Key results

* The model's average monthly error on unseen months is about **11 %**, better than both benchmark methods.
* Solar production is forecast to grow from about **51 TWh in 2025** to about **79.5 TWh in 2028**.
* Within the model, even **+3 °C** of warming reduces yearly production by only about **0.25 %**.

## Where to go next

* [Results in the README](https://github.com/KLU-BADS/project-4-scientific-programming-2026#results): accuracy, forecast tables, charts and limitations
* [Project design](design.md): how the code is organised and how the model works
* [Reference manual](manual.md): every function and what it does
* To install and run the project, see the [README on GitHub](https://github.com/KLU-BADS/project-4-scientific-programming-2026).

## Team

Ting-Ru Cheng, Hui-Yi Chiang, Azimjon Firuzov, Piyatida Aodthon, Alejandra Zamora