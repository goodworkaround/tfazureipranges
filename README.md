# Terraform Azure IP Ranges module

This module provides automatically up to date outputs for all IP ranges found in the [Azure IP Ranges json document](https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519).

All regions are identified using IDs from the table further down on this page.

# Example 1 - Getting NorwayEast and WestEurope IPs for AzureBackup

```HCL
module "azurebackup" {
    source = "github.com/goodworkaround/tfazureipranges/Generated/AzureBackup"
}

output "norwayeast" {
    value = module.azurebackup.region63 # NorwayEast
}

output "westeurope" {
    value = module.azurebackup.region18 # WestEurope
}
```

# Example 2 - Getting several NorthEurope services

```HCL
module "northeurope" {
    source = "github.com/goodworkaround/tfazureipranges/Generated/17"
}

output "AppServiceManagement" {
    value = module.northeurope.AppServiceManagement
}

output "All" {
    value = module.northeurope.All
}
```

# Example 3 - Getting all IPv4 IPs used by Azure Monitor globally

```HCL
module "azureglobal" {
    source = "github.com/goodworkaround/tfazureipranges/Generated/0"
}

output "AzureMonitor" {
    value = module.azureglobal.AzureMonitor
}
```

# Region ID to region name

| Region ID | Name |
| - | - |
| 0 | Global |
| 1 | EastAsia |
| 2 | SoutheastAsia |
| 3 | AustraliaEast |
| 4 | AustraliaSoutheast |
| 8 | taiwannorth |
| 9 | BrazilSouth |
| 10 | chilec |
| 11 | CanadaCentral |
| 12 | CanadaEast |
| 15 | easteurope |
| 16 | northeurope2 |
| 17 | NorthEurope |
| 18 | WestEurope |
| 19 | FranceCentral |
| 20 | FranceSouth |
| 21 | CentralIndia |
| 22 | SouthIndia |
| 23 | WestIndia |
| 24 | JapanEast |
| 25 | JapanWest |
| 26 | KoreaCentral |
| 27 | UKSouth |
| 28 | UKWest |
| 29 | UKNorth |
| 30 | UKSouth2 |
| 31 | CentralUS |
| 32 | EastUS |
| 33 | EastUS2 |
| 34 | NorthCentralUS |
| 35 | SouthCentralUS |
| 36 | WestCentralUS |
| 37 | WestUS |
| 38 | WestUS2 |
| 48 | CentralUSEUAP |
| 49 | EastUS2EUAP |
| 50 | KoreaSouth |
| 52 | PolandCentral |
| 53 | mexicocentral |
| 58 | AustraliaCentral |
| 59 | AustraliaCentral2 |
| 60 | UAENorth |
| 61 | UAECentral |
| 63 | NorwayEast |
| 64 | JioIndiaCentral |
| 65 | JioIndiaWest |
| 66 | SwitzerlandNorth |
| 67 | SwitzerlandWest |
| 68 | EastUSSTG |
| 69 | SouthCentralUSSTG |
| 71 | GermanyWestCentral |
| 72 | GermanyNorth |
| 74 | NorwayWest |
| 75 | SwedenSouth |
| 76 | SwedenCentral |
| 77 | BrazilSoutheast |
| 78 | brazilne |
| 79 | WestUS3 |
| 82 | SouthAfricaNorth |
| 83 | SouthAfricaWest |
| 84 | QatarCentral |
| 85 | IsraelCentral |
| 88 | spaincentral |
| 91 | newzealandnorth |
| 92 | malaysiawest |
| 93 | italynorth |
| 94 | EastUSSLV |
| 95 | austriaeast |
| 96 | taiwannorthwest |
| 97 | belgiumcentral |

