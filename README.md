# PSCodeGov
Creates a [code.gov](https://code.gov/) [code inventory JSON file](https://code.gov/#/policy-guide/docs/compliance/inventory-code) based on GitHub repository information.

```
Import-Module -Name .\PSCodeGov.psm1

Set-OAuthToken -Token insertgithubapitokenvaluehere

New-CodeGovJsonFile -Organization iadgov -AgencyName 'NSA Information Assurance' -AgencyContactEmail 'iad_ccc@nsa.gov' -AgencyContactName 'NSA IA Client Contact Center' -AgencyContactUrl 'https://www.iad.gov/iad/help/contact/index.cfm' -AgencyContactPhone '410-854-4200' -Path "$env:userprofile\Desktop\code.json"
```

## License
See [LICENSE](./LICENSE.md).

## Contributing
See [CONTRIBUTING](./CONTRIBUTING.md).

## Disclaimer
See [DISCLAIMER](./DISCLAIMER.md).