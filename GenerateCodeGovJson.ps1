#requires -Version 3
Set-StrictMode -Version 3

Import-Module -Name .\PSCodeGov.psm1

# Examples:

New-CodeGovJsonFile -Organization 'NationalSecurityAgency' -AgencyName 'National Security Agency' -AgencyEmail 'tech_transfer@nsa.gov' -AgencyEmailDescription 'NSA Technology Transfer Program' -Path '.\nsa.json'

Invoke-CodeGovJsonOverride -OriginalJsonPath .\nsa.json -NewJsonPath .\nsa.json -OverrideJsonPath .\nsa_overrides.json

New-CodeGovJsonFile -Organization 'iadgov' -AgencyName 'National Security Agency Information Assurance' -AgencyEmail 'iad_ccc@nsa.gov' -AgencyEmailDescription 'NSA IA Client Contact Center' -Path '.\ia.json'

Invoke-CodeGovJsonOverride -OriginalJsonPath .\nsa_ia.json -NewJsonPath .\nsa_ia.json -OverrideJsonPath .\nsa_ia_overrides.json

