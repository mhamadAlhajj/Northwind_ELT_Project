from pathlib import Path
import pandas as pd
import duckdb

Raw_xlsx = Path("Sources/raw_sales_export.xlsx")
Raw_xlsx_2 = Path("Sources/raw_sales_export_v2.xlsx")
DB_PATH = Path("warehouse/northwind.duckdb")

def load_data(path , skip_rows = 0):
    return pd.read_excel(path , skiprows = skip_rows)

def store_to_duckdb(df, table_name, db_path=DB_PATH):
    with duckdb.connect(str(db_path)) as con:
        con.execute(f"CREATE OR REPLACE TABLE raw.{table_name} AS SELECT * FROM df")

df_raw = load_data(Raw_xlsx ,3)
df_raw_2 = load_data(Raw_xlsx_2  , 3)  

store_to_duckdb(df_raw, "raw_sales_export")
store_to_duckdb(df_raw_2, "raw_sales_export_v2")

