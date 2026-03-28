import sys
import numpy as np
from block_bootstrap import (
    fetch_historical_returns,
    block_bootstrap,
    simulate_portfolio,
    apply_tax_wrapper,
    run_full_simulation,
    summarize_results,
)

tickers = ["QQQ", "GDX", "BTC-USD", "ETH-USD"]
weights = {"QQQ": 0.60, "GDX": 0.20, "BTC-USD": 0.15, "ETH-USD": 0.05}
INITIAL = 10_000.0


# ---------------------------------------------------------------------------
# fetch_historical_returns
# ---------------------------------------------------------------------------

def test_shape_sort_no_nans():
    returns = fetch_historical_returns(tickers)
    assert returns.shape[1] == 4
    assert (returns.index == returns.index.sort_values()).all()
    assert returns.isnull().sum().sum() == 0
    print("TEST 1 passed: shape, sort, no NaNs")

def test_return_magnitudes():
    returns = fetch_historical_returns(tickers)
    assert returns.abs().max().max() < 5.0
    assert returns.abs().mean().max() < 0.05
    print("TEST 2 passed: return magnitudes look sane")

def test_bad_ticker_skipped():
    partial = fetch_historical_returns(["QQQ", "FAKE-TICKER"])
    assert "QQQ" in partial.columns
    assert "FAKE-TICKER" not in partial.columns
    print("TEST 3 passed: bad ticker skipped cleanly")


# ---------------------------------------------------------------------------
# block_bootstrap
# ---------------------------------------------------------------------------

def test_bootstrap_shape():
    returns = fetch_historical_returns(tickers)
    simulated, year_labels = block_bootstrap(returns, block_size=20, n_simulations=100, force_refresh=True)
    n_years = len(year_labels)
    assert simulated.shape == (100, n_years * 252, 4)
    print(f"TEST 4 passed: bootstrap shape {simulated.shape}")

def test_bootstrap_values():
    returns = fetch_historical_returns(tickers)
    simulated, _ = block_bootstrap(returns, block_size=20, n_simulations=100, force_refresh=True)
    assert simulated.max() < 5.0
    assert simulated.min() > -1.0
    print("TEST 5 passed: bootstrap values are valid returns")


# ---------------------------------------------------------------------------
# simulate_portfolio
# ---------------------------------------------------------------------------

def test_portfolio_output_shape():
    returns = fetch_historical_returns(tickers)
    simulated, _ = block_bootstrap(returns, n_simulations=100, force_refresh=True)
    portfolio_values = simulate_portfolio(simulated, weights, returns.columns.tolist(), n_years=5, initial_value=INITIAL)
    assert portfolio_values.shape == (100, 5 * 252), f"unexpected shape: {portfolio_values.shape}"
    print(f"TEST 6 passed: portfolio shape {portfolio_values.shape}")

def test_portfolio_weights_must_sum_to_one():
    returns = fetch_historical_returns(tickers)
    simulated, _ = block_bootstrap(returns, n_simulations=100, force_refresh=True)
    bad_weights = {"QQQ": 0.50, "GDX": 0.20, "BTC-USD": 0.15, "ETH-USD": 0.05}  # sums to 0.9
    try:
        simulate_portfolio(simulated, bad_weights, returns.columns.tolist(), n_years=5)
        assert False, "should have raised ValueError"
    except ValueError:
        pass
    print("TEST 8 passed: bad weights rejected")

def test_portfolio_invalid_ticker_rejected():
    returns = fetch_historical_returns(tickers)
    simulated, _ = block_bootstrap(returns, n_simulations=100, force_refresh=True)
    bad_weights = {"QQQ": 0.60, "FAKE": 0.40}
    try:
        simulate_portfolio(simulated, bad_weights, returns.columns.tolist(), n_years=5)
        assert False, "should have raised ValueError"
    except ValueError:
        pass
    print("TEST 9 passed: unknown ticker in weights rejected")

