# Lispium Winget Package

This directory contains the manifest files needed to publish Lispium to the Windows Package Manager (winget).

## Publishing to Winget

1. Fork the [winget-pkgs repository](https://github.com/microsoft/winget-pkgs)
2. Create the directory structure: `manifests/t/Tetraslam/Lispium/0.1.0/`
3. Copy all YAML files to that directory
4. Update the `InstallerSha256` in the installer manifest with the actual SHA256 of the release zip
5. Submit a pull request

### Getting the SHA256

```powershell
# PowerShell
(Get-FileHash -Algorithm SHA256 lispium-windows-x86_64.zip).Hash

# Or use certutil
certutil -hashfile lispium-windows-x86_64.zip SHA256
```

## Validation

Before submitting, validate the manifests:

```powershell
winget validate manifests/t/Tetraslam/Lispium/0.1.0/
```

## Installation (for users)

Once published:

```powershell
winget install Tetraslam.Lispium
```

## References

- [Creating a package manifest](https://docs.microsoft.com/en-us/windows/package-manager/package/manifest)
- [winget-pkgs repository](https://github.com/microsoft/winget-pkgs)
- [Package manifest submission](https://docs.microsoft.com/en-us/windows/package-manager/package/repository)
