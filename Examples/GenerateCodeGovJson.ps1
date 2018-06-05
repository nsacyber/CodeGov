Set-StrictMode -Version 3

Import-Module -Name CodeGov

Set-OAuthToken -Token 'insertgithubapitokenvaluehere'

$unprocessedJsonPath = "$env:userprofile\Desktop\code.json"
$sitePath = "$env:userprofile\Documents\GitHub\nsacyber.github.io"
$processedJsonPath = "$sitePath\code.json"
$overridesJsonPath = "$sitePath\overrides.json"

if (!(Test-Path -Path $sitePath -PathType Container)) { 
    throw "$sitePath does not exist" 
}

#New-CodeGovJsonFile -Organization 'NationalSecurityAgency' -AgencyName 'National Security Agency' -AgencyContactEmail 'tech_transfer@nsa.gov' -AgencyContactName 'NSA Technology Transfer Program' -AgencyContactUrl 'https://www.nsa.gov/what-we-do/research/technology-transfer/' -AgencyContactPhone '1-866-680-4539' -Path '.\nsa_code.json'

New-CodeGovJsonFile -Organization nsacyber -AgencyName 'NSA Cybersecurity' -AgencyContactEmail 'iad_ccc@nsa.gov' -AgencyContactName 'NSA Client Contact Center' -AgencyContactUrl 'https://www.iad.gov/iad/help/contact/index.cfm' -AgencyContactPhone '410-854-4200' -Path $unprocessedJsonPath

Invoke-CodeGovJsonOverride -OriginalJsonPath $unprocessedJsonPath -NewJsonPath $processedJsonPath -OverrideJsonPath $overridesJsonPath

$valid = Test-CodeGovJsonFile -Path $processedJsonPath

$valid