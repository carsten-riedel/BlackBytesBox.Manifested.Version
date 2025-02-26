# BlackBytesBox.Manifested.Version

A simple PowerShell library that encodes DateTime values into version components with 64‑second granularity. It supports two versioning schemes:
- **4-part versioning** (Assembly+NuGet): Generates a version string in the format *Build.Major.Minor.Revision*.
- **3-part versioning** (PowerShell+NuGet): Produces a simplified version string in the format *Build.Major.Minor*.

## Overview

- **Convert-DateTimeTo64SecVersionComponents**  
  Encodes a DateTime into a four‑part version (Build.Major.Minor.Revision).

- **Convert-64SecVersionComponentsToDateTime**  
  Reconstructs an approximate DateTime from the version components.

- **Convert-DateTimeTo64SecPowershellVersion**  
  Wraps the conversion to produce a simplified three‑part version (Build.Major.Minor)

- **Convert-64SecPowershellVersionToDateTime**  
  Reverses the simplified version mapping back into an approximate DateTime.

- **Test-ModuleVersionToComputedDateTime**  
  Retrieves the current module's version, decodes it, and prints the computed DateTime.

## Getting Started

1. **Import the Module**
```powershell

Import-Module BlackBytesBox.Manifested.Version

# Generate version components from the current DateTime
$resultComponents = Convert-DateTimeTo64SecVersionComponents -VersionBuild 1 -VersionMajor 0 -InputDate (Get-Date)
Write-Host "Four-part Version: $($resultComponents.VersionFull)"

# Reconstruct DateTime from the version components
$reconstructed = Convert-64SecVersionComponentsToDateTime `
    -VersionBuild $resultComponents.VersionBuild `
    -VersionMajor $resultComponents.VersionMajor `
    -VersionMinor $resultComponents.VersionMinor `
    -VersionRevision $resultComponents.VersionRevision
Write-Host "Reconstructed DateTime: $($reconstructed.ComputedDateTime)"

# Generate a simplified three-part version for the module
$versionInfo = Convert-DateTimeTo64SecPowershellVersion -VersionBuild 1 -InputDate (Get-Date)
Write-Host "Module Version: $($versionInfo.VersionFull)"

# Decode the simplified version back to an approximate DateTime
$decodedInfo = Convert-64SecPowershellVersionToDateTime -VersionBuild 1 -VersionMajor 20250 -VersionMinor 1234
Write-Host "Computed DateTime: $($decodedInfo.ComputedDateTime)"

Test-ModuleVersionToComputedDateTime
```

## Developer Notes

- **Precision:**  
  The conversion discards the lower 6 bits (each representing 64 seconds), so the computed DateTime is approximate.

- **Simplified Mapping:**  
  The simplified version remaps the four-part version to a three-part version (ignoring the original VersionMajor).

- **Aliases:**  
  - `cdv64` → Convert-DateTimeTo64SecVersionComponents  
  - `cdv64r` → Convert-64SecVersionComponentsToDateTime  
  - `cdv64ps` → Convert-DateTimeTo64SecPowershellVersion  
  - `cdv64psr` → Convert-64SecPowershellVersionToDateTime  
  - `tmvcd` → Test-ModuleVersionToComputedDateTime

