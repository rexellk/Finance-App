import pandas as pd
import numpy as np
import os
import pickle
from datetime import datetime, timedelta
from pathlib import Path

# ---------------------------------------------------------------------------
# CSV paths - update these if you move the files
# ---------------------------------------------------------------------------

_SCRIPT_DIR = Path(__file__).parent

CSV_MAP = {
    "QQQ":     _SCRIPT_DIR / "csvData" / "qqq_us_d.csv",
    "GDX":     _SCRIPT_DIR / "csvData" / "gdx_us_d.csv",
    "BTC-USD": _SCRIPT_DIR / "csvData" / "btc_v_d.csv",
    "ETH-USD": _SCRIPT_DIR / "csvData" / "eth_v_d.csv",
}

# ---------------------------------------------------------------------------
# CSV loader
# ---------------------------------------------------------------------------

def _load_csv(ticker: str, csv_path: Path) -> pd.Series | None:
    """
    Reads a CSV with columns [Date, Open, High, Low, Close, Volume].
    Returns a pd.Series of Close prices indexed by datetime.
    """
    if not csv_path.exists():
        print(f"  WARNING: CSV not found for {ticker}: {csv_path}")
        return None

    df = pd.read_csv(csv_path, parse_dates=["Date"], index_col="Date")
    df.index = pd.to_datetime(df.index, utc=False)
    df.index.name = "Date"

    if "Close" not in df.columns:
        print(f"  WARNING: No 'Close' column in {csv_path}")
        return None

    series = df["Close"].sort_index().dropna()
    print(f"  {ticker}: {len(series)} days loaded from {csv_path.name} "
          f"({series.index[0].date()} to {series.index[-1].date()})")
    return series


def fetch_historical_returns(tickers: list[str]) -> pd.DataFrame:
    """
    Loads daily returns for each ticker directly from local CSV files.
    Always reads fresh - no caching. Drop in an updated CSV and re-run.

    tickers:  list of ticker symbols matching keys in CSV_MAP
    returns:  DataFrame where each column is a ticker,
              each row is a daily return (decimal, e.g. 0.01 = 1%)
    """
    print("Reading CSVs...")
    all_prices: dict[str, pd.Series] = {}

    for ticker in tickers:
        if ticker not in CSV_MAP:
            print(f"  WARNING: No CSV mapping for '{ticker}', skipping.")
            continue

        series = _load_csv(ticker, CSV_MAP[ticker])
        if series is not None and not series.empty:
            all_prices[ticker] = series

    if not all_prices:
        raise RuntimeError(
            "Could not load any ticker data. Check your CSV paths in CSV_MAP."
        )

    prices = pd.DataFrame(all_prices)

    # align on shared dates, forward-fill any isolated gaps (holidays / weekends)
    prices = prices.sort_index().ffill()

    daily_returns = prices.pct_change().dropna()
    daily_returns = daily_returns.clip(lower=-0.99, upper=5.0)

    loaded = list(daily_returns.columns)
    skipped = [t for t in tickers if t not in loaded]
    print(f"\nLoaded {len(daily_returns)} trading days for: {loaded}")
    if skipped:
        print(f"Skipped (no CSV): {skipped}")

    return daily_returns


# ---------------------------------------------------------------------------
# Bootstrap cache helpers (kept only here where it matters)
# ---------------------------------------------------------------------------

CACHE_DIR = "data_cache"
CACHE_EXPIRY_DAYS = 7


def _get_bootstrap_cache_path(tickers: list[str], block_size: int, n_simulations: int) -> str:
    tickers_key = "_".join(sorted(tickers))
    return os.path.join(CACHE_DIR, f"bootstrap_{tickers_key}_b{block_size}_n{n_simulations}.pkl")


def _load_bootstrap_cache(cache_path: str):
    if not os.path.exists(cache_path):
        return None

    modified_time = datetime.fromtimestamp(os.path.getmtime(cache_path))
    age = datetime.now() - modified_time

    if age < timedelta(days=CACHE_EXPIRY_DAYS):
        days_old = age.days
        hours_old = age.seconds // 3600
        print(f"Loading bootstrap from cache (age: {days_old}d {hours_old}h | expires in {CACHE_EXPIRY_DAYS - days_old}d)")
        with open(cache_path, "rb") as f:
            return pickle.load(f)

    print(f"Bootstrap cache expired ({age.days} days old), re-running...")
    return None


def _save_bootstrap_cache(cache_path: str, data) -> None:
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(cache_path, "wb") as f:
        pickle.dump(data, f)
    print(f"Bootstrap saved to cache: {cache_path}")