def test_portfolio_n_years_too_large():
    returns = fetch_historical_returns(tickers)
    simulated, year_labels = block_bootstrap(returns, n_simulations=100, force_refresh=True)
    max_years = len(year_labels)
    extended_years = max_years + 99
    pv = simulate_portfolio(simulated, weights, returns.columns.tolist(), n_years=extended_years)
    assert pv.shape == (100, extended_years * 252), f"unexpected shape: {pv.shape}"
    print(f"TEST 10 passed: n_years > history resamples correctly to shape {pv.shape}")


# ---------------------------------------------------------------------------
# apply_tax_wrapper
# ---------------------------------------------------------------------------

def _make_portfolio_values(n_sims=100, n_years=5):
    returns = fetch_historical_returns(tickers)
    simulated, _ = block_bootstrap(returns, n_simulations=n_sims, force_refresh=True)
    return simulate_portfolio(simulated, weights, returns.columns.tolist(), n_years=n_years, initial_value=INITIAL)

def test_roth_unchanged():
    pv = _make_portfolio_values()
    after_tax = apply_tax_wrapper(pv, "roth", tax_rate=0.25, initial_value=INITIAL)
    assert np.allclose(after_tax, pv), "roth should not change values"
    print("TEST 11 passed: roth leaves values unchanged")

def test_brokerage_only_taxes_gains():
    pv = _make_portfolio_values()
    after_tax = apply_tax_wrapper(pv, "brokerage", tax_rate=0.20, initial_value=INITIAL)
    # after-tax must always be <= pre-tax
    assert not np.any(after_tax > pv + 1e-6), "after-tax exceeds pre-tax"
    # gains should be reduced by tax rate
    profitable = pv > INITIAL
    if profitable.any():
        assert (after_tax[profitable] < pv[profitable]).all(), "gains not being taxed"
    print("TEST 12 passed: brokerage only taxes gains")

def test_pretax_taxes_everything():
    pv = _make_portfolio_values()
    after_tax = apply_tax_wrapper(pv, "401k", tax_rate=0.25, initial_value=INITIAL)
    expected = pv * 0.75
    assert np.allclose(after_tax, expected), "401k should be value * (1 - tax_rate)"
    print("TEST 13 passed: 401k taxes full withdrawal")

def test_tax_invalid_account_type():
    pv = _make_portfolio_values()
    try:
        apply_tax_wrapper(pv, "tfsa", tax_rate=0.20, initial_value=INITIAL)
        assert False, "should have raised ValueError"
    except ValueError:
        pass
    print("TEST 14 passed: invalid account type rejected")

def test_tax_rate_out_of_range():
    pv = _make_portfolio_values()
    try:
        apply_tax_wrapper(pv, "brokerage", tax_rate=1.5, initial_value=INITIAL)
        assert False, "should have raised ValueError"
    except ValueError:
        pass
    print("TEST 15 passed: tax rate >= 1.0 rejected")


# ---------------------------------------------------------------------------
# summarize_results
# ---------------------------------------------------------------------------

def test_summary_keys_present():
    pv = _make_portfolio_values()
    after_tax = apply_tax_wrapper(pv, "brokerage", tax_rate=0.20, initial_value=INITIAL)
    summary = summarize_results(after_tax, initial_value=INITIAL, n_years=5)
    required_keys = {"percentiles", "cone", "cagr", "multiples", "prob_profit", "prob_double", "worst_case", "best_case"}
    assert required_keys == set(summary.keys()), f"missing keys: {required_keys - set(summary.keys())}"
    print("TEST 16 passed: summary has all required keys")

def test_summary_percentile_ordering():
    pv = _make_portfolio_values()
    after_tax = apply_tax_wrapper(pv, "brokerage", tax_rate=0.20, initial_value=INITIAL)
    summary = summarize_results(after_tax, initial_value=INITIAL, n_years=5)
    p = summary["percentiles"]
    assert p[10] < p[25] < p[50] < p[75] < p[90], "percentiles not in order"
    print("TEST 17 passed: percentiles are ordered correctly")

