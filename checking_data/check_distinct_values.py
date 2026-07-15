import sys
import duckdb

DB_PATH = "warehouse/northwind.duckdb"
TABLE = "main_stg.stg_sales"
# TABLE = 'raw.sales'

def print_distinct(column):
    con = duckdb.connect(DB_PATH, read_only=True)
    rows = con.execute(f"select distinct {column} from {TABLE} order by {column}").fetchall()
    con.close()

    print(f"{len(rows)} distinct values in {TABLE}.{column}")
    for (value, ) in rows:
        print(value)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python check_distinct_values.py <column_name>")
        sys.exit(1)

    print_distinct(sys.argv[1])
