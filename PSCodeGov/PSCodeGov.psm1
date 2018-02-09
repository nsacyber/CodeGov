Set-StrictMode -Version 3

$script:GitHubBaseUri = 'https://api.github.com'

Function Set-OAuthToken() {
    [CmdletBinding()] 
    [OutputType([void])]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='A GitHub personal access OAuth token')]
        [AllowNull()]
        [AllowEmptyString()]
        [ValidatePattern('^([0-9a-f]{40}){0,1}$')]
        [string]$Token
    )

    $env:OAUTH_TOKEN = $Token
}

Function Get-OAuthToken() {
    [CmdletBinding()] 
    [OutputType([string])]
    Param()

    if (-not($env:OAUTH_TOKEN -eq $null -or $env:OAUTH_TOKEN -eq '')) {
        return $env:OAUTH_TOKEN
    }

    return ''
}

Function Test-OAuthToken() {
    [CmdletBinding()] 
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory=$false, HelpMessage='A GitHub personal access OAuth token')]
        [ValidateNotNullOrEmpty()]
        [string]$Token
    )

    $parameters = $PSBoundParameters

    if ($parameters.ContainsKey('Token')) {
        return $Token -match '^([0-9a-f]{40}){1}$'
    }

    if ($env:OAUTH_TOKEN -eq $null -or $env:OAUTH_TOKEN -eq '') {
        return $false
    } else {
        return $env:OAUTH_TOKEN -match '^([0-9a-f]{40}){1}$'
    }
}

Function Test-Url() {
    [CmdletBinding()] 
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='The URL to test')]
        [ValidateNotNullOrEmpty()]
        [Uri]$Url
    )

    $uri = $Url

    $proxyUri = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy($uri)

    $params = @{
        Uri = $uri;
        Method = 'Head';
        ProxyUseDefaultCredentials = (([string]$proxyUri) -ne $uri);
        UseBasicParsing = $true;
    }

    if (([string]$proxyUri) -ne $uri) {
        $params.Add('Proxy',$proxyUri)
    }

    $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue

    $statusCode = 0

    try {
        $response = Invoke-WebRequest @params

        $statusCode = $response.StatusCode 
    } catch { }

    return $statusCode -eq 200
}

Function Get-GitHubRepositoryLanguages() {
    [CmdletBinding()] 
    [OutputType([string[]])]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='The URL to retrieve the programming languages found in the repository')]
        [ValidateNotNullOrEmpty()]
        [Uri]$Url
    )

    $languages = @{}

    $uri = $Url

    $proxyUri = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy($uri)

    $params = @{
        Uri = $uri;
        Method = 'Get';
        ProxyUseDefaultCredentials = (([string]$proxyUri) -ne $uri);
        UseBasicParsing = $true;
    }

    if (([string]$proxyUri) -ne $uri) {
        $params.Add('Proxy',$proxyUri)
    }

    if (Test-OAuthToken) {
        if ($params.ContainsKey('Headers')) {
            $val = $params['Headers']
            $val.Add('Authorization', "token $(Get-OAuthToken)")
            $params['Headers'] = $val
        } else {
            $params.Add('Headers', @{'Authorization'="token $(Get-OAuthToken)"})
        }
    }

    $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue

    $statusCode = 0

    try {
        $response = Invoke-WebRequest @params

        $statusCode = $response.StatusCode
    } catch {
        Write-Error $_
    }

    if ($statusCode -eq 200) {
        $content = $response.Content
        $languageStats = $content | ConvertFrom-Json
    } else {
        throw "Request failed with status code $statusCode"
    }

    $languageStats.PSObject.Properties | ForEach-Object { $languages[$_.Name] = $_.Value }

    return ,[string[]]$languages.Keys
}

