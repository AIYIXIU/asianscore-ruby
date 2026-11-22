# asianscore_quant

Zero-dependency Ruby quantitative sports analytics SDK and live prediction ledger client powered by [AsianScore](https://asianscore.com/).

## Installation

```bash
gem install asianscore_quant
```

Or add to your `Gemfile`:

```ruby
gem "asianscore_quant", "~> 1.0"
```

## Quickstart

```ruby
require "asianscore_quant"

# 1. Remove bookmaker overround (Multiplicative & Power devigging)
odds = [1.85, 3.60, 4.40]
fair_mult  = AsianscoreQuant.devig_multiplicative(odds)
fair_power = AsianscoreQuant.devig_power(odds)

# 2. Fractional Kelly bankroll sizing (default quarter-Kelly, fraction: 0.25)
stake = AsianscoreQuant.kelly_fraction(fair_power[0], 1.95, fraction: 0.25)

# 3. Dixon-Coles low-score adjusted bivariate Poisson probabilities
probs = AsianscoreQuant.dixon_coles_probs(1.65, 1.15, rho: -0.08)
# => { home_win: ..., draw: ..., away_win: ..., over_2_5: ..., btts: ... }

# 4. Multi-class Brier score calibration evaluation
brier = AsianscoreQuant.brier_score([probs[:home_win], probs[:draw], probs[:away_win]], 0)

# 5. Fetch live fixtures and SHA-256 verifiable ledger summary
summary = AsianscoreQuant.fetch_live_summary
puts "Settled: #{summary.dig('ledger', 'settled')}, Avg Brier: #{summary.dig('ledger', 'avgBrier')}"
```

## API Reference

- `AsianscoreQuant.devig_multiplicative(odds)` — Proportional implied probability normalization.
- `AsianscoreQuant.devig_power(odds)` — Power-law overround removal via binary search solver for $\sum (1/o_i)^k = 1$.
- `AsianscoreQuant.kelly_fraction(prob, decimal_odds, fraction: 0.25)` — Clamped fractional Kelly criterion stake sizing.
- `AsianscoreQuant.dixon_coles_probs(lambda_home, lambda_away, rho: -0.08)` — Full bivariate Poisson grid with Dixon-Coles $\tau$ low-score adjustment returning `:home_win`, `:draw`, `:away_win`, `:over_2_5`, and `:btts`.
- `AsianscoreQuant.brier_score(probs, actual_index)` — Multi-class Brier score (`(1/N) * sum((p_i - y_i)^2)`).
- `AsianscoreQuant.fetch_live_summary` — Pure stdlib (`net/http` + `json`) client for `https://asianscore.com/api/widget/summary`.

## Ecosystem & References

- **AsianScore Platform**: [https://asianscore.com/](https://asianscore.com/)
- **Interactive Quant Calculators**: [https://asianscore.com/tools.html](https://asianscore.com/tools.html)
- **SHA-256 Verifiable Prediction Ledger**: [https://asianscore.com/models.html#ledger](https://asianscore.com/models.html#ledger)
- **Zenodo Dataset DOI**: [https://doi.org/10.5281/zenodo.24441036](https://doi.org/10.5281/zenodo.24441036)
- **Python SDK (PyPI)**: [https://pypi.org/project/asianscore-quant/](https://pypi.org/project/asianscore-quant/)
- **Web Widget (npm)**: [https://www.npmjs.com/package/asianscore-widget](https://www.npmjs.com/package/asianscore-widget)
- **Documentation (Read the Docs)**: [https://asianscore-quant.readthedocs.io/en/latest/](https://asianscore-quant.readthedocs.io/en/latest/)
- **Go SDK (pkg.go.dev)**: [https://pkg.go.dev/github.com/AIYIXIU/asianscore-go](https://pkg.go.dev/github.com/AIYIXIU/asianscore-go)

## License

MIT License. See [LICENSE](LICENSE) for details.
