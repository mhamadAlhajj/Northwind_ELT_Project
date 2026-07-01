import duckdb

con = duckdb.connect("warehouse/northwind.duckdb")


def check_fx():
    total = con.execute("SELECT COUNT(*) FROM raw.fx_rates").fetchone()[0]
    print(f"Total rows: {total}\n")

    print("=== First 10 rows ===")
    print(con.execute("SELECT * FROM raw.fx_rates ORDER BY rate_date ASC LIMIT 10").df().to_string(index=False))

    print("\n=== Last 10 rows ===")
    print(con.execute("SELECT * FROM raw.fx_rates ORDER BY rate_date ASC LIMIT 10 OFFSET (SELECT COUNT(*) - 10 FROM raw.fx_rates)").df().to_string(index=False))


def check_sales():
    total = con.execute("SELECT COUNT(*) FROM raw.sales").fetchone()[0]
    print(f"Total rows: {total}\n")

    print("=== First 10 rows ===")
    print(con.execute("SELECT * FROM raw.sales LIMIT 10").df().to_string(index=False))

    print("\n=== Last 10 rows ===")
    print(con.execute("SELECT * FROM raw.sales LIMIT 10 OFFSET (SELECT COUNT(*) - 10 FROM raw.sales)").df().to_string(index=False))


# check_fx()
check_sales()

con.close()