def test_summary_probabilities_in_range():
    pv = _make_portfolio_values()
    after_tax = apply_tax_wrapper(pv, "brokerage", tax_rate=0.20, initial_value=INITIAL)
    summary = summarize_results(after_tax, initial_value=INITIAL, n_years=5)
    assert 0.0 <= summary["prob_profit"] <= 1.0
    assert 0.0 <= summary["prob_double"] <= 1.0
    assert summary["prob_double"] <= summary["prob_profit"], "prob_double can't exceed prob_profit"
    print("TEST 18 passed: probabilities are valid")

def test_summary_cone_shape():
    pv = _make_portfolio_values(n_sims=100, n_years=5)
    after_tax = apply_tax_wrapper(pv, "brokerage", tax_rate=0.20, initial_value=INITIAL)
    summary = summarize_results(after_tax, initial_value=INITIAL, n_years=5)
    for p, curve in summary["cone"].items():
        assert curve.shape == (5 * 252,), f"cone[{p}] shape mismatch: {curve.shape}"
    print("TEST 19 passed: cone curves have correct shape")

# ---------------------------------------------------------------------------
# run_full_simulation
# ---------------------------------------------------------------------------

def test_full_simulation_returns_all_keys():
    results = run_full_simulation(
        tickers=tickers, weights=weights, n_years=5,
        initial_value=INITIAL, account_type="brokerage",
        tax_rate=0.20, n_simulations=100, force_refresh=True,
    )
    expected_keys = {"returns", "simulated", "year_labels", "portfolio_values", "after_tax_values", "summary"}
    assert expected_keys == set(results.keys())
    print("TEST 20 passed: run_full_simulation returns all keys")

def test_full_simulation_shapes_consistent():
    results = run_full_simulation(
        tickers=tickers, weights=weights, n_years=5,
        initial_value=INITIAL, account_type="roth",
        tax_rate=0.0, n_simulations=100, force_refresh=True,
    )
    n_days = 5 * 252
    assert results["portfolio_values"].shape == (100, n_days)
    assert results["after_tax_values"].shape == (100, n_days)
    print("TEST 21 passed: portfolio and after-tax shapes consistent")

def test_full_simulation_roth_matches_portfolio():
    results = run_full_simulation(
        tickers=tickers, weights=weights, n_years=5,
        initial_value=INITIAL, account_type="roth",
        tax_rate=0.0, n_simulations=100, force_refresh=True,
    )
    assert np.allclose(results["portfolio_values"], results["after_tax_values"])
    print("TEST 22 passed: roth with 0% tax matches pre-tax values")


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    tests = [
        test_shape_sort_no_nans,
        test_return_magnitudes,
        test_bad_ticker_skipped,
        test_bootstrap_shape,
        test_bootstrap_values,
        test_portfolio_output_shape,
        test_portfolio_weights_must_sum_to_one,
        test_portfolio_invalid_ticker_rejected,
        test_portfolio_n_years_too_large,
        test_roth_unchanged,
        test_brokerage_only_taxes_gains,
        test_pretax_taxes_everything,
        test_tax_invalid_account_type,
        test_tax_rate_out_of_range,
        test_summary_keys_present,
        test_summary_percentile_ordering,
        test_summary_probabilities_in_range,
        test_summary_cone_shape,
        test_full_simulation_returns_all_keys,
        test_full_simulation_shapes_consistent,
        test_full_simulation_roth_matches_portfolio,
    ]

    failed = []
    for test in tests:
        try:
            test()
        except AssertionError as e:
            print(f"FAILED {test.__name__}: {e}")
            failed.append(test.__name__)
        except Exception as e:
            print(f"ERROR  {test.__name__}: {e}")
            failed.append(test.__name__)

    print(f"\n{len(tests) - len(failed)}/{len(tests)} tests passed.")
    sys.exit(1 if failed else 0)