# ---------------------------------------------------------------------------
# Block bootstrap
# ---------------------------------------------------------------------------

def block_bootstrap(
    returns: pd.DataFrame,
    block_size: int = 20,
    n_simulations: int = 10000,
    force_refresh: bool = False,
) -> tuple[np.ndarray, list[int]]:
    """
    Stratified block bootstrap - resamples within each calendar year separately.
    Preserves market regime character (bull/bear) per year.
    Cached for 7 days since this takes 30-60s to run.
    Use force_refresh=True to re-run the simulation regardless of cache.

    returns:       DataFrame of daily returns with DatetimeIndex
    block_size:    consecutive days per block (20 = ~1 trading month)
    n_simulations: how many simulated futures to generate
    force_refresh: if True, ignores cache and re-runs simulation

    returns: tuple of:
        simulated   - 3D array of shape (n_simulations, n_years * 252, n_tickers)
        year_labels - list of years covered
    """
    cache_path = _get_bootstrap_cache_path(
        returns.columns.tolist(), block_size, n_simulations
    )

    if not force_refresh:
        cached = _load_bootstrap_cache(cache_path)
        if cached is not None:
            simulated, year_labels = cached
            print(f"Shape: {simulated.shape}, years: {year_labels}")
            return simulated, year_labels

    trading_days_per_year = 252

    years = returns.groupby(returns.index.year)
    year_labels = sorted(years.groups.keys())

    print(f"Found years: {year_labels}")

    year_arrays = {}
    for year in year_labels:
        year_data = years.get_group(year).values

        if len(year_data) < block_size:
            print(f"  {year}: only {len(year_data)} days (< block_size {block_size}), skipping.")
            continue

        year_arrays[year] = year_data
        print(f"  {year}: {len(year_data)} trading days")

    year_labels = sorted(year_arrays.keys())

    if not year_labels:
        raise ValueError("No valid years remaining after filtering partial years.")

    n_years = len(year_labels)
    n_tickers = returns.shape[1]
    simulated = np.zeros((n_simulations, n_years * trading_days_per_year, n_tickers))

    for sim in range(n_simulations):
        sim_returns = []

        for year in year_labels:
            year_data = year_arrays[year]
            n_days_in_year = len(year_data)
            valid_starts = np.arange(0, n_days_in_year - block_size + 1)

            days_filled = 0
            year_sim = []

            while days_filled < trading_days_per_year:
                start = np.random.choice(valid_starts)
                block = year_data[start: start + block_size]
                year_sim.append(block)
                days_filled += block_size

            year_sim = np.vstack(year_sim)[:trading_days_per_year]
            sim_returns.append(year_sim)

        simulated[sim] = np.vstack(sim_returns)

    print(f"\nGenerated {n_simulations} simulations")
    print(f"Each simulation: {n_years} years x {trading_days_per_year} days = {n_years * trading_days_per_year} total days")

    _save_bootstrap_cache(cache_path, (simulated, year_labels))
    return simulated, year_labels

def simulate_portfolio(
    simulated: np.ndarray,
    weights: dict[str, float],
    ticker_order: list[str],
    n_years: int,
    initial_value: float = 10_000.0,
) -> np.ndarray:
    """
    Compounds portfolio value across all simulations.

    simulated:     3D array of shape (n_simulations, total_days, n_tickers)
    weights:       dict mapping ticker to allocation e.g. {"QQQ": 0.5, "BTC-USD": 0.5}
                   must sum to 1.0
    ticker_order:  pass returns.columns.tolist() from fetch_historical_returns()
    n_years:       how many years forward to simulate
    initial_value: starting portfolio value in dollars

    returns:       2D array of shape (n_simulations, n_years * 252)
    """
    total_weight = sum(weights.values())
    if not np.isclose(total_weight, 1.0, atol=1e-6):
        raise ValueError(f"Weights must sum to 1.0, got {total_weight:.6f}")

    for ticker in weights:
        if ticker not in ticker_order:
            raise ValueError(f"'{ticker}' not in ticker_order: {ticker_order}")

    weight_vector = np.array([weights.get(t, 0.0) for t in ticker_order])

    n_simulations, total_days, n_tickers = simulated.shape
    n_days = n_years * 252
    available_years = total_days // 252

    if n_days > total_days:
        # Resample years with replacement to cover the requested horizon.
        # Each simulation independently draws from the available year pool,
        # so long-horizon paths stay statistically independent.
        year_blocks = simulated[:, :available_years * 252, :].reshape(
            n_simulations, available_years, 252, n_tickers
        )
        year_indices = np.random.randint(0, available_years, size=(n_simulations, n_years))
        extended = year_blocks[np.arange(n_simulations)[:, None], year_indices]
        simulated = extended.reshape(n_simulations, n_years * 252, n_tickers)
        print(f"Extended {available_years}-year history to {n_years} years via year-block resampling")

    returns_slice = simulated[:, :n_days, :]
    daily_portfolio_returns = returns_slice @ weight_vector
    growth_factors = 1.0 + daily_portfolio_returns
    cumulative = np.cumprod(growth_factors, axis=1)
    portfolio_values = initial_value * cumulative

    print(f"Simulated {n_simulations} portfolios over {n_years} years")
    print(f"Median final value: ${np.median(portfolio_values[:, -1]):,.0f}")
    print(f"10th percentile:    ${np.percentile(portfolio_values[:, -1], 10):,.0f}")
    print(f"90th percentile:    ${np.percentile(portfolio_values[:, -1], 90):,.0f}")

    return portfolio_values


