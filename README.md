# SolarCastSpain.jl

<!-- DO NOT EDIT BELOW -->
[![Tests](../../actions/workflows/tests.yml/badge.svg)](../../actions/workflows/tests.yml)
[![Documentation](../../actions/workflows/docs.yml/badge.svg)](../../actions/workflows/docs.yml)
<!-- DO NOT EDIT ABOVE -->


## Overview

<!-- DESCRIBE PROJECT PURPOSE BELOW -->
forecasts Spain's future monthly solar energy production using historical data from sources like ENTSO-E/REE and AEMET. The project models long-term solar panel capacity growth alongside seasonal patterns and efficiency losses caused by rising temperatures under various future warming scenarios.
<!-- DESCRIBE PROJECT PURPOSE ABOVE  -->

## Getting started

<!-- DO NOT EDIT BELOW -->
Clone the repository and start Julia in the project folder:

```bash
git clone https://github.com/KLU-BADS/project-4-scientific-programming-2026.git
cd project-4-scientific-programming-2026
julia --project=.
```
<!-- DO NOT EDIT ABOVE -->


<!-- DESCRIBE THE ESSENTIAL USAGE BELOW -->
To validate the forecast model on `data.csv`, run from the project folder
(the first line is needed only once):

```bash
julia -e 'using Pkg; Pkg.add(["CSV", "DataFrames"])'
julia --project=. scripts/run_validation.jl
```

This fits the model (`src/model.jl`) on the training months only, forecasts the
last 12 months, and compares it with two simple baselines (seasonal naive, with
and without growth). It prints MAE, RMSE, MAPE and bias for a hold-out test and
a rolling backtest.

The validation functions can also be used directly on any table with `month`
and `solar_gwh` columns, ordered by time:

```julia
using Project4
validate(seasonal_naive(), data).metrics   # (mae, rmse, mape, bias)
```
<!-- DESCRIBE THE ESSENTIAL USAGE ABOVE -->

## Tests

<!-- DO NOT EDIT BELOW -->
Tests are run automatically on GitHub for every push to `main` and on every pull request.

> [!TIP]
> To run the tests locally, run
> ```bash
> julia --project=. -e 'using Pkg; Pkg.test()'
> ```
 
<!-- DO NOT EDIT ABOVE -->


## Documentation

<!-- DO NOT EDIT BELOW -->
The [online documentation](https://klu-bads.github.io/project-4-scientific-programming-2026/) is automatically built and published to GitHub Pages on every push to `main`.

> [!TIP]
> To build the documentation locally, run
> ```bash
> julia --project=docs docs/make.jl
> ```
> and open `docs/build/index.html` in a browser.
>
> If building the documentation fails, run the tests locally before. 


<!-- DO NOT EDIT ABOVE -->

## Contributing

<!-- DO NOT EDIT BELOW -->
See [CONTRIBUTING.md](CONTRIBUTING.md).
<!-- DO NOT EDIT ABOVE -->

## License

<!-- DO NOT EDIT BELOW -->
MIT. See [LICENSE](LICENSE).
<!-- DO NOT EDIT ABOVE -->
