#!/usr/bin/env python3
"""Data Ingestion B - Example Cloud Run Job"""

import os
from google.cloud import bigquery

def main():
    print("Starting Data Ingestion B...")
    
    project_id = os.getenv("GCP_PROJECT")
    print(f"Running in project: {project_id}")
    
    # Your ingestion logic here
    
    print("Data Ingestion B completed!")

if __name__ == "__main__":
    main()
