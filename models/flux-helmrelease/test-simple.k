import main as flux

# Simple test
release = flux.helmReleaseFromRepo(
    "test-nginx",
    "nginx",
    "15.0.0",
    "bitnami"
)

items = release
