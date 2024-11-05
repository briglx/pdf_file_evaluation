# API - Python

Example API project to upload a file with metadata.

## Provision

```bash
# Build Docker image
project_root=$(git rev-parse --show-toplevel)
dockerfile_path="${project_root}/api_python/Dockerfile"
image_name="ai.doc.eval.api_python"

# Build image for local testing
docker build -t "${image_name}.dev" -f "${dockerfile_path}" "${project_root}"

# Run container locally
docker run -p 5000:5000 "${image_name}.dev"

# Interactive shell
docker run -it --entrypoint /bin/bash -p 5000:5000  "${image_name}.dev"
# Run the service
python app.py

# Check livliness
curl -p 127.0.0.1:5000/health

# Call API
metadata_title="Sample File"
metadata_description="This is a test file"
test_file_path="${project_root}/test/test_pdf_file.pdf"
curl -F "file=@${test_file_path}" -F "title=${metadata_title}" -F "description=${metadata_description}" http://localhost:5000/upload

# Build for deployment
docker build -t "$image_name" -f "${dockerfile_path}" "${project_root}"
```

Deploy image to a new container app

```bash
# load .env vars (optional)
[ ! -f .env ] || eval "export $(grep -v '^#' .env | xargs)"
# or this version allows variable substitution and quoted long values
[ -f .env ] && while IFS= read -r line; do [[ $line =~ ^[^#]*= ]] && eval "export $line"; done < .env

# Login to cloud cli. Only required once per install.
az login --tenant $AZURE_TENANT_ID

registry_host="${ACR_NAME}.azurecr.io"
namespace="$AZURE_CONTAINER_INFRA_NAMESPACE"
current_date_time=$(date +"%Y%m%dT%H%M")
tag="2024.10.1.dev${current_date_time}"

# Cloud Build
az acr build --registry "$registry_host" -t "${namespace}/${image_name}:${tag}" -f "${dockerfile_path}" "${project_root}"

# Or Local Docker Build
# Login to cloud cli. Only required once per install.
az acr login --name "${ACR_NAME}"
docker login -u "$ACR_USERNAME" -p "$ACR_PASSWORD" "${ACR_NAME}.azurecr.io"

# Build image
docker build -t "$image_name" -f "${dockerfile_path}" "${project_root}"

# Tag and Publish Dev Version
docker tag "${image_name}" "${registry_host}/${namespace}/${image_name}:${tag}"
docker push "${registry_host}/${namespace}/${image_name}:${tag}"

# Tag and Publish Prod Version
docker tag "${image_name}" "${registry_host}/${namespace}/${image_name}:latest"
docker push "${registry_host}/${namespace}/${image_name}:latest"

########

# Cloud Build Deplomnt

az acr login --name "${ACR_NAME}" "${ACR_PASSWORD}"
az acr login --name "$ACR_NAME" --username "$ACR_USERNAME" --password "$ACR_PASSWORD"
TOKEN=$(az acr login --name "${ACR_NAME}" --expose-token --output tsv --query accessToken)

# Create container app
az containerapp create \
  --name ca-pdffileevalwestus3 \
  --resource-group rg_pdf_file_eval_westus3 \
  --environment caepdffileevalwestus3 \
  --image "crdefaulteastus.azurecr.io/infra/ai.doc.eval.api_python:2024.10.1.dev20241104T1942" \
  --registry-server "$ACR_NAME" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD"

  --cpu 0.5 --memory 1 \





# docker tag "${image_name}" "${AZURE_CONTAINER_REGISTRY_NAME}.azurecr.io/${image_name}"
# docker push "${AZURE_CONTAINER_REGISTRY_NAME}.azurecr.io/${image_name}"
clean_name=$(echo "ca-${APP_NAME}${AZURE_LOCATION}" | tr -cd '[:alnum:]-')
response=$(az containerapp create -g "$AZURE_RESOURCE_GROUP_NAME" --name "$clean_name" --environment "$APP_ENVIRONMENT_NAME" --image "${registry_host}/${namespace}/${image_name}:${tag}" --cpu 0.5 --memory 1 --registry-server "$registry_host" --registry-username "$ACR_USERNAME" --registry-password "$ACR_PASSWORD")
ip_address=$(echo "$response" | jq -r '.ipAddress.ip')
iso_date_utc=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
{
    echo ""
    echo "# Script ./mlflow_server/README.md - output variables."
    echo "# Generated on $iso_date_utc"
    echo "MLFLOW_TRACKING_IP=${ip_address}"
    echo "MLFLOW_TRACKING_URI=http://${ip_address}"
}>> "./.env"


# Check livliness
curl -p ${ip_address}/health
# Login to the tracking server http://${ip_address}:5001
```

Response
```json
{
  "file_name": "test_pdf_file.pdf",
  "message": "File successfully uploaded",
  "metadata": {
    "description": "This is a test file",
    "title": "Sample File"
  }
}
```

Test results
```bash
request_test_file="test/test_pdf_file.pdf"
response_test_file="uploads/test_pdf_file.pdf"
# No output means files are the same
diff "$request_test_file" "$response_test_file"
```