Function Get-GitHubRepositories() {
    [CmdletBinding()] 
    [OutputType([pscustomobject])]
    Param(
        [Parameter(Mandatory=$true, HelpMessage="The name of the organization's repository taken from the GitHub URL")]
        [ValidateNotNullOrEmpty()]
        [string]$Organization
    )

    $repos = $null

    $uri = ($script:GitHubBaseUri,'orgs',$Organization.ToLower(),'repos' -join '/')

    $proxyUri = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy($uri)

    $params = @{
        Uri = $uri;
        Method = 'Get';
        ProxyUseDefaultCredentials = (([string]$proxyUri) -ne $uri);
        UseBasicParsing = $true;
        Headers = @{'Accept'='application/vnd.github.mercy-preview+json'} # topics API preview 
    }

    if (([string]$proxyUri) -ne $uri) {
        $params.Add('Proxy',$proxyUri)
    }

    if (Test-OAuthToken) {
        if ($params.ContainsKey('Headers')) {
            $val = $params['Headers']
            $val.Add('Authorization', "token $(Get-OAuthToken)")
            $params['Headers'] = $val
        } else {
            $params.Add('Headers', @{'Authorization'="token $(Get-OAuthToken)"})
        }
    }

    $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue

    $statusCode = 0

    try {
        $response = Invoke-WebRequest @params

        $statusCode = $response.StatusCode
    } catch {
        Write-Error $_
    } 

    if ($statusCode -eq 200) {
        $content = $response.Content
        $repos = $content | ConvertFrom-Json
    } else {
        throw "Request failed with status code $statusCode"
    }

    return $repos
}

Function Get-GitHubRepositoryLicenseUrl() {
    [CmdletBinding()] 
    [OutputType([string])]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='The URL of the repository')]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [Parameter(Mandatory=$true, HelpMessage='The default branch of the repository')]
        [ValidateNotNullOrEmpty()]
        [string]$Branch
    )

    $license = $null

    $urls = [string[]]@(('{0}/blob/{1}/LICENSE' -f $Url,$Branch),('{0}/blob/{1}/LICENSE.md' -f $Url,$Branch),('{0}/blob/{1}/LICENSE.txt' -f $Url,$Branch),('{0}/blob/{1}/LICENSE.spdx' -f $Url,$Branch))

    $urls = $urls | ForEach-Object { 
        if (Test-Url -Url $_ ) { 
            $license = $_ 
            return
        } 
    }

    return $license
}

Function Get-GitHubRepositoryLicense() {
    [CmdletBinding()] 
    [OutputType([pscustomobject])]
    Param(
        [Parameter(Mandatory=$true, HelpMessage="The name of the organization's repository taken from the GitHub URL")]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,

        [Parameter(Mandatory=$true, HelpMessage='The URL of the repository')]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [Parameter(Mandatory=$true, HelpMessage='The name of the repository')]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory=$true, HelpMessage='The default branch of the repository')]
        [ValidateNotNullOrEmpty()]
        [string]$Branch
    )

    $license = $null
    $response = $null
    $conte = $null

    $uri = ($script:GitHubBaseUri,'repos',$Organization.ToLower(),$Project,'license' -join '/')

    $proxyUri = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy($uri)

    $params = @{
        Uri = $uri;
        Method = 'Get';
        ProxyUseDefaultCredentials = (([string]$proxyUri) -ne $uri);
        UseBasicParsing = $true;
    }

    if (([string]$proxyUri) -ne $uri) {
        $params.Add('Proxy',$proxyUri)
    }

    if (Test-OAuthToken) {
        if ($params.ContainsKey('Headers')) {
            $val = $params['Headers']
            $val.Add('Authorization', "token $(Get-OAuthToken)")
            $params['Headers'] = $val
        } else {
            $params.Add('Headers', @{'Authorization'="token $(Get-OAuthToken)"})
        }
    }

    $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue

    $statusCode = 0

    try {
        $response = Invoke-WebRequest @params

        $statusCode = $response.StatusCode
        $content = $response.Content
    } catch {
        $statusCode = [int]$_.Exception.Response.StatusCode
        $content = $_.ToString()

        if ($content -eq $null) {
            Write-Error $_
        }
    } 

    $lic = $content | ConvertFrom-Json

    if ($content -eq $null -or $content -eq '') {
        throw "Request failed with status code $statusCode"
    }

    if($lic.PSObject.Properties.Name -contains 'message') {
        $license = [pscustomobject]@{
            Url = Get-GitHubRepositoryLicenseUrl -Url $Url -Branch $Branch;
            SPDX = '';
        }
    } else {
        $license = [pscustomobject]@{
            Url = $lic.html_url;
            SPDX =  $lic.license.spdx_id
        }
    }

    return $license
}