def apply_tax_wrapper(
    portfolio_values: np.ndarray,
    account_type: str,
    tax_rate: float,
    initial_value: float = 10_000.0,
) -> np.ndarray:
    """
    Adjusts portfolio values based on account tax treatment.

    portfolio_values: 2D array of shape (n_simulations, n_days)
    account_type:     "brokerage" | "roth" | "401k"
    tax_rate:         decimal e.g. 0.25 = 25%
    initial_value:    must match what was passed to simulate_portfolio()

    returns:          2D array same shape as portfolio_values with after-tax values
    """
    valid_account_types = ("brokerage", "roth", "401k")
    if account_type not in valid_account_types:
        raise ValueError(f"account_type must be one of {valid_account_types}, got '{account_type}'")

    if not 0.0 <= tax_rate < 1.0:
        raise ValueError(f"tax_rate must be between 0.0 and 1.0, got {tax_rate}")

    if account_type == "roth":
        after_tax = portfolio_values.copy()
    elif account_type == "brokerage":
        gains = np.maximum(portfolio_values - initial_value, 0.0)
        after_tax = portfolio_values - gains * tax_rate
    else:  # 401k
        after_tax = portfolio_values * (1.0 - tax_rate)

    final_values = after_tax[:, -1]
    print(f"Account type:       {account_type}")
    print(f"Tax rate:           {tax_rate * 100:.1f}%")
    print(f"Median (after-tax): ${np.median(final_values):,.0f}")
    print(f"10th percentile:    ${np.percentile(final_values, 10):,.0f}")
    print(f"90th percentile:    ${np.percentile(final_values, 90):,.0f}")

    return after_tax


def run_full_simulation(
    tickers: list[str],
    weights: dict[str, float],
    n_years: int,
    initial_value: float = 10_000.0,
    account_type: str = "brokerage",
    tax_rate: float = 0.20,
    block_size: int = 20,
    n_simulations: int = 10_000,
    force_refresh: bool = False,
) -> dict:
    """
    Orchestrates the full pipeline in one call:
    fetch -> bootstrap -> simulate_portfolio -> apply_tax_wrapper -> summarize_results

    tickers:        list of ticker symbols matching keys in CSV_MAP
    weights:        dict mapping ticker to allocation e.g. {"QQQ": 0.6, "BTC-USD": 0.4}
                    must sum to 1.0
    n_years:        how many years forward to simulate
    initial_value:  starting portfolio value in dollars
    account_type:   "brokerage", "roth", or "401k"
    tax_rate:       decimal tax rate e.g. 0.20 = 20%
    block_size:     consecutive days per bootstrap block (default 20 = ~1 month)
    n_simulations:  number of simulated futures (default 10,000)
    force_refresh:  if True, re-runs bootstrap even if cache is fresh

    returns: dict with keys:
        "returns"          -> raw daily returns DataFrame
        "simulated"        -> 3D bootstrap array (n_simulations, total_days, n_tickers)
        "year_labels"      -> list of years covered by bootstrap
        "portfolio_values" -> 2D pre-tax values (n_simulations, n_days)
        "after_tax_values" -> 2D after-tax values (n_simulations, n_days)
        "summary"          -> percentile summary dict from summarize_results()
    """
    print("=" * 60)
    print(f"FULL SIMULATION: {n_years}yr | {account_type} | {tax_rate*100:.0f}% tax")
    print(f"Portfolio: {weights}")
    print(f"Initial:   ${initial_value:,.0f}")
    print("=" * 60)

    # step 1: load returns from CSVs
    returns = fetch_historical_returns(tickers)

    # step 2: bootstrap
    simulated, year_labels = block_bootstrap(
        returns,
        block_size=block_size,
        n_simulations=n_simulations,
        force_refresh=force_refresh,
    )

    # step 3: compound portfolio growth
    portfolio_values = simulate_portfolio(
        simulated=simulated,
        weights=weights,
        ticker_order=returns.columns.tolist(),
        n_years=n_years,
        initial_value=initial_value,
    )

    # step 4: apply tax treatment
    after_tax_values = apply_tax_wrapper(
        portfolio_values=portfolio_values,
        account_type=account_type,
        tax_rate=tax_rate,
        initial_value=initial_value,
    )

    # step 5: summarize
    summary = summarize_results(after_tax_values, initial_value=initial_value, n_years=n_years)

    return {
        "returns":          returns,
        "simulated":        simulated,
        "year_labels":      year_labels,
        "portfolio_values": portfolio_values,
        "after_tax_values": after_tax_values,
        "summary":          summary,
    }


