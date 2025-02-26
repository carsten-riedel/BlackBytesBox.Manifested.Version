function Convert-DateTimeTo64SecVersionComponents {
    <#
    .SYNOPSIS
        Converts a DateTime instance into NuGet and assembly version components with a granularity of 64 seconds.

    .DESCRIPTION
        This function calculates the total seconds elapsed from January 1st of the input DateTime's year and discards the lower 6 bits (each unit representing 64 seconds). The resulting value is split into:
          - LowPart: The lower 16 bits, simulating a ushort value.
          - HighPart: The remaining upper bits combined with a year-based offset (year multiplied by 10).
        The output is provided as a version string along with individual version components. This conversion is designed to generate version segments suitable for both NuGet package versions and assembly version numbers. The function accepts additional version parameters and supports years up to 6553.

    .PARAMETER VersionBuild
        An integer representing the build version component.

    .PARAMETER VersionMajor
        An integer representing the major version component.

    .PARAMETER InputDate
        An optional UTC DateTime value. If not provided, the current UTC date/time is used.
        The year of the InputDate must not exceed 6553.

    .EXAMPLE
        PS C:\> $result = Convert-DateTimeTo64SecVersionComponents -VersionBuild 1 -VersionMajor 0
        PS C:\> $result
        Name              Value
        ----              -----
        VersionFull       1.0.20250.1234
        VersionBuild      1
        VersionMajor      0
        VersionMinor      20250
        VersionRevision   1234
    #>

    [CmdletBinding()]
    [alias("cdv64")]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VersionBuild,

        [Parameter(Mandatory = $true)]
        [int]$VersionMajor,

        [Parameter(Mandatory = $false)]
        [datetime]$InputDate = (Get-Date).ToUniversalTime()
    )

    # The number of bits to discard, where each unit equals 64 seconds.
    $shiftAmount = 6

    $dateTime = $InputDate

    if ($dateTime.Year -gt 6553) {
        throw "Year must not be greater than 6553."
    }

    # Determine the start of the current year
    $startOfYear = [datetime]::new($dateTime.Year, 1, 1, 0, 0, 0, $dateTime.Kind)
    
    # Calculate total seconds elapsed since the start of the year
    $elapsedSeconds = [int](([timespan]($dateTime - $startOfYear)).TotalSeconds)
    
    # Discard the lower bits by applying a bitwise shift
    $shiftedSeconds = $elapsedSeconds -shr $shiftAmount
    
    # LowPart: extract the lower 16 bits (simulate ushort using bitwise AND with 0xFFFF)
    $lowPart = $shiftedSeconds -band 0xFFFF
    
    # HighPart: remaining bits after a right-shift of 16 bits
    $highPart = $shiftedSeconds -shr 16
    
    # Combine the high part with a year offset (year multiplied by 10)
    $combinedHigh = $highPart + ($dateTime.Year * 10)
    
    # Return a hashtable with the version string and components (output names must remain unchanged)
    return @{
        VersionFull    = "$($VersionBuild.ToString()).$($VersionMajor.ToString()).$($combinedHigh.ToString()).$($lowPart.ToString())"
        VersionBuild   = $VersionBuild.ToString();
        VersionMajor   = $VersionMajor.ToString();
        VersionMinor   = $combinedHigh.ToString();
        VersionRevision = $lowPart.ToString()
    }
}