Function Get-GitHubRepositoryDisclaimerUrl() {
    [CmdletBinding()] 
    [OutputType([string])]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='The URL of the repository')]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [Parameter(Mandatory=$true, HelpMessage='The default branch of the repository')]
        [ValidateNotNullOrEmpty()]
        [string]$Branch
    )

    $disclaimer = $null

    $urls = [string[]]@(('{0}/blob/{1}/DISCLAIMER' -f $Url,$Branch),('{0}/blob/{1}/DISCLAIMER.md' -f $Url,$Branch),('{0}/blob/{1}/DISCLAIMER.txt' -f $Url,$Branch))

    $urls = $urls | ForEach-Object { 
        if (Test-Url -Url $_ ) { 
            $disclaimer = $_ 
            return
        } 
    }

    return $disclaimer
}

Function Get-GitHubRepositoryReleaseUrl() {
    [CmdletBinding()] 
    [OutputType([string])]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='The URL of the repository')]
        [ValidateNotNullOrEmpty()]
        [string]$Url
    )

    $release = $null

    $uri = $Url.Replace('{/id}','')

    $proxyUri = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy($uri)

    $params = @{
        Uri = $uri;
        Method = 'Get';
        ProxyUseDefaultCredentials = (([string]$proxyUri) -ne $uri);
        UseBasicParsing = $true;
    }

    if (([string]$proxyUri) -ne $uri) {
        $params.Add('Proxy',$proxyUri)
    }

    if (Test-OAuthToken) {
        if ($params.ContainsKey('Headers')) {
            $val = $params['Headers']
            $val.Add('Authorization', "token $(Get-OAuthToken)")
            $params['Headers'] = $val
        } else {
            $params.Add('Headers', @{'Authorization'="token $(Get-OAuthToken)"})
        }
    }

    $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue

    $statusCode = 0

    try {
        $response = Invoke-WebRequest @params

        $statusCode = $response.StatusCode
    } catch {
        Write-Error $_
    } 

    if ($statusCode -eq 200) {
        $content = $response.Content
        $releases = $content | ConvertFrom-Json
        
        if ($releases.Count -gt 0) {
            $stableReleases = [object[]]@($releases | Where-Object { $_.prerelease -eq $false })

            if($stableReleases.Count -gt 0) {
                # item 0 appears to be the most recent item, but if this proves false then use | Sort-Object -Property 'published_at' -Descending
                $release = $stableReleases[0].zipball_url # https://api.github.com/repos/org-name/repo-name/zipball/tag-name

                # transform the URL to the URL behind the words 'Source code (zip)' on the release page
                #$release = $release.Replace('api.','').Replace('/repos','').Replace('zipball','archive')
                #$release = '{0}.zip' -f $release

                # this works too
                $release = $release.Replace('api.','')
            }
        }
    } else {
        throw "Request failed with status code $statusCode"
    }

    return $release
}

