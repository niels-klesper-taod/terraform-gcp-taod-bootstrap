#!/usr/bin/env python3
"""Example Cloud Run Job"""

import os
from google.cloud import bigquery

def main():
    print("Starting Cloud Run Job...")
    
    # Your job logic here
    project_id = os.getenv("GCP_PROJECT")
    print(f"Running in project: {project_id}")
    
    print("Job completed successfully!")

if __name__ == "__main__":
    main()
