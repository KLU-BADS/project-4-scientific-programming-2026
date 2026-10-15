using Project4
using Test

# Every @testset that fails will be reported individually, so give them
# names that tell you what broke.

@testset "Project4.jl" begin

    # Add a @testset for each function you write.

    # Synthetic monthly data for the validation tests: a fixed seasonal
    # pattern, with and without 10 % growth per year. 5 years = 60 months.
    base   = [100.0, 110, 150, 170, 210, 250, 260, 240, 200, 160, 120, 100]
    months = repeat(1:12, 5)
    years  = repeat(0:4; inner = 12)
    flat    = (month = collect(months), solar_gwh = [base[m] for m in months])
    growing = (month = collect(months),
               solar_gwh = [base[m] * 1.1^y for (m, y) in zip(months, years)])

    # Synthetic monthly data for the model tests: an exact linear trend
    # (1000 + 500 × time GWh), a fixed seasonal pattern that averages 1, and
    # mild temperatures (no efficiency loss). 4 years = 48 months.
    pattern = [0.6, 0.7, 0.9, 1.1, 1.3, 1.4, 1.5, 1.4, 1.1, 0.8, 0.65, 0.55]
    pattern = pattern ./ (sum(pattern) / 12)
    mo   = repeat(collect(1:12), 4)
    yr   = repeat(collect(0:3); inner = 12)
    tm   = yr .+ (mo .- 1) ./ 12
    true_trend = (slope = 500.0, intercept = 1000.0)
    synth = (year = 2021 .+ yr, month = mo, time = tm,
             avg_temperature_c = fill(15.0, 48),
             solar_gwh = (1000.0 .+ 500.0 .* tm) .* pattern[mo])

    @testset "load_data" begin
        d = load_data()
        @test size(d, 1) > 0
        @test :time in propertynames(d)
        @test !any(ismissing, d.solar_gwh)
        @test !any(ismissing, d.avg_temperature_c)
        @test d.time[1] ≈ (d.year[1] - 2021) + (d.month[1] - 1) / 12
    end

    @testset "temperature_efficiency" begin
        @test temperature_efficiency(20.0) == 1.0
        @test temperature_efficiency(25.0) == 1.0
        @test temperature_efficiency(30.0) ≈ 0.98
        eff = estimate_temperature_efficiency(synth)
        @test all(eff.efficiency_factor .== 1.0)
    end

    @testset "estimate_trend" begin
        # A pure straight line is recovered exactly.
        line = (time = tm, solar_gwh = 1000.0 .+ 500.0 .* tm)
        tr = estimate_trend(line)
        @test tr.slope ≈ 500.0
        @test tr.intercept ≈ 1000.0
    end

    @testset "estimate_seasonality" begin
        # With the true trend, the seasonal pattern is recovered exactly.
        s = estimate_seasonality(synth, true_trend)
        @test sort(s.month) == collect(1:12)
        @test [s.seasonal_factor[s.month .== m][1] for m in 1:12] ≈ pattern
        @test sum(s.seasonal_factor) / 12 ≈ 1.0
        # Hot months: the heat loss is removed before the factors are
        # computed, so the same pattern comes out (no double counting).
        hot_temp = [m in (7, 8) ? 30.0 : 15.0 for m in mo]
        hot = merge(synth, (avg_temperature_c = hot_temp,
                            solar_gwh = synth.solar_gwh .* temperature_efficiency.(hot_temp)))
        s_hot = estimate_seasonality(hot, true_trend)
        @test [s_hot.seasonal_factor[s_hot.month .== m][1] for m in 1:12] ≈ pattern
    end

    @testset "predict_solar" begin
        s = estimate_seasonality(synth, true_trend)
        @test predict_solar(2.0, 7, 15.0, true_trend, s) ≈ (1000 + 500 * 2.0) * pattern[7]
        # Above 25 °C the efficiency loss is applied.
        @test predict_solar(2.0, 7, 30.0, true_trend, s) ≈ (1000 + 500 * 2.0) * pattern[7] * 0.98
    end

    @testset "train_model and predict_model" begin
        model = train_model(synth)
        @test keys(model) == (:trend, :seasonality)
        pred = predict_model(model, synth)
        @test length(pred) == 48
        @test all(pred .> 0)
        # At mild temperatures the temperature factor changes nothing.
        @test predict_model(model, synth; temperature = false) ≈ pred
        # forecast_model plugs into the validation tools.
        r = validate(forecast_model, synth; test_months = 12)
        @test length(r.predicted) == 12
        @test all(isfinite, r.predicted)
        @test forecast_model_no_temperature(synth, synth) ≈ pred
    end

    @testset "holdout_split" begin
        s = holdout_split(68)
        @test s.train == 1:56
        @test s.test == 57:68
        @test holdout_split(10; test_months = 3) == (train = 1:7, test = 8:10)
        @test_throws ArgumentError holdout_split(10; test_months = 0)
        @test_throws ArgumentError holdout_split(10; test_months = 10)
    end

    @testset "metrics" begin
        actual    = [100.0, 200.0]
        predicted = [125.0, 150.0]
        @test mae(actual, predicted) ≈ 37.5
        @test rmse(actual, predicted) ≈ sqrt((25^2 + 50^2) / 2)
        @test mape(actual, predicted) ≈ 25.0
        @test bias(actual, predicted) ≈ -12.5
        @test evaluate(actual, predicted) == (mae = mae(actual, predicted),
                                              rmse = rmse(actual, predicted),
                                              mape = mape(actual, predicted),
                                              bias = bias(actual, predicted))
        # A perfect forecast has zero error.
        @test evaluate(actual, actual) == (mae = 0.0, rmse = 0.0, mape = 0.0, bias = 0.0)
        # Bias sign: too high is positive.
        @test bias([100.0], [110.0]) > 0
        @test_throws DimensionMismatch mae([1.0, 2.0], [1.0])
        @test_throws ArgumentError mae(Float64[], Float64[])
        @test_throws ArgumentError mape([0.0, 1.0], [1.0, 1.0])
    end

    @testset "seasonal_naive" begin
        # On data that repeats exactly every year, last year is a perfect forecast.
        r = validate(seasonal_naive(), flat)
        @test r.predicted ≈ r.actual
        @test r.metrics.mae ≈ 0 atol = 1e-9
        # It repeats the last 12 training values in order.
        f = seasonal_naive()
        train = (month = collect(1:12), solar_gwh = base)
        @test f(train, (month = collect(1:14),)) == vcat(base, base[1:2])
        @test_throws ArgumentError f((month = [1], solar_gwh = [1.0]), (month = [2],))
    end

    @testset "seasonal_naive_growth" begin
        # With constant 10 % growth, scaling last year by the growth is exact,
        # while plain seasonal naive is 10 % too low.
        r = validate(seasonal_naive_growth(), growing)
        @test r.predicted ≈ r.actual
        naive = validate(seasonal_naive(), growing)
        @test naive.metrics.bias < 0
        @test naive.metrics.mape ≈ 100 * (1 - 1 / 1.1)
        # Two years ahead grows twice.
        f = seasonal_naive_growth()
        train = (month = collect(1:24), solar_gwh = vcat(base, 2 .* base))
        pred = f(train, (month = collect(1:24),))
        @test pred[1:12] ≈ 4 .* base
        @test pred[13:24] ≈ 8 .* base
        @test_throws ArgumentError f((month = collect(1:12), solar_gwh = base), (month = [1],))
    end

    @testset "validate" begin
        r = validate(seasonal_naive(), flat; test_months = 6)
        @test r.train == 1:54
        @test r.test == 55:60
        @test length(r.actual) == length(r.predicted) == 6
        @test keys(r.metrics) == (:mae, :rmse, :mape, :bias)
        # The forecaster must not see the target of the test rows.
        peek = (train, test) -> (haskey(test, :solar_gwh) ? error("leak") : fill(1.0, length(test.month)))
        @test validate(peek, flat).predicted == fill(1.0, 12)
        # A forecaster returning the wrong number of values is an error.
        @test_throws DimensionMismatch validate((train, test) -> [1.0], flat)
    end

    @testset "backtest" begin
        b = backtest(seasonal_naive(), flat; horizon = 12, min_train = 24, step = 6)
        @test b.origins == [24, 30, 36, 42, 48]
        @test length(b.metrics) == 5
        @test b.mean.mae ≈ 0 atol = 1e-9
        @test_throws ArgumentError backtest(seasonal_naive(), flat; min_train = 50, horizon = 12)
    end

    @testset "compare_forecasters" begin
        rows = compare_forecasters(growing,
            "naive"  => seasonal_naive(),
            "growth" => seasonal_naive_growth())
        @test [r.name for r in rows] == ["growth", "naive"]   # best first
        @test rows[1].mae < rows[2].mae
    end
    @testset "temperature scenarios" begin
    # Two years of synthetic monthly temperatures.
    # Year 1: 1°C to 12°C
    # Year 2: 3°C to 14°C
    months = repeat(collect(1:12), 2)
    temperatures = vcat(
        Float64.(1:12),
        Float64.(3:14)
    )

    baseline = monthly_temperature_baseline(months, temperatures)

    # The baseline should contain all 12 calendar months.
    @test sort(collect(keys(baseline))) == collect(1:12)

    # Monthly averages should be 2°C, 3°C, ..., 13°C.
    @test [baseline[m] for m in 1:12] ≈ Float64.(2:13)

    # No warming: use the baseline temperature.
    @test future_temperature_scenario(
        [1, 7, 12],
        baseline;
        warming_c = 0.0
    ) ≈ [2.0, 8.0, 13.0]

    # Low scenario: +1°C
    @test future_temperature_scenario(
        [1, 7, 12],
        baseline;
        warming_c = 1.0
    ) ≈ [3.0, 9.0, 14.0]

    # Medium scenario: +2°C
    @test future_temperature_scenario(
        [1, 7, 12],
        baseline;
        warming_c = 2.0
    ) ≈ [4.0, 10.0, 15.0]

    # High scenario: +3°C
    @test future_temperature_scenario(
        [1, 7, 12],
        baseline;
        warming_c = 3.0
    ) ≈ [5.0, 11.0, 16.0]

    # Months and temperatures must have the same length.
    @test_throws DimensionMismatch monthly_temperature_baseline(
        [1, 2],
        [10.0]
    )

    # A baseline cannot be calculated if one calendar month is missing.
    incomplete_months = repeat(collect(1:11), 2)
    incomplete_temperatures = fill(10.0, length(incomplete_months))

    @test_throws ArgumentError monthly_temperature_baseline(
        incomplete_months,
        incomplete_temperatures
    )
    end
    @testset "generate_forecast" begin
        # Simple predictor used only for testing.
        # It makes the result easy to calculate by hand.
        predictor(time, month, temperature, trend, seasonality) =
            time + month + temperature

        times = [1.0, 2.0, 3.0]
        months = [1, 2, 3]
        temperatures = [10.0, 20.0, 30.0]

        forecasts = generate_forecast(
            predictor,
            times,
            months,
            temperatures,
            nothing,
            nothing
        )

        @test forecasts ≈ [12.0, 24.0, 36.0]

        @test_throws DimensionMismatch generate_forecast(
            predictor,
            [1.0, 2.0],
            [1],
            [10.0, 20.0],
            nothing,
            nothing
        )

        @test_throws DimensionMismatch generate_forecast(
            predictor,
            [1.0, 2.0],
            [1, 2],
            [10.0],
            nothing,
            nothing
        )
    end
    @testset "forecast output" begin
        years = [2026, 2026, 2026]
        months = [9, 10, 11]
        temperatures = [20.8, 17.8, 11.6]
        forecasts = [5808.0, 4530.0, 3481.0]

        output = create_forecast_output(
            years,
            months,
            temperatures,
            forecasts;
            scenario = "+1C"
        )

        @test size(output, 1) == 3

        @test output.year == years
        @test output.month == months
        @test output.temperature_c == temperatures
        @test output.forecast_solar_gwh == forecasts

        @test output.scenario == ["+1C", "+1C", "+1C"]

        @test_throws DimensionMismatch create_forecast_output(
            [2026],
            [9, 10],
            [20.8, 17.8],
            [5808.0, 4530.0]
        )
    end

end
