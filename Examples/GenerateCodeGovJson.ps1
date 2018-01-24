#requires -Version 3
Set-StrictMode -Version 3

#Import-Module -Name .\PSCodeGov.psm1

Import-Module -Name PSCodeGov

#New-CodeGovJsonFile -Organization 'NationalSecurityAgency' -AgencyName 'National Security Agency' -AgencyContactEmail 'tech_transfer@nsa.gov' -AgencyContactName 'NSA Technology Transfer Program' -AgencyContactUrl 'https://www.nsa.gov/what-we-do/research/technology-transfer/' -AgencyContactPhone '1-866-680-4539' -Path '.\nsa_code.json'

#WARNING: Required element tags was empty for organization NationalSecurityAgency repository SIMP
#WARNING: Required element permissions.license.name was empty for organization NationalSecurityAgency repository SIMP
#WARNING: Required element tags was empty for organization NationalSecurityAgency repository qgis-latlontools-plugin
#WARNING: Required element tags was empty for organization NationalSecurityAgency repository qgis-searchlayers-plugin
#WARNING: Required element tags was empty for organization NationalSecurityAgency repository qgis-shapetools-plugin
#WARNING: Required element description was empty for organization NationalSecurityAgency repository sharkPy
#WARNING: Required element tags was empty for organization NationalSecurityAgency repository sharkPy
#WARNING: Required element permissions.license.URL was empty for organization NationalSecurityAgency repository sharkPy
#WARNING: Required element permissions.license.name was empty for organization NationalSecurityAgency repository sharkPy
#WARNING: Required element tags was empty for organization NationalSecurityAgency repository qgis-d3datavis-plugin
#WARNING: Required element tags was empty for organization NationalSecurityAgency repository lemongraph
#WARNING: Required element permissions.license.name was empty for organization NationalSecurityAgency repository lemongraph
#WARNING: Required element tags was empty for organization NationalSecurityAgency repository lemongrenade
#WARNING: Required element permissions.license.name was empty for organization NationalSecurityAgency repository lemongrenade
#WARNING: Required element tags was empty for organization NationalSecurityAgency repository DCP
#WARNING: Required element permissions.license.name was empty for organization NationalSecurityAgency repository DCP

#Invoke-CodeGovJsonOverride -OriginalJsonPath .\nsa.json -NewJsonPath .\nsa_code.json -OverrideJsonPath .\nsa_overrides.json

New-CodeGovJsonFile -Organization iadgov -AgencyName 'NSA Information Assurance' -AgencyContactEmail 'iad_ccc@nsa.gov' -AgencyContactName 'NSA IA Client Contact Center' -AgencyContactUrl 'https://www.iad.gov/iad/help/contact/index.cfm' -AgencyContactPhone '410-854-4200' -Path "$env:userprofile\Desktop\nsaia.json"

Invoke-CodeGovJsonOverride -OriginalJsonPath "$env:userprofile\Desktop\nsaia.json" -NewJsonPath "$env:userprofile\Desktop\nsaia_code.json" -OverrideJsonPath "$env:userprofile\Documents\GitHub\iadgov.github.io\overrides.json"

