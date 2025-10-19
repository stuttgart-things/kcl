# Tasks

## Setup Dagger Module with Crossplane Variable Pattern

### Module Creation
- [ ] Create module folder: `mkdir -p dagger/my-module`
- [ ] Initialize KCL module: `cd dagger/my-module && kcl mod init`
- [ ] Verify `kcl.mod` file was created

### Add Dependencies
- [ ] Add Crossplane types: `kcl mod add crossplane`
- [ ] Add Dagger SDK: `kcl mod add dagger` (if needed)
- [ ] Add other dependencies: `kcl mod add <package>` (if needed)

### Write KCL Code
- [ ] Create main function file: `main.k`
- [ ] Implement Crossplane variable pattern:
```
  name = option("params")?.oxr?.spec?.name or "default"
```
- [ ] Add function logic
- [ ] Add inline comments for variable usage

### Testing
- [ ] Test with minimal params:
```bash
  kcl run main.k -D params='{"oxr":{"spec":{"name":"test"}}}'
```
- [ ] Test with full Crossplane XR structure:
```bash
  kcl run main.k -D params='{
    "oxr": {
      "spec": {
        "name": "vcluster-k3s-tink1",
        "version": "0.29.0",
        "clusterName": "k3s-tink1",
        "targetNamespace": "vcluster-k3s-tink2"
      }
    }
  }'
```
- [ ] Test with empty params to verify fallback values:
```bash
  kcl run main.k -D params='{}'
```
- [ ] Verify all variable accessors work correctly

### Documentation
- [ ] Add function description
- [ ] Document required XR spec fields
- [ ] Document default values used
- [ ] Add example `kcl run` commands
