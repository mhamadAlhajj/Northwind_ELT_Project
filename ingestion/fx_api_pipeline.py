import dlt
import requests
from datetime import date, timedelta

FX_BASE = "https://api.frankfurter.dev/v2/rates"


@dlt.resource(name="FX_Rates", write_disposition="merge", primary_key=["rate_date", "currency"])
def fx_rates_by_date(
    cursor=dlt.sources.incremental("rate_date", initial_value="2024-01-01")
):
    #  The idea here is to create a new column containing the rate date, because on weekends and holidays the market is closed, 
    #  so the actual date may return the value from the previous working day instead of the correct date I am searching for.
    end_date = date.today()
    current = date.fromisoformat(cursor.last_value)
    print(f"Starting from: {current} → up to: {end_date}")

    while current <= end_date:
        date_str = current.strftime("%Y-%m-%d")
        response = requests.get(FX_BASE, params={"base": "USD", "date": date_str})
        response.raise_for_status()
        data = response.json()
        for row in data:
            yield {
                "rate_date": date_str,
                "actual_date": row["date"],
                "base": row["base"],
                "currency": row["quote"],
                "rate": row["rate"],
            }
        current += timedelta(days=1)


def run_pipeline():
    print("Starting FX_rates data extraction...")
    pipeline = dlt.pipeline(
        pipeline_name="FX_pipeline",
        destination=dlt.destinations.duckdb("warehouse/northwind.duckdb"),
        dataset_name="raw",
    )

    load_info = pipeline.run(fx_rates_by_date())

    print("Pipeline completed successfully!")
    print(f"Load info: {load_info}")
    return load_info


if __name__ == "__main__":
    run_pipeline()
