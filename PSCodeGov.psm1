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

        [Parameter(Mandatory=$true, HelpMessage='A generic email address that can be used as a contact point for agency open source releases')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyEmail,
        
        [Parameter(Mandatory=$false, HelpMessage='A description of the generic agency email address')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyEmailDescription,

        [Parameter(Mandatory=$false, HelpMessage='Include private repositories in the code.json file')]
        [switch]$IncludePrivate,

        [Parameter(Mandatory=$false, HelpMessage='Include repositories that are forks of other projects')]
        [switch]$IncludeForks
    )

    $Organization | ForEach-Object {
        $repositories = Get-GitHubRepositories -Organization $_

        $projects = @()

        $contact = [pscustomobject][ordered]@{
            'email' = $AgencyEmail; # required
            'name' =  $AgencyEmailDescription; # optional
        }
        
        $repositories | Where-Object { $_.private -eq $IncludePrivate -and $_.fork -eq $IncludeForks } | ForEach-Object {
            $branch = $_.default_branch

            $name = $_.name
            $repository = $_.html_url
            $description = if ($_.description -eq $null) { 'No description provided' } else { $_.description }
            $tags = if ($_.topics -eq $null -or $_.topics.Count -eq 0) { [string[]]@('none') } else { [string[]]@($_.topics) }
            $homepage = if ($_.homepage -eq $null -or $_.homepage -eq '') { $repository } else { $_.homepage }
            $languages = Get-GitHubRepositoryLanguages -Url $_.languages_url
            $lastUpdated = $_.updated_at
            $lastCommit = $_.pushed_at

            $license = Get-GitHubRepositoryLicenseUrl -Url $repository -Branch $branch
            $license = if ($license -eq $null) { 'null'} else { $license }

            $download = Get-GitHubRepositoryReleaseUrl -Url $_.releases_url
            $download = if ($download -eq $null) {  ('{0}/archive/{1}.zip' -f $repository,$branch) } else { $download }

            $updated = [pscustomobject]@{
                'metadataLastUpdated' = $lastUpdated; # optional
                'lastCommit' = $lastCommit; # optional
            }

            $project = [ordered]@{
                'name'= $name; # required
                'repository' = $repository; # required
                'description' = $description; # required
                'license' = $license ; # required
                'openSourceProject' = [int]!$IncludePrivate; # required 
                'governmentWideReuseProject' = '1'; # required
                'tags' = $tags; # required
                'contact' = $contact; # required
                'vcs' = 'git'; # optional
                'homepage' = $homepage; # optional
                'downloadURL' = $download ; # optional, actually downloadURL?
                'updated' = $updated; # optional
            }

            if ($languages.Count -gt 0) {
                $project.Add('languages', $languages) # optional
            }

            $projects += [pscustomobject]$project
        }
    }

    $codeGov = [pscustomobject][ordered]@{
        'version' = '1.0.1';
        'agency' = $AgencyName; # required
        'projects' = $projects | Sort-Object -Property 'Name';
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

        [Parameter(Mandatory=$true, HelpMessage='A generic email address that can be used as a contact point for agency open source releases')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyEmail,
        
        [Parameter(Mandatory=$false, HelpMessage='A description of the generic agency email address')]
        [ValidateNotNullOrEmpty()]
        [string]$AgencyEmailDescription,

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

