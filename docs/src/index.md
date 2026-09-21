# SolarCastSpain.jl

## About the project

This project explores how much solar energy Spain could produce in the future. We use real historical data on solar electricity production, sunlight, and temperature to build a simple forecasting model.

The main idea is to look at two effects:

* **Solar capacity growth** — more solar panels should increase electricity production.
* **Rising temperatures** — higher temperatures can slightly reduce solar panel efficiency.

We also take into account the strong seasonal pattern of solar energy production, since Spain produces much more solar electricity during some months than others.

## What we will do

**The** project will:

1. Collect monthly solar production, sunlight, and temperature data for Spain.
2. Explore the historical data and its seasonal patterns using Julia.
3. Estimate the historical growth trend in solar production.
4. Include a simple temperature effect on solar panel efficiency.
5. Forecast future solar production under different warming scenarios.
6. Test the model by forecasting historical months that were left out of the data.
7. Compare the forecasts with the actual values and report the model's accuracy.

## Data

We aim to use publicly available data from sources such as:

* **Red Eléctrica (REE)** or **ENTSO-E** for solar electricity production.
* **AEMET** or a similar public meteorological source for sunlight and temperature.

If a particular dataset is difficult to obtain, we may use a simplified synthetic version for that variable. Any such data will be clearly identified.

## Goal

The goal is to create a simple and understandable forecast of Spain's future solar energy production while showing how both **increasing solar capacity** and **rising temperatures** can affect the result.

The project will be implemented in **Julia**, with the analysis, visualizations, forecasting, and validation documented throughout the project.

