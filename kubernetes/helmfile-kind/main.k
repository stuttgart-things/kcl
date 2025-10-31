import .cilium
import .cert_manager as cert
import .defaults as defaults

helmDefaults = defaults.helmDefaults

# Create a registry of all available apps
_app_registry = {
    cilium = cilium.app
    cert_manager = cert.app
}

# Default apps to install
_default_apps = ["cilium", "cert_manager"]

# Get apps from -D option or use defaults
_enabled_apps_input = option("apps") or _default_apps

# Parse if string (comma-separated)
_enabled_apps = _enabled_apps_input.split(",") if typeof(_enabled_apps_input) == "str" else _enabled_apps_input

# Build helmfiles from enabled apps
helmfiles = [_app_registry[app] for app in _enabled_apps]