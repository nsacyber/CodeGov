Set-StrictMode -Version 3

Import-Module -Name CodeGov

Function Invoke-CodeGov() {
    [OutputType([void])]
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage='A GitHub personal access OAuth token')]
        [ValidateNotNullOrEmpty()]
        [string]$UnprocessedJsonPath,

        [Parameter(Mandatory=$true, HelpMessage='Path to store a temporary code.json file')]
        [ValidateNotNullOrEmpty()]
        [string]$ProcessedJsonPath,

        [Parameter(Mandatory=$true, HelpMessage='A GitHub personal access OAuth token')]
        [ValidateNotNullOrEmpty()]
        [string]$OverridesJsonPath,

        [Parameter(Mandatory=$true, HelpMessage='Organization properties for the code.json file')]
        [ValidateNotNullOrEmpty()]
        [object]$Properties,

        [Parameter(Mandatory=$false, HelpMessage='Validate code.json file')]
        [switch]$Validate
    )

    New-CodeGovJsonFile -Organization $Properties.Organization -AgencyName $Properties.AgencyName -AgencyContactEmail $Properties.AgencyContactEmail -AgencyContactName $Properties.AgencyContactName -AgencyContactUrl $Properties.AgencyContactUrl -AgencyContactPhone $Properties.AgencyContactPhone -Path $UnprocessedJsonPath

    Invoke-CodeGovJsonOverride -OriginalJsonPath $UnprocessedJsonPath -NewJsonPath $ProcessedJsonPath -OverrideJsonPath $OverridesJsonPath

    if($Validate) {
        $valid = Test-CodeGovJsonFile -Path $ProcessedJsonPath

        if(-not($valid)) {
            throw "$ProcessedJsonPath does not validate against the code.gov schema"
        }
    }
}

Set-OAuthToken -Token 'insertgithubapitokenhere'


$tempPath = "$env:userprofile\Desktop"
$sitePath = "$env:userprofile\Documents\GitHub\nsacyber.github.io"

$nsaCyberProperties = [pscustomobject]@{
    Organization = 'nsacyber';
    AgencyName = 'NSA Cybersecurity';
    AgencyContactEmail = 'cybersecurity_requests@nsa.gov';
    AgencyContactName = 'NSA Cybersecurity';
    AgencyContactUrl = 'https://www.nsa.gov/about/contact-us/';
    AgencyContactPhone = '410-854-4200';
}

Invoke-CodeGov -UnprocessedJsonPath "$tempPath\nsacyber-code.json" -ProcessedJsonPath "$sitePath\nsacyber-code.json" -OverridesJsonPath "$sitePath\nsacyber-overrides.json" -Properties $nsaCyberProperties

$nsaProperties = [pscustomobject]@{
    Organization = 'NationalSecurityAgency';
    AgencyName = 'National Security Agency';
    AgencyContactEmail = 'tech_transfer@nsa.gov';
    AgencyContactName = 'NSA Technology Transfer Program';
    AgencyContactUrl = 'https://www.nsa.gov/what-we-do/research/technology-transfer/';
    AgencyContactPhone = '1-866-680-4539';
}

Invoke-CodeGov -UnprocessedJsonPath "$tempPath\nsa-code.json" -ProcessedJsonPath "$sitePath\nsa-code.json" -OverridesJsonPath "$sitePath\nsa-overrides.json" -Properties $nsaProperties

$nsaCyberJson = Get-Content -Path "$sitePath\nsacyber-code.json" | ConvertFrom-Json

$nsaJson = Get-Content -Path "$sitePath\nsa-code.json" | ConvertFrom-Json

$releases = @()

$releases += [pscustomobject]($nsaCyberJson.releases)

$releases += [pscustomobject]($nsaJson.releases)

$measurementType = [pscustomobject]@{
    'method' = 'projects';
}

$codeGov = [pscustomobject][ordered]@{
    'version' = '2.0'; # required
    'agency' = 'NSA'; # required
    'measurementType' = $measurementType; # required
    'releases' = $releases | Sort-Object -Property 'Name'; # required
}

$codeGov | ConvertTo-Json -Depth 5 | Out-File -FilePath "$sitePath\code.json"  -Force -NoNewline -Encoding 'ASCII'
