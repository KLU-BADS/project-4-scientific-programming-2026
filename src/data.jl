using CSV
using DataFrames

function load_data()
    return CSV.read("data.csv", DataFrame)
end