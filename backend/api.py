import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
from block_bootstrap import run_full_simulation, CSV_MAP

app = FastAPI(title="Finance Simulator API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class SimulationRequest(BaseModel):
    tickers: list[str]
    weights: dict[str, float]
    n_years: int = 10
    initial_value: float = 10_000.0
    account_type: str = "brokerage"
    tax_rate: float = 0.20
    n_simulations: int = 1_000
    force_refresh: bool = False


class SimulationResponse(BaseModel):
    percentiles: dict[str, float]
    cagr: dict[str, float]
    multiples: dict[str, float]
    prob_profit: float
    prob_double: float
    worst_case: float
    best_case: float
    cone: dict[str, list[float]]
    year_labels: list[int]
    n_years: int
    initial_value: float


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/tickers")
def get_tickers():
    return {"tickers": list(CSV_MAP.keys())}


@app.post("/simulate", response_model=SimulationResponse)
def simulate(req: SimulationRequest):
    try:
        results = run_full_simulation(
            tickers=req.tickers,
            weights=req.weights,
            n_years=req.n_years,
            initial_value=req.initial_value,
            account_type=req.account_type,
            tax_rate=req.tax_rate,
            n_simulations=req.n_simulations,
            force_refresh=req.force_refresh,
        )
        summary = results["summary"]

        # Downsample cone to ~12 points per year for fast transfer
        cone_raw = summary["cone"]
        n_days = req.n_years * 252
        sample_count = req.n_years * 12
        indices = np.linspace(0, n_days - 1, sample_count, dtype=int)

        cone_sampled = {
            str(k): [float(cone_raw[k][i]) for i in indices]
            for k in cone_raw
        }

        return SimulationResponse(
            percentiles={str(k): float(v) for k, v in summary["percentiles"].items()},
            cagr={str(k): float(v) for k, v in summary["cagr"].items()},
            multiples={str(k): float(v) for k, v in summary["multiples"].items()},
            prob_profit=float(summary["prob_profit"]),
            prob_double=float(summary["prob_double"]),
            worst_case=float(summary["worst_case"]),
            best_case=float(summary["best_case"]),
            cone=cone_sampled,
            year_labels=[int(y) for y in results["year_labels"]],
            n_years=req.n_years,
            initial_value=req.initial_value,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
