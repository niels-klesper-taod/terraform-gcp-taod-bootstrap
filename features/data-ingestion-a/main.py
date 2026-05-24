#!/usr/bin/env python3
"""Data Ingestion A - Example Cloud Run Job"""

import os
from google.cloud import bigquery

def main():
    print("Starting Data Ingestion A...")
    
    project_id = os.getenv("GCP_PROJECT")
    print(f"Running in project: {project_id}")
    
    # Your ingestion logic here
    
    print("Data Ingestion A completed!")

if __name__ == "__main__":
    main()
