from pathlib import Path
import pandas as pd
import duckdb
import dlt


Raw_xlsx = Path("Sources/raw_sales_export.xlsx")
Raw_xlsx_2 = Path("Sources/raw_sales_export_v2.xlsx")
DB_PATH = Path("warehouse/northwind.duckdb")
@dlt.resource(name="sales", write_disposition="merge", primary_key=["Order ID"])
def load_data(path, skip_rows=0):
    df = pd.read_excel(path, skiprows=skip_rows)
    df.columns = df.columns.str.strip()
    df = df.rename(columns={"Total Amount": "Amount"})
    df = df.dropna(subset=["Order ID"])
    yield from df.to_dict(orient="records")

def run_pipeline():
    print("Starting Sales Excel pipeline...")
    pipeline = dlt.pipeline(
        pipeline_name="Sales_Excel_pipeline",
        destination=dlt.destinations.duckdb("warehouse/northwind.duckdb"),
        dataset_name="raw",
    )

    version_before = pipeline.default_schema.version

    load_info = pipeline.run([load_data(Raw_xlsx, 3), load_data(Raw_xlsx_2, 3)])

    version_after = pipeline.default_schema.version
    if version_after != version_before:
        print(f"Schema changed! version {version_before} → {version_after}")
        print("New or modified columns detected — check raw.sales before trusting downstream models.")
    else:
        print(f"Schema unchanged (version {version_after})")

    print("Pipeline completed successfully!")
    print(f"Load info: {load_info}")
    return load_info

if __name__ == "__main__":
    run_pipeline()
