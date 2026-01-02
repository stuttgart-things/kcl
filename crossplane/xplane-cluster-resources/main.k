import .schema

# --- Flattened params for backward compatibility ---
_flat_params = option("params")?.oxr?.spec or {}

# --- Merge CLI options into params (only if not null) ---
_cli_options = {
    if option("clusterName"): clusterName = option("clusterName")
    if option("credNamespace"): credNamespace = option("credNamespace")
    if option("credSecretName"): credSecretName = option("credSecretName")
    if option("credKey"): credKey = option("credKey")
    if option("useClusterProviderConfig") != None: useClusterProviderConfig = option("useClusterProviderConfig")
}
_merged_params = _flat_params | _cli_options

# --- Validate and apply defaults using schema ---
_config: schema.ProviderConfigParams = _merged_params

# --- Determine provider type ---
_providerType = option("providerType") or "helm"

# --- Determine apiVersion based on provider type ---
_apiVersion = "kubernetes.crossplane.io/v1alpha1" if _providerType == "kubernetes" else "helm.m.crossplane.io/v1beta1"


# --- Boolean flag to control output - check explicitly for False ---
_createProviderConfigValue = _flat_params?.createProviderConfig or option("createProviderConfig")
createProviderConfig = False if _createProviderConfigValue == False else True

# --- Determine the kind based on boolean ---
_kind = "ClusterProviderConfig" if _config.useClusterProviderConfig else "ProviderConfig"

# --- Build ProviderConfig or ClusterProviderConfig ---
_providerConfigObj = {
    apiVersion = _apiVersion
    kind = _kind
    metadata = { name = _config.clusterName }
    spec = {
        credentials = {
            source = "Secret"
            secretRef = {
                namespace = _config.credNamespace
                name = _config.credSecretName
                key = _config.credKey
            }
        }
    }
}

# --- Output the items array based on createProviderConfig flag ---
items = [_providerConfigObj] if createProviderConfig else []
