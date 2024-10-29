"""Example script to process a file from Azure Blob Storage."""

import os
import sys

from azure.storage.blob import BlobServiceClient

# Ensure Azure SDK for Python is installed
# pip install azure-storage-blob

# Load environment variables
account_name = os.getenv("AZURE_STORAGE_ACCOUNT")
container_name = os.getenv("AZURE_STORAGE_CONTAINER")
connection_string = os.getenv("AZURE_STORAGE_CONNECTION_STRING")

if len(sys.argv) != 2:
    print("Usage: python process_trigger.py <blob_name>")
    sys.exit(1)

blob_name = sys.argv[1]


def process_file(file_path):
    """Process the file content."""
    # Sample processing function (e.g., read file content)
    print(f"Processing file: {file_path}")
    with open(file_path, "r") as f:
        data = f.read()
        print(f"File content:\n{data}")


try:
    # Initialize BlobServiceClient
    blob_service_client = BlobServiceClient.from_connection_string(connection_string)
    blob_client = blob_service_client.get_blob_client(
        container=container_name, blob=blob_name
    )

    # Download the blob to a local file
    download_file_path = f"./{blob_name}"
    print(f"Downloading blob to {download_file_path}...")
    with open(download_file_path, "wb") as download_file:
        download_file.write(blob_client.download_blob().readall())

    # Process the downloaded file
    process_file(download_file_path)

    # Clean up
    os.remove(download_file_path)
    print("Processing complete and temporary file removed.")

except Exception as e:
    print(f"Error processing blob {blob_name}: {e}")
    sys.exit(1)
