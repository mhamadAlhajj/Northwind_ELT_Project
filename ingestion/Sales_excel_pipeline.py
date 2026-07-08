from pathlib import Path
import pandas as pd
import duckdb
import dlt


Raw_xlsx = Path("Sources/raw_sales_export.xlsx")
Raw_xlsx_2 = Path("Sources/raw_sales_export_v2.xlsx")
DB_PATH = Path("warehouse/northwind.duckdb")


def fix_mojibake(value):
    if not isinstance(value, str):
        return value
    try:
        return value.encode("cp1252").decode("utf-8").strip()
    except (UnicodeDecodeError, UnicodeEncodeError):
        return value.strip()


SALES_COLUMNS = {
    "Order ID": {"data_type": "text"},
    "Order Date": {"data_type": "text"},
    "Ship Date": {"data_type": "text"},
    "Customer ID": {"data_type": "text"},
    "Customer Name": {"data_type": "text"},
    "Country": {"data_type": "text"},
    "Segment": {"data_type": "text"},
    "Product ID": {"data_type": "text"},
    "Product Name": {"data_type": "text"},
    "Category": {"data_type": "text"},
    "Quantity": {"data_type": "text"},
    "Unit Price": {"data_type": "text"},
    "Discount": {"data_type": "text"},
    "Amount": {"data_type": "text"},
    "Currency": {"data_type": "text"},
    "Sales Rep": {"data_type": "text"},
    "Order Channel": {"data_type": "text"},
    "Tax": {"data_type": "text"},
}


@dlt.resource(
    name="sales",
    write_disposition="append",
    columns=SALES_COLUMNS,
)
def load_data(path, skip_rows=0):
    df = pd.read_excel(path, skiprows=skip_rows,dtype=str)
    df.columns = df.columns.str.strip()
    df = df.rename(columns={"Total Amount": "Amount"})
    df = df.dropna(subset=["Order ID"])
    df["Customer Name"] = df["Customer Name"].apply(fix_mojibake)
    df["Product Name"] = df["Product Name"].apply(fix_mojibake)
    df["Country"] = df["Country"].apply(fix_mojibake)
    yield from df.to_dict(orient="records")




def run_pipeline():
    print("Starting Sales Excel pipeline...")
    pipeline = dlt.pipeline(
        pipeline_name="Sales_Excel_pipeline",
        destination=dlt.destinations.duckdb("warehouse/northwind.duckdb"),
        dataset_name="raw",
    )

    version_before = pipeline.default_schema.version if pipeline.default_schema_name else 0

    load_info = pipeline.run([load_data(Raw_xlsx, 3), load_data(Raw_xlsx_2, 3)])

    version_after = pipeline.default_schema.version
    if version_after != version_before:
        print(f"Schema changed! version {version_before} -> {version_after}")
        print("New or modified columns detected — check raw.sales before trusting downstream models.")
    else:
        print(f"Schema unchanged (version {version_after})")

    print("Pipeline completed successfully!")
    print(f"Load info: {load_info}")
    return load_info

if __name__ == "__main__":
    run_pipeline()
