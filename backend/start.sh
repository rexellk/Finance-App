#!/bin/bash
# Start the Finance Simulator API server
cd "$(dirname "$0")"
uvicorn api:app --host 127.0.0.1 --port 8000 --reload