def summarize_results(
    after_tax_values: np.ndarray,
    initial_value: float = 10_000.0,
    n_years: int | None = None,
) -> dict:
    """
    Outputs a percentile cone and key stats from after-tax portfolio values.

    after_tax_values: 2D array of shape (n_simulations, n_days)
                      output directly from apply_tax_wrapper()
    initial_value:    starting portfolio value, used to compute CAGR and multiples
    n_years:          used to compute annualized returns, inferred from n_days if None

    returns: dict with keys:
        "percentiles"    -> dict of {pct: final_value} for 10,25,50,75,90
        "cone"           -> dict of {pct: array of shape (n_days,)} full time series
        "cagr"           -> dict of {pct: annualized_return} for 10,25,50,75,90
        "multiples"      -> dict of {pct: final_value / initial_value}
        "prob_profit"    -> probability of ending above initial_value
        "prob_double"    -> probability of ending above 2x initial_value
        "worst_case"     -> 5th percentile final value
        "best_case"      -> 95th percentile final value
    """
    n_simulations, n_days = after_tax_values.shape
    years = n_years if n_years is not None else n_days / 252

    percentile_levels = [10, 25, 50, 75, 90]
    final_values = after_tax_values[:, -1]

    # percentile final values
    percentiles = {
        p: float(np.percentile(final_values, p))
        for p in percentile_levels
    }

    # full time series cone - one curve per percentile across all days
    cone = {
        p: np.percentile(after_tax_values, p, axis=0)
        for p in percentile_levels
    }

    # CAGR: (final / initial) ^ (1 / years) - 1
    cagr = {
        p: float((percentiles[p] / initial_value) ** (1.0 / years) - 1.0)
        for p in percentile_levels
    }

    # simple multiples: final / initial
    multiples = {
        p: float(percentiles[p] / initial_value)
        for p in percentile_levels
    }

    prob_profit = float(np.mean(final_values > initial_value))
    prob_double = float(np.mean(final_values > 2.0 * initial_value))
    worst_case  = float(np.percentile(final_values, 5))
    best_case   = float(np.percentile(final_values, 95))

    # print summary table
    print("\n" + "=" * 60)
    print(f"RESULTS SUMMARY  ({years:.0f} years | ${initial_value:,.0f} initial)")
    print("=" * 60)
    print(f"{'Percentile':<14} {'Final Value':>12} {'Multiple':>10} {'CAGR':>8}")
    print("-" * 60)
    labels = {10: "10th (bad)", 25: "25th", 50: "50th (median)", 75: "75th", 90: "90th (great)"}
    for p in percentile_levels:
        print(f"  {labels[p]:<12} ${percentiles[p]:>11,.0f} {multiples[p]:>9.1f}x {cagr[p]:>7.1%}")
    print("-" * 60)
    print(f"  Worst case (5th):   ${worst_case:>10,.0f}")
    print(f"  Best case  (95th):  ${best_case:>10,.0f}")
    print(f"  Prob of profit:     {prob_profit:>9.1%}")
    print(f"  Prob of 2x:         {prob_double:>9.1%}")
    print("=" * 60)

    return {
        "percentiles": percentiles,
        "cone":        cone,
        "cagr":        cagr,
        "multiples":   multiples,
        "prob_profit": prob_profit,
        "prob_double": prob_double,
        "worst_case":  worst_case,
        "best_case":   best_case,
    }