# Loading the project dataset.

"""Path of the project dataset, `data.csv` in the repository folder."""
const DATA_FILE = joinpath(dirname(@__DIR__), "data.csv")

"""
    load_data(path = DATA_FILE)

Load the monthly dataset (by default `data.csv` in the repository folder) and
prepare it for the model:

* rows with a missing `solar_gwh`, `year`, `month`, `avg_temperature_c` or
  `sunlight_hours` are removed (`data.csv` ends with empty rows);
* a `time` column is added: years since January 2021
  (January 2021 = 0.0, February 2021 = 1/12, January 2022 = 1.0).

Returns a `DataFrame` with one row per month.
"""
function load_data(path::AbstractString = DATA_FILE)
    raw = CSV.read(path, DataFrame)
    data = dropmissing(raw, [:solar_gwh, :year, :month, :avg_temperature_c, :sunlight_hours])
    data.time = (data.year .- 2021) .+ (data.month .- 1) ./ 12
    return data
end
