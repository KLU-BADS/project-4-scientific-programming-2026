# Validation: how accurate is a forecast on months the model has not seen?
#
# Everything here is model-agnostic. A *forecaster* is any function
#
#     forecaster(train, test) -> Vector of predictions, one per row of `test`
#
# where `train` holds the training rows (target included) and `test` holds the
# rows to predict. When the data is a NamedTuple of columns, the target column is
# removed from `test` before it is handed over, so a forecaster cannot peek at the
# answers. For other table types (e.g. a DataFrame) the forecaster must not read
# the target column of `test` itself.
#
# Data can be a NamedTuple of equal-length column vectors, or any table that
# supports `size(data, 1)`, `data[rows, :]` and `data.column` (e.g. a DataFrame).
# Rows must be ordered in time, one row per month, with no gaps.

# ---------------------------------------------------------------------------
# Table helpers (internal)
# ---------------------------------------------------------------------------

_nrows(data::NamedTuple) = length(first(data))
_nrows(data) = size(data, 1)

_rows(data::NamedTuple, idx) = map(col -> col[idx], data)
_rows(data, idx) = data[idx, :]

_column(data, target::Symbol) = getproperty(data, target)

_drop_target(data::NamedTuple, target::Symbol) =
    Base.structdiff(data, NamedTuple{(target,)})
_drop_target(data, target::Symbol) = data

# ---------------------------------------------------------------------------
# Splitting
# ---------------------------------------------------------------------------

"""
    holdout_split(n; test_months = 12)

Split the row indices `1:n` into a training range and a test range, where the
test range is the last `test_months` rows.

Returns a NamedTuple `(train = ..., test = ...)` of index ranges.

# Examples

```jldoctest
julia> holdout_split(68)
(train = 1:56, test = 57:68)
```
"""
function holdout_split(n::Integer; test_months::Integer = 12)
    0 < test_months < n ||
        throw(ArgumentError("test_months must be between 1 and n - 1, got $test_months for n = $n"))
    return (train = 1:(n - test_months), test = (n - test_months + 1):n)
end

# ---------------------------------------------------------------------------
# Error metrics
# ---------------------------------------------------------------------------

function _check_lengths(actual, predicted)
    length(actual) == length(predicted) ||
        throw(DimensionMismatch("actual has $(length(actual)) values, predicted has $(length(predicted))"))
    isempty(actual) && throw(ArgumentError("cannot compute an error on zero values"))
    return nothing
end

"""
    mae(actual, predicted)

Mean absolute error: the average size of the forecast error, in the units of
the data (GWh for solar production).

# Examples

```jldoctest
julia> mae([100, 200], [125, 150])
37.5
```
"""
function mae(actual, predicted)
    _check_lengths(actual, predicted)
    return sum(abs.(predicted .- actual)) / length(actual)
end

"""
    rmse(actual, predicted)

Root mean squared error. Like [`mae`](@ref), but large misses count more.

# Examples

```jldoctest
julia> rmse([100, 200], [100, 220])
14.142135623730951
```
"""
function rmse(actual, predicted)
    _check_lengths(actual, predicted)
    return sqrt(sum((predicted .- actual) .^ 2) / length(actual))
end

"""
    mape(actual, predicted)

Mean absolute percentage error, in percent. Throws an `ArgumentError` if any
actual value is zero, because the percentage error is undefined there.

# Examples

```jldoctest
julia> mape([100, 200], [125, 150])
25.0
```
"""
function mape(actual, predicted)
    _check_lengths(actual, predicted)
    any(iszero, actual) &&
        throw(ArgumentError("mape is undefined when an actual value is zero"))
    return 100 * sum(abs.((predicted .- actual) ./ actual)) / length(actual)
end

"""
    bias(actual, predicted)

Mean error, `predicted - actual`. Positive means the forecast is too high on
average, negative means it is too low.

# Examples

```jldoctest
julia> bias([100, 200], [125, 150])
-12.5
```
"""
function bias(actual, predicted)
    _check_lengths(actual, predicted)
    return sum(predicted .- actual) / length(actual)
end

"""
    evaluate(actual, predicted)

Compute all error metrics at once. Returns a NamedTuple
`(mae, rmse, mape, bias)`; see [`mae`](@ref), [`rmse`](@ref), [`mape`](@ref)
and [`bias`](@ref).
"""
function evaluate(actual, predicted)
    return (
        mae  = mae(actual, predicted),
        rmse = rmse(actual, predicted),
        mape = mape(actual, predicted),
        bias = bias(actual, predicted),
    )
end

# ---------------------------------------------------------------------------
# Baseline forecasters
# ---------------------------------------------------------------------------

"""
    seasonal_naive(target = :solar_gwh; period = 12)

Return a baseline forecaster that predicts each future month with the value of
the same month one year earlier (the last `period` training values, repeated).

A real model should beat this baseline; if it does not, the extra modelling
adds nothing.

Use it like any other forecaster, e.g. `validate(seasonal_naive(), data)`.
"""
function seasonal_naive(target::Symbol = :solar_gwh; period::Integer = 12)
    return function (train, test)
        y = _column(train, target)
        length(y) >= period ||
            throw(ArgumentError("seasonal_naive needs at least $period training values, got $(length(y))"))
        last_season = y[(end - period + 1):end]
        return [last_season[mod1(i, period)] for i in 1:_nrows(test)]
    end
