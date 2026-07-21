"""Run the whole pipeline in one go.

Load the three sources with dlt, then build and test the dbt models.
Run it from the project root:  python run_pipeline.py
"""

import subprocess
import sys

STEPS = [
    ("1. Load sales from the Excel files", [sys.executable, "ingestion/Sales_excel_pipeline.py"], "."),
    ("2. Load FX rates from Frankfurter", [sys.executable, "ingestion/fx_api_pipeline.py"], "."),
    ("3. Load the country reference data", [sys.executable, "ingestion/countries_pipeline.py"], "."),
    ("4. Build and test the dbt models", ["dbt", "build"], "Transformation"),
]

for name, command, folder in STEPS:
    print(f"\n===== {name} =====\n")
    # check=True stops the whole script if a step fails,
    # so dbt never builds models on top of a broken load.
    subprocess.run(command, cwd=folder, check=True)

print("\nDone. Everything is in warehouse/northwind.duckdb")
