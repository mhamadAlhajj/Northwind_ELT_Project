from rapidfuzz import process , fuzz
import pandas as pd
import duckdb

DB_PATH = "warehouse/northwind.duckdb"

def get_country_list(path , column = "names__common" , TABLE = "countries"):
    con = duckdb.connect(path, read_only=True)
    rows = con.execute(f"select distinct {column} from raw.{TABLE} order by {column}").fetchall()
    con.close()
    df = pd.DataFrame(rows , columns=["country"])
    print(df)

get_country_list(DB_PATH)