#!/usr/bin/env bash
######################################################
# Create a system identity to authenticate using
# OpenId Connect (OIDC) federated credentials.
# Sets CICD_CLIENT_ID to .env
# Globals:
#   AZURE_TENANT_ID
#   AZURE_SUBSCRIPTION_ID
#   CICD_CLIENT_NAME
#   GITHUB_ORG
#   GITHUB_REPO
#   BASH_ENV (Optional) file path to environment variables.
# Params
#    -h, --help             Show this message and get help for a command.
######################################################

# Stop on errors
set -e

show_help() {
    echo "$0 : Create a cloud CICD system identity to authenticate using OpenId Connect (OIDC) federated credentials." >&2
    echo "Usage: create_cicd_sp.sh [OPTIONS]" >&2
    echo "Sets CICD_CLIENT_ID in .env" >&2
    echo "Globals"
    echo "   CICD_CLIENT"
    echo "   AZURE_TENANT_ID"
    echo "   AZURE_SUBSCRIPTION_ID"
    echo "   GITHUB_ORG"
    echo "   GITHUB_REPO"
    echo "   BASH_ENV (Optional)"
    echo
    echo "Arguments"
    echo "   -h, --help             Show this message and get help for a command."
    echo
}

validate_parameters(){

    # Check AZURE_SUBSCRIPTION_ID
    if [ -z "$AZURE_SUBSCRIPTION_ID" ]
    then
        echo "AZURE_SUBSCRIPTION_ID is required" >&2
        show_help
        exit 1
    fi

    # Check AZURE_TENANT_ID
    if [ -z "$AZURE_TENANT_ID" ]
    then
        echo "AZURE_TENANT_ID is required" >&2
        show_help
        exit 1
    fi

    # Check CICD_CLIENT
    if [ -z "$CICD_CLIENT_NAME" ]
    then
        echo "CICD_CLIENT_NAME is required" >&2
        show_help
        exit 1
    fi

    # Check GITHUB_ORG
    if [ -z "$GITHUB_ORG" ]
    then
        echo "GITHUB_ORG is required" >&2
        show_help
        exit 1
    fi

    # Check GITHUB_REPO
    if [ -z "$GITHUB_REPO" ]
    then
        echo "GITHUB_REPO is required" >&2
        show_help
        exit 1
    fi

}

# Globals
PROJ_ROOT_PATH=$(cd "$(dirname "$0")"/..; pwd)
ENV_FILE="${PROJ_ROOT_PATH}/.env"
echo "Project root: $PROJ_ROOT_PATH"
SCRIPT_DIRECTORY="${PROJ_ROOT_PATH}/script"

# shellcheck source=./common.sh
source "${SCRIPT_DIRECTORY}/common.sh"

# Argument/Options
LONGOPTS=help
OPTIONS=h

# Variables
ISO_DATE_UTC=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# Load .env
load_env "$ENV_FILE"

# Parse arguments
TEMP=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
eval set -- "$TEMP"
unset TEMP
while true; do
    case "$1" in
        -h|--help)
            show_help
            exit
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

echo "Creating cicd sp"
app_client_id=$(create_cicd_sp "$CICD_CLIENT_NAME" "$AZURE_SUBSCRIPTION_ID" "$GITHUB_ORG" "$GITHUB_REPO")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "Failed to create cicd sp" >&2
    exit 1
fi

# Save variables to .env
echo "Save Azure variables to ${ENV_FILE}"
{
    echo ""
    echo "# Script create_cicd_sp output variables."
    echo "# Generated on ${ISO_DATE_UTC} for subscription ${AZURE_SUBSCRIPTION_ID}"
    echo "CICD_CLIENT_ID=$app_client_id"
}>> "$ENV_FILE"
