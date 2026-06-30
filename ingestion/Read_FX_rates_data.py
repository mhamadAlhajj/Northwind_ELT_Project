import dlt
from dlt.sources.rest_api import rest_api_source

FX_BASE    = "https://api.frankfurter.dev/"

def Read_FX(path):
    source = rest_api_source(
        {"client" :{
            "base_url":path
        },
        "resources":
            [{
                "name" : "FX_Rates",
                "endpoint":{
                    "path":"v2/rates",
                "paginator": {
                    "type": "single_page",
                }
                }
            }]
        
        }
    )
    return source

def run_pipeline():
    """Run the data extraction pipeline."""
    print("🚀 Starting FX_rates data extraction...")
    pipeline = dlt.pipeline(
        pipeline_name="FX_pipeline",
        destination=dlt.destinations.duckdb("warehouse/northwind.duckdb"),
        dataset_name="raw",
    )

    FX_source = Read_FX(FX_BASE)
    load_FX_info = pipeline.run(FX_source, write_disposition="append")

    print("✅ Pipeline completed successfully!")
    print(f"📊 Load info: {load_FX_info}")
    
    return load_FX_info


if __name__ == "__main__":
    run_pipeline()