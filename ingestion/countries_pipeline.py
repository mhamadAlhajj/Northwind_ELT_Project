from dotenv import load_dotenv
import os
import dlt
from dlt.sources.rest_api import rest_api_source
import requests

load_dotenv()
api_key= os.getenv("api_key")
COUNTRIES  = "https://restcountries.com/"
def Read_Countries(path):
    source = rest_api_source(
        {"client" :{
            "base_url":path,
            "auth": {
            "type": "api_key",
            "name": "api_key", 
            "api_key": api_key,
            "location": "query",
            }
        },
        "resources":
            [{
                "name" : "Countries",
                "endpoint":{
                    "path":"countries/v5",
                    "data_selector": "data.objects",
                "params": {
                    "response_fields": "names.common,names.official,region,area,coordinates,currencies.code,currencies.name,currencies.symbol,continents.value,codes.alpha_3 , codes.alpha_2,population,ISO , ccn3 , subregion",
                },
                "paginator": {
                    "type": "offset",
                    "limit": 100,               
                    "offset_param": "offset",
                    "limit_param": "limit",
                    "total_path": "data.meta.total",  
                },
                }
            }]
        
        }
    )
    return source

def run_pipeline():
    """Run the data extraction pipeline."""
    print("Starting Countries data extraction...")
    pipeline = dlt.pipeline(
        pipeline_name="Countries_pipeline",
        destination=dlt.destinations.duckdb("warehouse/northwind.duckdb"),
        dataset_name="raw",
    )

    Countries_source = Read_Countries(COUNTRIES)
    load_Countries_info = pipeline.run(Countries_source, write_disposition="replace")
    print("Pipeline completed successfully!")
    print(f"Load info: {load_Countries_info}")
    
    return load_Countries_info


if __name__ == "__main__":
    run_pipeline()