end

"""
    seasonal_naive_growth(target = :solar_gwh; period = 12)

Return a baseline forecaster like [`seasonal_naive`](@ref), but scaled by the
growth of the last year: the ratio of the total of the last `period` training
values to the total of the `period` values before them. A forecast `k` years
ahead is multiplied by that ratio `k` times.

Needs at least `2 * period` training values.
"""
function seasonal_naive_growth(target::Symbol = :solar_gwh; period::Integer = 12)
    return function (train, test)
        y = _column(train, target)
        length(y) >= 2 * period ||
            throw(ArgumentError("seasonal_naive_growth needs at least $(2 * period) training values, got $(length(y))"))
        last_season  = y[(end - period + 1):end]
        prior_season = y[(end - 2 * period + 1):(end - period)]
        growth = sum(last_season) / sum(prior_season)
        return [last_season[mod1(i, period)] * growth^cld(i, period) for i in 1:_nrows(test)]
    end
end

# ---------------------------------------------------------------------------
# Running a validation
# ---------------------------------------------------------------------------

function _forecast_and_score(forecaster, data, train_idx, test_idx, target)
    train = _rows(data, train_idx)
    test  = _drop_target(_rows(data, test_idx), target)
    predicted = forecaster(train, test)
    actual = _column(data, target)[test_idx]
    length(predicted) == length(actual) ||
        throw(DimensionMismatch("forecaster returned $(length(predicted)) values for $(length(actual)) test rows"))
    return actual, predicted
end

"""
    validate(forecaster, data; target = :solar_gwh, test_months = 12)

Hold out the last `test_months` rows of `data`, fit and forecast them with
`forecaster(train, test)`, and compare the forecast with the actual values.

Returns a NamedTuple with the index ranges `train` and `test`, the `actual`
and `predicted` values for the test rows, and the error `metrics` (see
[`evaluate`](@ref)).
"""
function validate(forecaster, data; target::Symbol = :solar_gwh, test_months::Integer = 12)
    split = holdout_split(_nrows(data); test_months = test_months)
    actual, predicted = _forecast_and_score(forecaster, data, split.train, split.test, target)
    return (
        train     = split.train,
        test      = split.test,
        actual    = actual,
        predicted = predicted,
        metrics   = evaluate(actual, predicted),
    )
end

"""
    backtest(forecaster, data; target = :solar_gwh, horizon = 12, min_train = 36, step = 3)

Rolling-origin validation. For each forecast origin `t` in
`min_train:step:(n - horizon)`, train on rows `1:t` and forecast rows
`t+1:t+horizon`. Averaging over several origins is more reliable than a
single hold-out split when the history is short.

Returns a NamedTuple with the `origins`, the `metrics` of each origin, and
their `mean`.
"""
function backtest(forecaster, data; target::Symbol = :solar_gwh,
                  horizon::Integer = 12, min_train::Integer = 36, step::Integer = 3)
    n = _nrows(data)
    horizon > 0 || throw(ArgumentError("horizon must be positive"))
    step > 0 || throw(ArgumentError("step must be positive"))
    min_train + horizon <= n ||
        throw(ArgumentError("not enough rows: min_train + horizon = $(min_train + horizon) > $n"))

    origins = collect(min_train:step:(n - horizon))
    metrics = map(origins) do t
        actual, predicted = _forecast_and_score(forecaster, data, 1:t, (t + 1):(t + horizon), target)
        evaluate(actual, predicted)
    end
    k = length(metrics)
    avg = (
        mae  = sum(m.mae  for m in metrics) / k,
        rmse = sum(m.rmse for m in metrics) / k,
        mape = sum(m.mape for m in metrics) / k,
        bias = sum(m.bias for m in metrics) / k,
    )
    return (origins = origins, metrics = metrics, mean = avg)
end

"""
    compare_forecasters(data, forecasters::Pair...; target = :solar_gwh, test_months = 12)

Validate several forecasters on the same hold-out split and return one row
per forecaster, sorted from lowest to highest MAE. Each forecaster is given as
`name => forecaster`, for example

```julia
compare_forecasters(data,
    "model"                 => my_forecaster,
    "seasonal naive"        => seasonal_naive(),
    "seasonal naive+growth" => seasonal_naive_growth())
```

Each row is a NamedTuple `(name, mae, rmse, mape, bias)`.
"""
function compare_forecasters(data, forecasters::Pair...; target::Symbol = :solar_gwh,
                             test_months::Integer = 12)
    rows = map(collect(forecasters)) do (name, forecaster)
        m = validate(forecaster, data; target = target, test_months = test_months).metrics
        (name = String(name), mae = m.mae, rmse = m.rmse, mape = m.mape, bias = m.bias)
    end
    return sort(rows; by = r -> r.mae)
end
