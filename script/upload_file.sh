#!/bin/bash

# Check if the filename argument is passed
if [ -z "$1" ]; then
    echo "Usage: ./upload.sh <file_path>"
    exit 1
fi

FILE_PATH=$1
BLOB_NAME=$(basename "$FILE_PATH")

# Upload file to Azure Blob Storage
echo "Uploading $FILE_PATH to Azure Storage..."
result=$(az storage blob upload \
    --account-name "$AZURE_STORAGE_ACCOUNT" \
    --container-name "$AZURE_STORAGE_CONTAINER" \
    --file "$FILE_PATH" \
    --name "$BLOB_NAME" \
    --connection-string "$AZURE_STORAGE_CONNECTION_STRING" \
    --output json)

# Check if the file is uploaded successfully
is_uploaded=$(echo "$result" | grep -c "url")

if [ "$is_uploaded" -eq 1 ]; then
    echo "File uploaded successfully!"
    echo "Triggering the Python processing script..."
    python3 process_trigger.py "$BLOB_NAME"
else
    echo "File upload failed."
    exit 1
fi