function Convert-64SecVersionComponentsToDateTime {
    <#
    .SYNOPSIS
        Reconstructs an approximate DateTime from version components encoded with 64-second granularity.
        
    .DESCRIPTION
        This function reverses the conversion performed by Convert-DateTimeTo64SecVersionComponents.
        It accepts the version components where VersionMinor is calculated as (Year * 10 + HighPart)
        and VersionRevision holds the lower 16 bits of the shifted elapsed seconds.
        The function computes:
          - The Year is extracted from VersionMinor by integer division by 10.
          - The original shifted seconds are reassembled from the high part (derived from VersionMinor) and VersionRevision.
          - Multiplying the shifted seconds by 64 recovers the approximate total elapsed seconds since the year's start.
        The function returns a hashtable with the original VersionBuild, VersionMajor, and the computed DateTime.
        Note: Due to the loss of the lower 6 bits in the original conversion, the computed DateTime is approximate.
        
    .PARAMETER VersionBuild
        An integer representing the build version component (passed through unchanged).
        
    .PARAMETER VersionMajor
        An integer representing the major version component (passed through unchanged).
        
    .PARAMETER VersionMinor
        An integer representing the combined high part of the shifted seconds along with the encoded year 
        (calculated as Year * 10 + (shiftedSeconds >> 16)).
        
    .PARAMETER VersionRevision
        An integer representing the low 16 bits of the shifted seconds.
        
    .EXAMPLE
        PS C:\> $result = Convert-64SecVersionComponentsToDateTime -VersionBuild 1 -VersionMajor 0 `
                  -VersionMinor 20250 -VersionRevision 1234
        PS C:\> $result
        Name                Value
        ----                -----
        VersionBuild        1
        VersionMajor        0
        ComputedDateTime    2025-06-15T12:34:56Z
    #>
    [CmdletBinding()]
    [alias("cdv64r")]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VersionBuild,
        
        [Parameter(Mandatory = $true)]
        [int]$VersionMajor,
        
        [Parameter(Mandatory = $true)]
        [int]$VersionMinor,
        
        [Parameter(Mandatory = $true)]
        [int]$VersionRevision
    )

    # Extract the year from VersionMinor.
    # Since VersionMinor = (Year * 10) + HighPart, integer division by 10 yields the year.
    $year = [int]($VersionMinor / 10)

    # Calculate the high part by subtracting (Year * 10) from VersionMinor.
    $highPart = $VersionMinor - ($year * 10)

    # Reconstruct the shifted seconds: original shiftedSeconds = (HighPart << 16) + VersionRevision.
    $shiftedSeconds = ($highPart -shl 16) + $VersionRevision

    # Multiply the shifted seconds by 64 to recover the approximate elapsed seconds.
    $elapsedSeconds = $shiftedSeconds * 64

    # Define the start of the year in UTC.
    $startOfYear = [datetime]::new($year, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)

    # Compute the approximate DateTime.
    $computedDateTime = $startOfYear.AddSeconds($elapsedSeconds)

    return @{
        VersionBuild     = $VersionBuild;
        VersionMajor     = $VersionMajor;
        ComputedDateTime = $computedDateTime
    }
}

function Convert-DateTimeTo64SecPowershellVersion {
    <#
    .SYNOPSIS
        Converts a DateTime to a simplified three-part version string using 64-second encoding.
        
    .DESCRIPTION
        This function wraps Convert-DateTimeTo64SecVersionComponents and remaps its four-part version
        into a simplified three-part version. The mapping is:
          - New Build remains the same.
          - New Major is the original VersionMinor.
          - New Minor is the original VersionRevision.
        The resulting version is in the form: "Build.NewMajor.NewMinor"
        (e.g., if the original output is 1.0.20250.1234, the simplified version becomes "1.20250.1234").
        
    .PARAMETER VersionBuild
        An integer representing the build version component.
        
    .PARAMETER InputDate
        An optional UTC DateTime. If not provided, the current UTC time is used.
        
    .EXAMPLE
        PS C:\> Convert-DateTimeTo64SecPowershellVersion -VersionBuild 1 -InputDate (Get-Date)
    #>
    [CmdletBinding()]
    [alias("cdv64ps")]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VersionBuild,
        [Parameter(Mandatory = $false)]
        [datetime]$InputDate = (Get-Date).ToUniversalTime()
    )

    # Call the original conversion function, assuming VersionMajor is 0.
    $original = Convert-DateTimeTo64SecVersionComponents -VersionBuild $VersionBuild -VersionMajor 0 -InputDate $InputDate

    # Remap: New Major = original VersionMinor, New Minor = original VersionRevision.
    $newMajor = $original.VersionMinor
    $newMinor = $original.VersionRevision

    $versionFull = "$($original.VersionBuild).$newMajor.$newMinor"

    return @{
        VersionFull  = $versionFull;
        VersionBuild = $original.VersionBuild;
        VersionMajor = $newMajor;
        VersionMinor = $newMinor
    }
}


function Convert-64SecPowershellVersionToDateTime {
    <#
    .SYNOPSIS
        Reconstructs an approximate DateTime from a simplified three-part version using 64-second encoding.
        
    .DESCRIPTION
        This function reverses the mapping performed by Convert-DateTimeTo64SecPowershellVersion.
        It expects the simplified version in the form:
            VersionBuild.NewMajor.NewMinor
        where:
          - NewMajor corresponds to the original VersionMinor (encoding the high part of the DateTime).
          - NewMinor corresponds to the original VersionRevision (encoding the low part of the DateTime).
        Since the original VersionMajor is not preserved in the simplified version, it is assumed to be 0.
        The function calls Convert-64SecVersionComponentsToDateTime with these mapped values to reconstruct
        the approximate DateTime.
        
    .PARAMETER VersionBuild
        An integer representing the build component of the version.
        
    .PARAMETER VersionMajor
        An integer representing the major component of the simplified version,
        which is mapped from the original VersionMinor.
        
    .PARAMETER VersionMinor
        An integer representing the minor component of the simplified version,
        which is mapped from the original VersionRevision.
        
    .EXAMPLE
        PS C:\> Convert-64SecPowershellVersionToDateTime -VersionBuild 1 -VersionMajor 20250 -VersionMinor 1234
        Returns a hashtable containing the simplified version string, the VersionBuild, and the computed DateTime.
    #>
    [CmdletBinding()]
    [alias("cdv64psr")]
    param(
        [Parameter(Mandatory = $true)]
        [int]$VersionBuild,
        [Parameter(Mandatory = $true)]
        [int]$VersionMajor,  # Represents the original VersionMinor.
        [Parameter(Mandatory = $true)]
        [int]$VersionMinor   # Represents the original VersionRevision.
    )

    # Since the original VersionMajor is not included in the simplified version, we assume it to be 0.
    $result = Convert-64SecVersionComponentsToDateTime -VersionBuild $VersionBuild -VersionMajor 0 -VersionMinor $VersionMajor -VersionRevision $VersionMinor

    # Rebuild the simplified version string for clarity.
    $versionFull = "$VersionBuild.$VersionMajor.$VersionMinor"

    return @{
        VersionFull      = $versionFull;
        VersionBuild     = $VersionBuild;
        ComputedDateTime = $result.ComputedDateTime
    }
}

function Test-ModuleVersionToComputedDateTime {
    <#
    .SYNOPSIS
        Reads the current module's version and computes the corresponding DateTime.
        
    .DESCRIPTION
        This function retrieves the version of the current module (expected in the format:
        VersionBuild.NewMajor.NewMinor where NewMajor maps to the original VersionMinor and 
        NewMinor maps to the original VersionRevision). It then calls 
        Convert-64SecPowershellVersionToDateTime to convert the version back into an approximate
        DateTime value, and outputs the computed DateTime.
        
    .EXAMPLE
        PS C:\> Test-ModuleVersionToComputedDateTime
        Current module version: 1.20250.1234
        Computed DateTime from module version: 2025-06-15T12:34:56Z
    #>
    [CmdletBinding()]
    [alias("tmvcd")]
    param()
    
    # Retrieve the current module from which this function is running.
    $currentModule = Get-Module -Name $MyInvocation.MyCommand.Module.Name
    if (-not $currentModule) {
        Write-Error "Current module could not be determined."
        return
    }
    
    $versionString = $currentModule.Version.ToString()
    Write-Host "Current module version: $versionString"
    
    # Expecting the version in the format: Build.NewMajor.NewMinor (e.g., 1.20250.1234)
    $parts = $versionString -split '\.'
    if ($parts.Count -ne 3) {
        Write-Error "Module version format is not as expected (Build.NewMajor.NewMinor)."
        return
    }
    
    [int]$build = $parts[0]
    [int]$newMajor = $parts[1]
    [int]$newMinor = $parts[2]
    
    $result = Convert-64SecPowershellVersionToDateTime -VersionBuild $build -VersionMajor $newMajor -VersionMinor $newMinor
    Write-Host "Computed DateTime from module version: $($result.ComputedDateTime)"
}

