"""
Example usage of HarborProject resource from resources.stuttgart-things.com in KCL.
With conditional template loading based on template name.
"""

import k8s.apimachinery.pkg.apis.meta.v1 as v1
import v1alpha1.resources_stuttgart_things_com_v1alpha1_harbor_project as hp

# Read parameters from CLI or fallback to defaults
_params = option("params") or {}
_spec = _params?.hp?.spec or {}

# Template selector
_templateName = option("templateName") or _params?.templateName or "demo"  # Options: "demo", "production", "insecure"

# Common parameters - only fields from XRD
_name = option("name") or _params?.name or "demo-project"
_harborURL = _spec?.harborURL or option("harborURL") or "https://harbor.idp.kubermatic.sva.dev"
_projectName = _spec?.projectName or option("projectName") or "demo-project1"
_storageQuota = _spec?.storageQuota or option("storageQuota") or -1
_providerConfigRef = _spec?.providerConfigRef or option("providerConfigRef") or "default"
_harborInsecure = _spec?.harborInsecure or option("harborInsecure") or False

# Valid template options: "demo", "production", "insecure"

# Demo/Default Template
if _templateName == "demo":
    hp.HarborProject {
        metadata = v1.ObjectMeta {
            name = _name
        }
        spec = hp.ResourcesStuttgartThingsComV1alpha1HarborProjectSpec {
            harborURL = _harborURL
            projectName = _projectName
            storageQuota = _storageQuota
            providerConfigRef = _providerConfigRef
            harborInsecure = False
        }
    }

# Production Template with Quota
if _templateName == "production":
    hp.HarborProject {
        metadata = v1.ObjectMeta {
            name = option("name") or "production-app"
        }
        spec = hp.ResourcesStuttgartThingsComV1alpha1HarborProjectSpec {
            harborURL = option("harborURL") or "https://harbor.idp.kubermatic.sva.dev"
            projectName = option("projectName") or "production-app"
            storageQuota = option("storageQuota") or 107374182400  # 100GB in bytes
            providerConfigRef = option("providerConfigRef") or "default"
            harborInsecure = False
        }
    }

# Insecure/Self-Signed Template
if _templateName == "insecure":
    hp.HarborProject {
        metadata = v1.ObjectMeta {
            name = option("name") or "dev-project"
        }
        spec = hp.ResourcesStuttgartThingsComV1alpha1HarborProjectSpec {
            harborURL = option("harborURL") or "https://harbor.internal.dev"
            projectName = option("projectName") or "development-team"
            storageQuota = -1  # Unlimited
            providerConfigRef = option("providerConfigRef") or "default"
            harborInsecure = True
        }
    }
