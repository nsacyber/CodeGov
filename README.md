# CodeGov
Creates a [code.gov](https://code.gov/) [code inventory JSON file](https://code.gov/#/policy-guide/docs/compliance/inventory-code) based on GitHub repository information.

The CodeGov PowerShell module is used to generate the [NSA Cybersecurity GitHub code.gov JSON file](https://nsacyber.github.io/code.json).

## Getting started

To get started using the tools:

1. [Install](#installing-prerequisites) prerequisites
1. [Download](#downloading-the-repository) the repository as a zip file 
1. [Configure PowerShell](#configuring-the-powershell-environment) 
1. [Load the code](#loading-the-code) 
1. [Run the code](#running-the-code) 

## Installing prerequisites
This module depends on [NewtonSoft.Json](https://github.com/JamesNK/Newtonsoft.Json/releases) and [NewtonSoft.Json.Schema](https://github.com/JamesNK/Newtonsoft.Json.Schema/releases) for validation of the generated code.gov JSON file. Download the latest release from each project and use [gacutil](https://docs.microsoft.com/en-us/dotnet/framework/tools/gacutil-exe-gac-tool) to install the files to the Global Assembly Cache (GAC).

Install NewtonSoft.Json:
* gacutil -i %userprofile%\Downloads\Json110r2\Bin\net40\Newtonsoft.Json.dll
* gacutil -i %userprofile%\Downloads\Json110r2\Bin\net45\Newtonsoft.Json.dll

Install NewtonSoft.Json.Schema:
* gacutil -i %userprofile%\Downloads\\JsonSchema30r10\Bin\net40\Newtonsoft.Json.Schema.dll
* gacutil -i %userprofile%\Downloads\\JsonSchema30r10\Bin\net45\Newtonsoft.Json.Schema.dll

## Downloading the repository

Download the [current code](https://github.com/nsacyber/CodeGov/archive/master.zip) to your **Downloads** folder. It will be saved as **PSCodeGov-master.zip** by default.

## Configuring the PowerShell environment
The PowerShell commands are meant to run from a system with at least PowerShell 4.0 and .Net 4.5 installed. PowerShell may need to be configured to run the commands.

### Changing the PowerShell execution policy

Users may need to change the default PowerShell execution policy. This can be achieved in a number of different ways:

* Open a command prompt and run **powershell.exe -ExecutionPolicy Unrestricted** and run scripts from that PowerShell session. 
* Open a PowerShell prompt and run **Set-ExecutionPolicy Unrestricted -Scope Process** and run scripts from the current PowerShell session. 
* Open an administrative PowerShell prompt and run **Set-ExecutionPolicy Unrestricted** and run scripts from any PowerShell session. 

### Unblocking the PowerShell scripts
Users will need to unblock the downloaded zip file since it will be marked as having been downloaded from the Internet which PowerShell will block from executing by default. Open a PowerShell prompt and run the following commands to unblock the PowerShell code in the zip file:

1. `cd $env:USERPROFILE` 
1. `cd Downloads` 
1. `Unblock-File -Path '.\CodeGov-master.zip'`

Running the PowerShell scripts inside the zip file without unblocking the file will result in the following warning:

*Security warning*
*Run only scripts that you trust. While scripts from the internet can be useful, this script can potentially harm your computer. If you trust this script, use the Unblock-File cmdlet to allow the script to run without this warning message. Do you want to run C:\users\user\Downloads\script.ps1?*
*[D] Do not run [R] Run once [S] Suspend [?] Help (default is "D"):*


If the downloaded zip file is not unblocked before extracting it, then all the individual PowerShell files that were in the zip file will have to be unblocked. You will need to run the following command after Step 5 in the [Loading the code](#loading-the-code) section:

```
Get-ChildItem -Path '.\CodeGov' -Recurse -Include '*.ps1','*.psm1','*.psd1' | Unblock-File -Verbose
```

See the [Unblock-File command's documentation](https://docs.microsoft.com/en-us/powershell/module/Microsoft.PowerShell.Utility/Unblock-File?view=powershell-5.1) for more information on how to use it.

### Loading the code
Now extract the downloaded zip file and load the PowerShell code used for apply the policies.

1. Right click on the zip file and select **Extract All**
1. At the dialog remove **CodeGov-master** from the end of the path since it will extract the files to a CodeGov-master folder by default
1. Click the **Extract** button
1. From the previously opened PowerShell prompt, rename the **CodeGov-master** folder to **CodeGov** `mv .\CodeGov-master\ .\CodeGov\`
1. `cd CodeGov`
1. Inside the **CodeGov** folder is another folder named **CodeGov** which is a PowerShell module. Move this folder to a folder path in your $PSModulePath such as **C:\\users\\*username*\\Documents\\WindowsPowerShell\\Modules**
1. `mv .\CodeGov "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"`

### Running the code
See the [GenerateCodeGovJson file] in the [Examples](./Examples) folder for an example of how to use the module.

## License
See [LICENSE](./LICENSE.md).

## Contributing
See [CONTRIBUTING](./CONTRIBUTING.md).

## Disclaimer
See [DISCLAIMER](./DISCLAIMER.md).