Function New-CodeGovJson() {
    [CmdletBinding()] 
    [OutputType([pscustomobject])]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='GitHub organization name(s)')]
        [ValidateNotNullOrEmpty()]
        [string[]]$Organization,

        [Parameter(Mandatory=$true, HelpMessage='The name of the agency')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyName,

        [Parameter(Mandatory=$true, HelpMessage='A email address that can be used as a contact point for agency open source releases')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyContactEmail,
        
        [Parameter(Mandatory=$false, HelpMessage='A description or name associated with agency email address')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyContactName,
        
        [Parameter(Mandatory=$false, HelpMessage='A URL containing contact information for agency open source releases')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyContactUrl,
        
        [Parameter(Mandatory=$false, HelpMessage='A phone number for agency open source releases')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyContactPhone,        

        [Parameter(Mandatory=$false, HelpMessage='Include private repositories in the code.json file')]
        [switch]$IncludePrivate,

        [Parameter(Mandatory=$false, HelpMessage='Include repositories that are forks of other projects')]
        [switch]$IncludeForks
    )

    $Organization | ForEach-Object {
        $org = $_
        $repositories = Get-GitHubRepositories -Organization $org

        $releases = @()

        $contact = @{
            'email' = $AgencyContactEmail; # required
        }

        if ($AgencyContactName -ne $null -and $AgencyContactName -ne '' ) {
            $contact.Add('name', $AgencyContactName) # optional
        }
        
        if ($AgencyContactUrl -ne $null -and $AgencyContactUrl -ne '' ) {
            $contact.Add('URL', $AgencyContactUrl) # optional
        }

        if ($AgencyContactPhone -ne $null -and $AgencyContactPhone -ne '' ) {
            $contact.Add('phone', $AgencyContactPhone) # optional
        }
       
        $repositories | Where-Object { $_.private -eq $IncludePrivate -and $_.fork -eq $IncludeForks } | ForEach-Object {
            $branch = $_.default_branch

            $name = $_.name
            $repositoryUrl = $_.html_url
            $description = if ($_.description -eq $null) { 'No description provided' } else { $_.description }
            $tags = if ($_.topics -eq $null -or $_.topics.Count -eq 0) { [string[]]@('none') } else { [string[]]@($_.topics) }
            $homepageUrl = if ($_.homepage -eq $null -or $_.homepage -eq '') { $repositoryUrl } else { $_.homepage }
            $languages = Get-GitHubRepositoryLanguages -Url $_.languages_url
            $lastUpdated = $_.updated_at
            $lastCommit = $_.pushed_at
            $created = $_.created_at
            $isArchived = $_.archived

            $lic = Get-GitHubRepositoryLicense -Organization $org -Url $repositoryUrl -Project $name -Branch $branch
            #$licenseUrl = if ($licenseUrl -eq $null) { 'null'} else { $licenseUrl }
            
            $disclaimerUrl = Get-GitHubRepositoryDisclaimerUrl -Url $repositoryUrl -Branch $branch
            $disclaimerUrl = if ($disclaimerUrl -eq $null) { 'null'} else { $disclaimerUrl }

            $downloadUrl = Get-GitHubRepositoryReleaseUrl -Url $_.releases_url
            $downloadUrl = if ($downloadUrl -eq $null) {  ('{0}/archive/{1}.zip' -f $repositoryUrl,$branch) } else { $downloadUrl }

            $date = [pscustomobject]@{
                'created' = $created; # optional
                'metadataLastUpdated' = $lastUpdated; # optional
                'lastModified' = $lastCommit; # optional
            }

            $license = [pscustomobject]@{
                'URL' = $lic.Url; # required
                'name' = $lic.SPDX; # required, needs to be manually updated
            }

            $licenses = @($license)
            
            $permissions = [pscustomobject]@{
                'licenses' = $licenses; # required
                'usageType' = 'openSource'; # required
            }

            if ($_.name -eq $null -or $_.name -eq '') {
                Write-Warning -Message ('Required element name was empty for organization {0} repository {1}' -f $org,$name)
            }

            if ($repositoryUrl -eq $null -or $repositoryUrl -eq '') {
                Write-Warning -Message ('Required element repositoryURL was empty for organization {0} repository {1}' -f $org,$name)
            }

            if ($_.description -eq $null -or $_.description -eq '') {
                Write-Warning -Message ('Required element description was empty for organization {0} repository {1}' -f $org,$name)
            }

            if ($_.topics -eq $null -or $_.topics.Count -eq 0) {
                Write-Warning -Message ('Required element tags was empty for organization {0} repository {1}' -f $org,$name)
            }

            if ($contact.email -eq $null -or $contact.email -eq '') {
                Write-Warning -Message ('Required element contact.email was empty for organization {0} repository {1}' -f $org,$name)
            }

            if ($license.URL -eq $null -or $license.URL -eq '') {
                Write-Warning -Message ('Required element permissions.license.URL was empty for organization {0} repository {1}' -f $org,$name)
            }

            if ($license.name -eq $null -or $license.name -eq '') {
                Write-Warning -Message ('Required element permissions.license.name was empty for organization {0} repository {1}' -f $org,$name)
            }
            
            $status = if ($isArchived) { 'Archival' } else { 'Production'}
            
            $release = [ordered]@{
                'name' = $name; # required
                'repositoryURL' = $repositoryUrl; # required
                'description' = $description; # required
                'permissions' = $permissions; # required
                'laborHours' = 1; # required, needs to be manually updated
                'tags' = [string[]]@($tags); # required
                'contact' = [pscustomobject]$contact; # required

                #'version' = '' # optional
                'status' = $status; # optional
                'vcs' = 'git'; # optional
                'homepageURL' = $homepageUrl; # optional
                'downloadURL' = $downloadUrl; # optional
                'disclaimerURL' = $disclaimerUrl; # optional
                'date' = $date; # optional
            }

            if ($languages.Count -gt 0) {
                $release.Add('languages', $languages) # optional
            }

            $releases += [pscustomobject]$release
        }
    }

    $measurementType = [pscustomobject]@{
        'method' = 'projects';
    }

    $codeGov = [pscustomobject][ordered]@{
        'version' = '2.0'; # required
        'agency' = $AgencyName; # required
        'measurementType' = $measurementType; # required
        'releases' = $releases | Sort-Object -Property 'Name'; # required
    }

    return $codeGov
}

Function New-CodeGovJsonFile() {
    [CmdletBinding()] 
    [OutputType([void])]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='GitHub organization name(s)')]
        [ValidateNotNullOrEmpty()]
        [string[]]$Organization,

        [Parameter(Mandatory=$true, HelpMessage='The name of the agency')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyName,

        [Parameter(Mandatory=$true, HelpMessage='A email address that can be used as a contact point for agency open source releases')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyContactEmail,
        
        [Parameter(Mandatory=$false, HelpMessage='A description or name associated with agency email address')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyContactName,
        
        [Parameter(Mandatory=$false, HelpMessage='A URL containing contact information for agency open source releases')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyContactUrl,
        
        [Parameter(Mandatory=$false, HelpMessage='A phone number for agency open source releases')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyContactPhone,        

        [Parameter(Mandatory=$false, HelpMessage='Include private repositories in the code.json file')]
        [switch]$IncludePrivate,

        [Parameter(Mandatory=$false, HelpMessage='Include repositories that are forks of other projects')]
        [switch]$IncludeForks,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true, HelpMessage='Path to save the JSON file to')]
        [string]$Path
    )

    $parameters = $PSBoundParameters 

    $parameters.Remove('Path') | Out-Null

    New-CodeGovJson @parameters | ConvertTo-Json -Depth 5 | Out-File -FilePath $Path -Force -NoNewline -Encoding 'ASCII'
}

$script:codeGov20Schema = @'
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "Code.gov Inventory",
  "description": "A federal source code catalog",
  "type": "object",
  "properties": {
    "version": {
      "type": "string",
      "description": "The version of the metadata schema in use. Implements semantic versioning 2.0.0 rules as defined at http://semver.org"
    },
    "measurementType": {
      "type": "object",
      "properties": {
        "method": {
          "type": "string",
          "enum": [
            "linesOfCode",
            "modules",
            "cost",
            "projects",
            "systems",
            "other"
          ],
          "description": "An enumerated list of methods for measuring the open source requirement."
        },
        "ifOther": {
          "type": "string",
          "description": "A one- or two- sentence description of the measurement type used, if 'other' is selected as the value of 'method' field."
        }
      },
      "additionalProperties": false
    },
    "agency": {
      "type": "string",
      "description": "The agency acronym for Clinger Cohen Act agency, as defined by the United States Government Manual."

    },
    "releases": {
      "type": "array",
      "items": {
        "type": "object",
        "description": "An object containing each versioned source code release made available.",
        "properties": {
          "name": {
            "type": "string",
            "description": "The name of the release."
          },
          "version": {
            "type": "string",
            "description": "The version for this release. For example, '1.0.0'."
          },
          "organization": {
            "type": "string",
            "description": "The organization or component within the agency to which the releases listed belong. For example, '18F' or 'Navy'."
          },
          "description": {
            "type": "string",
            "description": "A one- or two-sentence description of the release."
          },

          "permissions": {
            "type": "object",
            "properties": {
              "licenses": {
                "type": ["array", "null"],
                "items": {
                  "type": "object",
                  "properties": {
                    "URL": {
                      "type": "string",
                      "format": "uri",
                      "description": "The URL of the release license, if available. If not, null should be used."
                    },
                    "name": {
                      "type": "string",
                      "description": "An abbreviation for the name of the license. For example, 'CC0' or 'MIT'."
                    }
                  },
                  "additionalProperties": false
                },
                "additionalProperties": false
              },
              "usageType": {
                "type": "string",
                "description": "A list of enumerated values which describes the usage permissions for the release.",
                "enum": [
                  "openSource",
                  "governmentWideReuse",
                  "exemptByLaw",
                  "exemptByNationalSecurity",
                  "exemptByAgencySystem",
                  "exemptByAgencyMission",
                  "exemptByCIO",
                  "exemptByPolicyDate"
                ],
                "additionalProperties": false
              },
              "exemptionText": {
                "type": [
                  "string",
                  "null"
                ],
                "description": "If an exemption is listed in the 'usageType' field, this field should include a one- or two- sentence justification for the exemption used."
              }
            },
            "required": ["licenses"]
          },
          "tags": {
            "type": "array",
            "items": {
              "type": "string",
              "description": "An array of keywords that will be helpful in discovering and searching for the release."
            }

          },
          "contact": {
            "type": "object",
            "properties": {
              "email": {
                "type": "string",
                "description": "The email address for the point of contact for the release."

              },
              "name": {
                "type": "string",
                "description": "The name of the point of contact for the release."

              },
              "URL": {
                "type": "string",
                "format": "uri",
                "description": "The URL to a website that can be used to reach the point of contact. For example, 'http://twitter.com/codeDotGov'."
              },
              "phone": {
                "type": "string",
                "description": "A phone number for the point of contact for the release."
              }
            },
            "required": ["email"],
            "additionalProperties": false
          },
          "status": {
            "type": "string",
            "description": "The development status of the release.",
            "enum": [
              "Ideation",
              "Development",
              "Alpha",
              "Beta",
              "Release Candidate",
              "Production",
              "Archival"
            ]
          },
          "vcs": {
            "type": "string",
            "description": "A lowercase string with the name of the version control system that is being used for the release. For example, 'git'."
          },
          "repositoryURL": {
            "type": ["string", "null"],
            "format": "uri",
            "description": "The URL of the public release repository for open source repositories. This field is not required for repositories that are only available as government-wide reuse or are closed (pursuant to one of the exemptions)."
          },
          "homepageURL": {
            "type": "string",
            "format": "uri",
            "description": "The URL of the public release homepage."
          },
          "downloadURL": {
            "type": "string",
            "format": "uri",
            "description": "The URL where a distribution of the release can be found."
          },
          "disclaimerURL": {
            "type": "string",
            "format": "uri",
            "description": "The URL where disclaimer language regarding the release can be found."
          },
          "disclaimerText": {
            "type": "string",
            "description": "Short paragraph that includes disclaimer language to accompany the release."
          },
          "languages": {
            "type": "array",
            "description": " An array of strings with the names of the programming languages in use on the release.",
            "items": {
              "type": "string"
            }
          },
          "laborHours": {
            "type": "number",
            "description": "An estimate of total labor hours spent by your organization/component across all versions of this release. This includes labor performed by federal employees and contractors."
          },
          "relatedCode": {
            "type": "array",
            "description": "An array of affiliated government repositories that may be a part of the same project. For example,  relatedCode for 'code-gov-web' would include 'code-gov-api' and 'code-gov-tools'.",
            "items": {
              "type": "object",
              "properties": {
                "name": {
                  "type": "string",
                  "description": "The name of the code repository, project, library or release."
                },
                "URL": {
                  "type": "string",
                  "format": "uri",
                  "description": "The URL where the code repository, project, library or release can be found."
                },
                "isGovernmentRepo": {
                  "type": "boolean",
                  "description": "Is the code repository owned or managed by a federal agency?"
                }
              },
              "additionalProperties": false
            }
          },
          "reusedCode": {
            "type": "array",
            "description": "An array of government source code, libraries, frameworks, APIs, platforms or other software used in this release. For example, US Web Design Standards, cloud.gov, Federalist, Digital Services Playbook, Analytics Reporter.",
            "items": {
              "type": "object",
              "properties": {
                "name": {
                  "type": "string",
                  "description": "The name of the software used in this release."
                },
                "URL": {
                  "type": "string",
                  "format": "uri",
                  "description": "The URL where the software can be found."
                }

              },
              "additionalProperties": false
            }
          },
          "partners": {
            "type": "array",
            "description": "An array of objects including an acronym for each agency partnering on the release and the contact email at such agency.",
            "items": {
              "type": "object",
              "properties": {
                "name": {
                  "type": "string",
                  "description": "The acronym describing the partner agency."
                },
                "email": {
                  "type": "string",
                  "description": "The email address for the point of contact at the partner agency."
                }
              },
              "additionalProperties": false
            }
          },
          "date": {
            "type": "object",
            "description": "A date object describing the release.",
            "properties": {
              "created": {
                "type": "string",
                "description": "The date the release was created, in YYYY-MM-DD or ISO 8601 format."
              },
              "lastModified": {
                "type": "string",
                "description": "The date the release was modified, in YYYY-MM-DD or ISO 8601 format."
              },
              "metadataLastUpdated": {
                "type": "string",
                "description": "The date the metadata of the release was last updated, in YYYY-MM-DD or ISO 8601 format."
              }
            },
            "additionalProperties": false
          }
        },
        "required": [
          "name",
          "permissions",
          "repositoryURL",
          "description",
          "laborHours",
          "tags",
          "contact"
        ]
      },
      "additionalProperties": false
    }
  },
  "required": [
    "version",
    "measurementType",
    "agency",
    "releases"
  ],
  "additionalProperties": false
}
'@

Function Test-CodeGovJsonFile() {
    [CmdletBinding()] 
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='GitHub organization name(s)')]
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true, HelpMessage='Path to save the JSON file to')]
        [string]$Path
    )
    
    $content = Get-Content -Path $Path -Raw 

    $codeGovJson = $content | ConvertFrom-Json

    $propertyNames = @('version','agency','measurementType','releases')
    
    $propertyNames | ForEach-Object {
        $propertyName = $_
        
        if (!($codeGovJson.PSObject.Properties.Name -contains $propertyName)) {
            Write-Warning -Message ('Required {0} property was missing' -f $propertyName)
        }     
    }
    
    $schema = [NewtonSoft.Json.Schema.JSchema]::Parse($script:codeGov20Schema)
    
    if (!$schema.Valid) {
        throw 'code.gov schema is not valid'
    }
    
    $settings = New-Object Newtonsoft.Json.Linq.JsonLoadSettings
    $settings.CommentHandling = [Newtonsoft.Json.Linq.CommentHandling]::Ignore
    $settings.LineInfoHandling = [Newtonsoft.Json.Linq.LineInfoHandling]::Load
    $json = [Newtonsoft.Json.Linq.JToken]::Parse($content, $settings)
    
    $validationErrors = $null
    
    $isValid = [NewtonSoft.Json.Schema.JSchema]::IsValid($content, $schema, $validationErrors)
    
    if (!$isValid -and $validationErrors -ne $null) {
        $validationErrors | ForEach-Object {
            Write-Warning -Message $_
        }
    }
    
    if ($codeGovJson.PSObject.Properties.Name -contains 'releases') {
        $codeGovJson.releases | ForEach-Object {
            $release = $_
    }
}

