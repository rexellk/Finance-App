from block_bootstrap import run_full_simulation

# ---------------------------------------------------------------------------
# Portfolio to simulate
# ---------------------------------------------------------------------------

tickers = ["QQQ", "GDX", "BTC-USD", "ETH-USD"]

weights = {
    "QQQ":     0.60,   # 60% tech-heavy equities (Nasdaq-100)
    "GDX":     0.20,   # 20% gold miners (inflation hedge)
    "BTC-USD": 0.15,   # 15% Bitcoin
    "ETH-USD": 0.05,   # 5%  Ethereum
}

results = run_full_simulation(
    tickers=tickers,
    weights=weights,
    n_years=10,
    initial_value=25_000.0,
    account_type="brokerage",
    tax_rate=0.20,
    n_simulations=10_000,
)
