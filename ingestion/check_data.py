from pathlib import Path
import pandas as pd
import requests
from dotenv import load_dotenv
import os
load_dotenv()
api_key= os.getenv("api_key")
from sqlglot.expressions import Count
Raw_xlsx = Path("Sources/raw_sales_export.xlsx")
Raw_xlsx_2 = Path("Sources/raw_sales_export_v2.xlsx")
DUCKDB     = Path("warehouse/northwind.duckdb")
FX_BASE    = "https://api.frankfurter.dev/v2/rates"
COUNTRIES  = "https://restcountries.com/countries/v5"

def load_Data(path , skip_rows = 0) -> pd.DataFrame:
        return pd.read_excel(path , skiprows=skip_rows)          

FX_response = requests.get(FX_BASE)
if FX_response.status_code == 200 :
    FX_Data = FX_response.json()

params = {"api_key":api_key }
Countries_response =  requests.get(COUNTRIES , params=params)
if Countries_response.status_code == 200 :
    Countries_Data = Countries_response.json()

def data_overview(Data):
    print("first 5 rows of data:")
    print(Data.head(5))     
    print("-" * 50 )
    print("Data info:")
    print(Data.info())
    print("-" * 50)
    print("Data Describe:")
    print(Data.describe())
    print("-" * 50)
    print("checking null:")
    print(Data.isnull().sum())
    print("-" * 50)
    print("checking duplicates:")
    print(Data.duplicated().sum())
    print("-" * 50)
    print("checking unique")
    print(Data["Order ID"].nunique())
    print("=" * 50)

def check_Column(Data):
    rows = []
    for column in Data.columns:
        col = Data[column]
        sample_vals = col.dropna().unique()[:5].tolist()
        rows.append({
            "Column": column,
            "Type": col.dtype,
            "Nulls": col.isnull().sum(),
            "Nulls %": round(col.isnull().mean() * 100, 1),
            "Duplicates": col.duplicated().sum(),
            "Unique": col.nunique(),
            "Sample Values": sample_vals,
        })
    details = pd.DataFrame(rows)
    print(details.to_string(index=False))
    return details

df_raw = load_Data(Raw_xlsx ,3)
df_raw_2 = load_Data(Raw_xlsx_2  , 3)
# data_overview(df_raw)
# data_overview(df_raw_2)
# check_Column(df_raw)
# check_Column(df_raw_2)
