param (
    [string]$NUGET_GITHUB_PUSH,
    [string]$NUGET_PAT,
    [string]$NUGET_TEST_PAT,
    [string]$POWERSHELL_GALLERY
)

# If any of the parameters are empty, try loading them from a secrets file.
if ([string]::IsNullOrEmpty($NUGET_GITHUB_PUSH) -or [string]::IsNullOrEmpty($NUGET_PAT) -or [string]::IsNullOrEmpty($NUGET_TEST_PAT) -or [string]::IsNullOrEmpty($POWERSHELL_GALLERY)) {
    if (Test-Path "$PSScriptRoot\cicd_secrets.ps1") {
        . "$PSScriptRoot\cicd_secrets.ps1"
        Write-Host "Secrets loaded from file."
    }
    if ([string]::IsNullOrEmpty($NUGET_GITHUB_PUSH))
    {
        exit 1
    }
}

Install-Module -Name BlackBytesBox.Manifested.Initialize -Repository "PSGallery" -Force -AllowClobber
Install-Module -Name BlackBytesBox.Manifested.Version -Repository "PSGallery" -Force -AllowClobber
Install-Module -Name BlackBytesBox.Manifested.Git -Repository "PSGallery" -Force -AllowClobber


$result1 = Convert-DateTimeTo64SecPowershellVersion -VersionBuild 0
$result2 = Get-GitCurrentBranch
$result3 = Get-GitTopLevelDirectory

##############################

# Define the path to your module folder (adjust "MyModule" as needed)
$moduleFolder = "$result3/source/BlackBytesBox.Manifested.Version"
Update-ManifestModuleVersion -ManifestPath "$moduleFolder" -NewVersion "$($result1.VersionBuild).$($result1.VersionMajor).$($result1.VersionMinor)"
$moduleManifest = "$moduleFolder/BlackBytesBox.Manifested.Version.psd1" -replace '[/\\]', [System.IO.Path]::DirectorySeparatorChar

# Validate the module manifest
Write-Host "===> Testing module manifest at: $moduleManifest" -ForegroundColor Cyan
Test-ModuleManifest -Path $moduleManifest

Publish-Module -Path $moduleFolder -Repository "PSGallery" -NuGetApiKey "$POWERSHELL_GALLERY"

##############################
# Git operations: commit changes, tag the repo with the new version, and push them

$gitUserLocal = git config user.name
$gitMailLocal = git config user.email

$gitTempUser = "Workflow"
$gitTempMail = "carstenriedel@outlook.com"  # Assuming a placeholder email

git config user.name $gitTempUser
git config user.email $gitTempMail

# Define the new version tag based on the version information
$tag = "$($result1.VersionBuild).$($result1.VersionMajor).$($result1.VersionMinor)"

# Change directory to the repository's top-level directory
Set-Location -Path $result3

# Stage all changes (adjust if you want to be more specific)
git add .

# Commit changes with a message including the version tag and [skip ci] to avoid triggering GitHub Actions
git commit -m "Update module version to $tag [skip ci]"

# Create a Git tag for the new version
git tag $tag

# Push the commit and tag to the remote repository
git push origin HEAD
git push origin $tag

git config user.name $gitUserLocal
git config user.email $gitMailLocal