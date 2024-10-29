#!/usr/bin/env bash
#########################################################################
# Onboard and manage application on cloud infrastructure.
# Usage: devops.sh [COMMAND]
# Globals:
#
# Commands
#   provision_connectivity  Provision connectivity resources.
#   provision               Provision common resources.
#   deploy          Prepare the app and deploy to cloud.
#   create_sp       Create system identity for the app.
#   delete          Delete the app from cloud.
# Params
#    -n, --name     Application name
#    -m, --message  Deployment message
#    -h, --help     Show this message and get help for a command
#    -l, --location Resource location. Default westus3
#    -j, --jumpbox  Deploy jumpbox (Default no jumpbox)
#########################################################################

# Stop on errors
set -e

show_help() {
    echo "$0 : Onboard and manage application on cloud infrastructure." >&2
    echo "Usage: devops.sh [COMMAND]"
    echo "Globals"
    echo
    echo "Commands"
    echo "  create_sp   Create system identity for the app."
    echo "  provision_connectivity  Provision connectivity resources."
    echo "  provision        Provision common resources."
    echo "  delete      Delete the app from cloud."
    echo "  deploy      Prepare the app and deploy to cloud."
    echo
    echo "Arguments"
    echo "   -n, --name             Application name"
    echo "   -m, --message          Deployment message"
    echo "   -l, --location         Resource location. Default westus3"
    echo "   -h, --help             Show this message and get help for a command"
    echo "   -j, --jumpbox          Deploy jumpbox (Default no jumpbox)"
    echo
}

validate_parameters(){
    # Check command
    if [ -z "$1" ]
    then
        echo "COMMAND is required (provision | deploy)" >&2
        show_help
        exit 1
    fi

    if [ -z "$app_name" ]
    then
        echo "Application name is required" >&2
        show_help
        exit 1
    fi
}

create_sp(){
    echo "Creating service principal."
    # shellcheck disable=SC2153
    app_client_id=$(create_cicd_sp "$CICD_CLIENT_NAME" "$AZURE_SUBSCRIPTION_ID" "$GITHUB_ORG" "$GITHUB_REPO")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "Failed to create cicd sp" >&2
        exit 1
    fi

}

provision_connectivity(){
    # Provision resources for the application.
    local location=$1
    local jumpbox=$2
    local deployment_name="core_vnet.Provisioning-${run_date}"

    additional_parameters=("message=$message")
    if [ -n "$location" ]
    then
        additional_parameters+=("location=$location")
    fi
    if [ "$jumpbox" = "true" ]
    then
        additional_parameters+=("jumpbox=$jumpbox")
    fi

    echo "Deploying ${deployment_name} with ${additional_parameters[*]}"

    # shellcheck source=/home/brlamore/src/azure_subscription_boilerplate/iac/connectivity_deployment.sh
    source "${INFRA_DIRECTORY}/connectivity_deployment.sh" --parameters "${additional_parameters[@]}"
}

validate_deployment(){
    # Validate the deployment.
    local app_name=$1
    local location=$2
    local deployment_name="${app_name}.coreinfra.Provisioning-${run_date}"

    additional_parameters=()
    if [ -n "$app_name" ]
    then
        additional_parameters+=("applicationName=$app_name")
    fi
    if [ -n "$location" ]
    then
        additional_parameters+=("location=$location")
    fi

    echo "Deploying ${deployment_name} with ${additional_parameters[*]}"

    # shellcheck source=/home/brlamore/src/azure_subscription_boilerplate/iac/common_services_deployment.sh
    results=$(az deployment sub validate --name "$deployment_name" --location "$location" --template-file "${INFRA_DIRECTORY}/main.bicep" --parameters @"${INFRA_DIRECTORY}/main.parameters.json")
    is_valid=$(echo "$results" | jq -r '.properties.provisioningState')

    if [ "$is_valid" != "Succeeded" ]
    then
        echo "Deployment failed. Exiting."
        exit 1
    fi

}