Function Add-Repository() {
    [CmdletBinding()] 
    [OutputType([void])]
    Param(
    )
}

Function Copy-PSObject() {
    [CmdletBinding()]
    [OutputType([psobject])]
        Param (
            [Parameter(Mandatory=$true, HelpMessage='The psobject to make a deep copy of')]
            [ValidateNotNullOrEmpty()]
            [object]$PSObject
        )

        if($PSObject -isnot [psobject]) {
            throw 'Input was not of type [psobject]'
        }

        $stream = New-Object System.IO.MemoryStream
        $formatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
        $formatter.Serialize($stream,$PSObject)
        $stream.Position = 0
        $copy = $formatter.Deserialize($stream)
        $stream.Close()
        $stream.Dispose()
        return [psobject]$copy
}

Function Invoke-CodeGovJsonOverride() {
    [CmdletBinding()] 
    [OutputType([void])]
    Param(
        [Parameter(Mandatory=$true, HelpMessage='The path of the original code.gov json file')]
        [ValidateNotNullOrEmpty()]
        [string]$OriginalJsonPath,

        [Parameter(Mandatory=$true, HelpMessage='The path of the new code.gov json file')]
        [ValidateNotNullOrEmpty()]
        [string]$NewJsonPath,

        [Parameter(Mandatory=$true, HelpMessage='The path of the overrides json file')]
        [ValidateNotNullOrEmpty()]
        [string]$OverrideJsonPath
    )

    $content = Get-Content -Path $OriginalJsonPath -Raw 
    
    $codeGovJson = $content | ConvertFrom-Json

    $content = Get-Content -Path $OverrideJsonPath -Raw

    $overridesJson = $content | ConvertFrom-Json

    $map = @{}

    $codeGovJson.releases | ForEach-Object {
        $map.Add($_.Name, (Copy-PSObject -PSObject $_))
    }

    $overridesJson.overrides | ForEach-Object {
        $override = $_
        $targetProject = $_.project
        $action = $_.action

        if ($map.ContainsKey($targetProject)) {
            $project = $map[$targetProject]
        } else {
            Write-Verbose -Message ('{0} release not found' -f $targetProject)
            return
        }

        switch ($action) {
            'replaceproperty' {
                $targetProperty = $override.property
                $targetValue = $override.value

                if (($project | Get-Member -MemberType 'NoteProperty' | Where-Object { $_.Name -eq ($targetProperty.Split('.')[0]) }) -ne $null) {
                    $props = $targetProperty.Split('.')

                    if ($props.Length -eq 1) {
                        $project.($targetProperty) = $targetValue
                        $map[$targetProject] = $project
                    } elseif ($props.Length -eq 2) {
                        $project.($props[0]).($props[1]) = $targetValue
                        $map[$targetProject] = $project
                    } elseif ($props.Length -eq 3) { # this is to support permissions.licenses[].name and .url
                        $project.($props[0]).($props[1])[0].($props[2]) = $targetValue # hardcoded for only 1 license existing in the array
                        $map[$targetProject] = $project
                    }
                } else {
                    Write-Verbose -Message ('{0} property not found for project {1}' -f $targetProperty,$targetProject)
                }

                return
            }
            'addproperty' {
                 $targetProperty = $override.property
                 $targetValue = $override.value

                 if (($project | Get-Member -MemberType 'NoteProperty' | Where-Object { $_.Name -eq ($targetProperty.Split('.')[0]) }) -ne $null) {
                     Write-Warning -Message ('{0} property already exists for project {1} use an action of replaceproperty in the overrides file' -f $targetProperty,$targetProject)
                 } else {
                     $project | Add-Member -MemberType NoteProperty -Name $targetProperty -Value $targetValue
                     $map[$targetProject] = $project
                 }

                 return
            }
            'removeproperty' {
                $targetProperty = $override.property

                 if (($project | Get-Member -MemberType 'NoteProperty' | Where-Object { $_.Name -eq ($targetProperty.Split('.')[0]) }) -ne $null) {
                     $props = $targetProperty.Split('.')

                     if ($props.Length -eq 1) {
                         $project.PSObject.Properties.Remove($targetProperty)
                         $map[$targetProject] = $project
                     } elseif ($props.Length -eq 2) {
                         $project.($props[0]).PSObject.Properties.Remove(($props[1]))
                         $map[$targetProject] = $project
                     }
                 } else {

                     Write-Warning -Message ('{0} property does not exist for project {1} so it cannot be removed' -f $targetProperty,$targetProject)
                 }
            }
            'removeproject' {
                if ($map.ContainsKey($targetProject)) {
                    $map.Remove($targetProject)
                } else {
                    Write-Warning -Message ('{0} project not found' -f $targetProject)
                }

                return
            }
            default { Write-Warning -Message ('{0} action not supported') }
        }
    }   

    $codeGovJson.releases = $map.Values | Sort-Object -Property 'Name'
    $codeGovJson | ConvertTo-Json -Depth 5 | Out-File -FilePath $NewJsonPath -Force -NoNewline -Encoding 'ASCII'
}


