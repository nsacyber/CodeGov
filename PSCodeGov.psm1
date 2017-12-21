#requires -Version 3
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

Function Get-OAUthToken() {
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

    $urls = [string[]]@(('{0}/blob/{1}/LICENSE' -f $Url,$Branch),('{0}/blob/{1}/LICENSE.md' -f $Url,$Branch))

    $urls = $urls | ForEach-Object { 
        if (Test-Url -Url $_ ) { 
            $license = $_ 
            return
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

    $license = $null

    $urls = [string[]]@(('{0}/blob/{1}/DISCLAIMER' -f $Url,$Branch),('{0}/blob/{1}/DISCLAIMER.md' -f $Url,$Branch))

    $urls = $urls | ForEach-Object { 
        if (Test-Url -Url $_ ) { 
            $license = $_ 
            return
        } 
    }

    return $license
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
        $repositories = Get-GitHubRepositories -Organization $_

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

            $licenseUrl = Get-GitHubRepositoryLicenseUrl -Url $repositoryUrl -Branch $branch
            $licenseUrl = if ($licenseUrl -eq $null) { 'null'} else { $licenseUrl }
            
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
                'URL' = $licenseUrl; # required
                'name' = 'Manually add license name'; # required, needs to be manually updated
            }

            $licenses = @($license)
            
            $permissions = [pscustomobject]@{
                'licenses' = $licenses; # required
                'usageType' = 'openSource'; # required
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

        [Parameter(Mandatory=$true, HelpMessage='Path to save the JSON file to')]
        [string]$Path
    )

    $parameters = $PSBoundParameters 

    $parameters.Remove('Path') | Out-Null

    New-CodeGovJson @parameters | ConvertTo-Json -Depth 5 | Out-File -FilePath $Path -Force -NoNewline -Encoding 'ASCII'
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

    $codeGovJson.projects | ForEach-Object {
        $map.Add($_.Name, (Copy-PSObject -PSObject $_))
    }

    $overridesJson.overrides | ForEach-Object {
        $override = $_
        $targetProject = $_.project
        $action = $_.action

        if ($map.ContainsKey($targetProject)) {
            $project = $map[$targetProject]
        } else {
            Write-Verbose -Message ('{0} project not found' -f $targetProject)
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

    $codeGovJson.projects = $map.Values | Sort-Object -Property 'Name'
    $codeGovJson | ConvertTo-Json -Depth 5 | Out-File -FilePath $NewJsonPath -Force -NoNewline -Encoding 'ASCII'
}