provision(){
    # Provision resources for the application.
    local app_name=$1
    local location=$2
    local deployment_name="${app_name}.coreinfra.Provisioning-${run_date}"

    additional_parameters=()
    if [ -n "$app_name" ]
    then
        additional_parameters+=("applicationName=$app_name")
    fi
    if [ -n "$location" ]
    then
        additional_parameters+=("location=$location")
    fi

    echo "Deploying ${deployment_name} with ${additional_parameters[*]}"
    results=$(az deployment sub create --name "$deployment_name" --location "$location" --template-file "${INFRA_DIRECTORY}/main.bicep" --parameters @"${INFRA_DIRECTORY}/main.parameters.json")
    is_valid=$(echo "$results" | jq -r '.properties.provisioningState')

    if [ "$is_valid" != "Succeeded" ]
    then
        echo "Deployment failed. Exiting."
        exit 1
    fi

    # Get the output variables from the deployment
    output_variables=$(echo "$results" | jq -r '.properties.outputs')
    # output_variables=$(az deployment sub show -n "${deployment_name}" --query 'properties.outputs' --output json)
    echo "Save deployment $deployment_name output variables to ${ENV_FILE}"
    {
        echo ""
        echo "# Deployment output variables"
        echo "# Generated on ${ISO_DATE_UTC}"
        echo "$output_variables" | jq -r 'to_entries[] | "\(.key | ascii_upcase )=\(.value.value)"'
    }>> "$ENV_FILE"
}

delete(){
    echo pass
}

deploy(){
    local source_folder="${PROJ_ROOT_PATH}/functions"
    local destination_dir="${PROJ_ROOT_PATH}/dist"
    local timestamp
    timestamp=$(date +'%Y%m%d%H%M%S')
    local zip_file_name="${app_name}_${timestamp}.zip"
    local zip_file_path="${destination_dir}/${zip_file_name}"

    echo "$0 : deploy $app_name" >&2

    # Ensure the source folder exists
    if [ ! -d "$source_folder" ]; then
        echo "Error: Source folder '$source_folder' does not exist."
        return 1
    fi

    # Create the destination directory if it doesn't exist
    mkdir -p "$(dirname "$zip_file_path")"

    # Create an array for exclusion patterns to zip based on .gitignore
    exclude_patterns=()
    while IFS= read -r pattern; do
        # Skip lines starting with '#' (comments)
        if [[ "$pattern" =~ ^[^#] ]]; then
            exclude_patterns+=("-x./$pattern")
        fi
    done < "${PROJ_ROOT_PATH}/.gitignore"
    exclude_patterns+=("-x./local.settings.*")
    exclude_patterns+=("-x./requirements_dev.txt")

    # Zip the folder to the specified location
    cd "$source_folder"
    zip -r "$zip_file_path" ./* "${exclude_patterns[@]}"

    func azure functionapp publish "$app_name"

    # az functionapp deployment source config-zip \
    #     --name "${functionapp_name}" \
    #     --resource-group "${resource_group}" \
    #     --src "${zip_file_path}"

    # Update environment variables to function app
    update_environment_variables

    echo "Cleaning up"
    rm "${zip_file_path}"

    echo "Done"
}

update_environment_variables(){
    echo pass
}

# Globals
PROJ_ROOT_PATH=$(cd "$(dirname "$0")"/..; pwd)
echo "Project root: $PROJ_ROOT_PATH"
SCRIPT_DIRECTORY="${PROJ_ROOT_PATH}/script"
INFRA_DIRECTORY="${PROJ_ROOT_PATH}/iac"
ENV_FILE="${PROJ_ROOT_PATH}/.env"

# shellcheck source=common.sh
source "${SCRIPT_DIRECTORY}/common.sh"

# Argument/Options
LONGOPTS=name:,message:,resource-group:,location:,jumpbox,help
OPTIONS=n:m:g:l:jh

# Variables
app_name="myapp"
message=""
location="westus3"
jumpbox="false"
run_date=$(date +%Y%m%dT%H%M%S)
ISO_DATE_UTC=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# Parse arguments
TEMP=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
eval set -- "$TEMP"
unset TEMP
while true; do
    case "$1" in
        -n|--name)
            app_name="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit
            ;;
        -m|--message)
            message="$2"
            shift 2
            ;;
        -l|--location)
            location="$2"
            shift 2
            ;;
        -j|--jumpbox)
            jumpbox="true"
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unknown parameters."
            show_help
            exit 1
            ;;
    esac
done

validate_parameters "$@"
command=$1
case "$command" in
    create_sp)
        create_sp
        exit 0
        ;;
    provision_connectivity)
        provision_connectivity "$app_name" "$location" "$jumpbox"
        exit 0
        ;;
    provision)
        validate_deployment "$app_name" "$location"
        provision "$app_name" "$location"
        exit 0
        ;;
    delete)
        delete
        exit 0
        ;;
    deploy)
        deploy
        exit 0
        ;;
    update_env)
        update_environment_variables
        exit 0
        ;;
    *)
        echo "Unknown command."
        show_help
        exit 1
        ;;
esac
