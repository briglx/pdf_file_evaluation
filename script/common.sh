# shellcheck shell=bash
# Definition of common subroutines
load_env(){
    local env_file="$1"

    if [ -z "$env_file" ]
    then
        echo "ENV_FILE is required" >&2
        return 1
    fi

    if [ -f "$env_file" ]; then
        [ -f "${env_file}" ] && while IFS= read -r line; do [[ $line =~ ^[^#]*= ]] && eval "export $line"; done < "$env_file"
    else
        echo "ENV_FILE not found" >&2
        return 1
    fi
}

create_resource_group(){
    local rg_name="$1"
    local rg_region="$2"

    echo "creating resource group $rg_name in $rg_region"

    if az group show --name "$rg_name" &>/dev/null; then
        echo "Resource group $rg_name already exists."
    else
        if result=$(az group create --name "$rg_name" --location "$rg_region"); then
            echo "Creation successful"
        else
            echo "Creation failed"
            echo "$result"
        fi
    fi
}

remove_resource_group(){
    local rg_name="$1"

    # Remove Resource Group
    if az group show --name "$rg_name" &>/dev/null; then
        echo "Resource group $rg_name exists. Deleting..."

        if result=$(az group delete --name "$rg_name" --yes); then
            echo "Deletion successful"
        else
            echo "Deletion failed"
            echo "$result"
        fi
    fi
}

create_vnet(){
    local vnet_name="$1"
    local rg_name="$2"
    local vnet_cidr="$3"

    echo "creating vnet $vnet_name in $rg_name with cidr $vnet_cidr"

    if az network vnet show --resource-group "$rg_name" --name "$vnet_name" &>/dev/null; then
        echo "vnet $vnet_name already exists."
    else
        if result=$(az network vnet create --resource-group "$rg_name" --name "$vnet_name" --address-prefixes "$vnet_cidr"); then
            echo "Creation successful"
        else
            echo "Creation failed"
            echo "$result"
        fi
    fi

}

create_subnet(){
    local subnet_name="$1"
    local vnet_name="$2"
    local rg_name="$3"
    local subnet_cidr="$4"

    echo "creating subnet $subnet_name in $vnet_name with cidr $subnet_cidr"

    if az network vnet subnet show --resource-group "$rg_name" --vnet-name "$vnet_name" --name "$subnet_name" &>/dev/null; then
        echo "subnet $subnet_name already exists."
    else
        if result=$(az network vnet subnet create --resource-group "$rg_name" --vnet-name "$vnet_name" --name "$subnet_name" --address-prefixes "$subnet_cidr"); then
            echo "Creation successful"
        else
            echo "Creation failed"
            echo "$result"
        fi
    fi
}

unique_string(){
    local rg_name="$1"

    unique_string=$(echo -n "$(az group show --name "$rg_name" --query id)" | md5sum | cut -c 1-13)

    echo "$unique_string"
}

create_cicd_sp(){
    local client_name="$1"
    local subscription="$2"
    local github_org="$3"
    local github_repo="$4"

    # Constants
    ms_graph_api_id="00000003-0000-0000-c000-000000000000"
    ms_graph_user_invite_all_permission="09850681-111b-4a89-9bed-3f2cae46d706"
    ms_graph_user_read_write_all_permission="741f803b-c850-494e-b5df-cde7c675a1ca"
    ms_graph_directory_read_write_all_permission="19dbc75e-c2e2-444c-a770-ec69d8559fc7"

    # App Names
    app_name="${client_name}"
    federated_secret_name="github_oidc_cicd_secret"

    # Create an Azure Active Directory application.
    app_list_response=$(az ad app list --display-name "$app_name")
    if [[ $app_list_response == '[]' ]]; then
        response=$(az ad app create --display-name "$app_name")
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            echo "Failed to create ad app" >&2
            exit 1
        fi

        app_id=$(jq --raw-output .id <(echo "$response"))
        app_client_id=$(jq --raw-output .appId <(echo "$response"))

    else
        # Azure Active Directory application already exists.
        app_id=$(jq --raw-output .[0].id <(echo "$app_list_response"))
        app_client_id=$(jq --raw-output .[0].appId <(echo "$app_list_response"))
    fi

    # Create a service principal for the Azure Active Directory application.
    response=$(az ad sp list --all --display-name "$app_name")
    if [[ $response == '[]' ]]; then
        response=$(az ad sp create --id "$app_id")
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            echo "Failed to create ad service principal" >&2
            exit 1
        fi

        app_sp_id=$(jq --raw-output .id <(echo "$response"))

    else
        app_sp_id=$(jq --raw-output .[0].id <(echo "$response"))
    fi

    # Assign contributor role to the app service principal
    response=$(az role assignment list --assignee "$app_sp_id" --role contributor)
    if [[ $response == '[]' ]]; then
        # response=$(az role assignment create --role contributor --scope "/subscriptions/$subscription" --assignee "$app_sp_id" )
        response=$(az role assignment create --role contributor --scope "/subscriptions/$subscription" --assignee-object-id "$app_sp_id" --assignee-principal-type ServicePrincipal --subscription "$subscription" )
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            echo "Failed to assign contributor role to service principal" >&2
            exit 1
        fi
    fi

    # Assign Microsoft Graph api permissions to application
    response=$(jq --raw-output .[0].requiredResourceAccess <(echo "$app_list_response"))
    # response=$(az ad app permission list --id "$app_client_id" )
    if [[ $response == '[]' ]]; then
        response=$(az ad app permission add --id "$app_client_id" --api "$ms_graph_api_id" --api-permissions "${ms_graph_user_invite_all_permission}=Role ${ms_graph_user_read_write_all_permission}=Role ${ms_graph_directory_read_write_all_permission}=Role")
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            echo "Failed to assign Microsoft Graph api permissions to application" >&2
            exit 1
        fi
    fi

    # Grant Microsoft Graph api permissions to application
    response=$(az ad app permission list-grants --id "$app_client_id")
    if [[ $response == '[]' ]]; then
        response=$(az ad app permission admin-consent --id "$app_client_id")
        # response=$(az ad app permission grant --id "$app_client_id" --api "$ms_graph_api_id")
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            echo "Failed to grant Microsoft Graph api permissions to application" >&2
            exit 1
        fi
    fi

    # Add OIDC federated credentials for the application.
    response=$(az ad app federated-credential list --id "$app_id")
    if [[ $response == '[]' ]]; then
        json_sub="repo:$github_org/$github_repo"
        json_sub="${json_sub}:ref:refs/heads/main"
        json_desc="$client_name GitHub Service"

        json_body="{\"name\":\"$federated_secret_name\","
        json_body=$json_body'"issuer":"https://token.actions.githubusercontent.com",'
        json_body=$json_body"\"subject\":\"$json_sub\","
        json_body=$json_body"\"description\":\"$json_desc\",\"audiences\":[\"api://AzureADTokenExchange\"]}"

        response=$(az ad app federated-credential create --id "$app_id" --parameters "$json_body")
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            echo "Failed to create a federated identity credential" >&2
            exit 1
        fi
    fi

    echo "$app_client_id"

}
