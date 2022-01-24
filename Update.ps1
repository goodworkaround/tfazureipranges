[CmdletBinding()]

Param(
    [String] $url = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519"
)

# Download json file
$ProgressPreference = "SilentlyContinue"
$r = Invoke-WebRequest $url -UseBasicParsing -Verbose:$false
$url = [Regex]::Matches($r.Content,'"https://download.microsoft.com/(.)+json"')[-1].Value

if($url) {
    $url = $url.Trim('"')
    Write-Verbose "Downloading JSON from $url"
    $json = Invoke-RestMethod $url -ErrorAction Stop -Verbose:$false
} else {
    throw "Unable to determine url of JSON with IP addresses"
}

Function New-TerraformStringArrayOutput {
    [CmdletBinding()]

    Param(
        [string] $identifier,

        [string[]] $values
    ) 

    Process {
        $values | ForEach-Object `
            -Begin {
                $s = New-Object System.Collections.ArrayList
                $s.Add("output ""$identifier"" {`n  value = [") | Out-Null
            } `
            -Process {
                if(![String]::IsNullOrEmpty($_)) {
                    $s.Add("    ""$($_)"",") | Out-Null
                }
            } `
            -End {
                $s.Add("  ]") | Out-Null
                $s.Add("}") | Out-Null
                $s -join "`n"
            }
    }
}

Function New-TerraformStringOutput {
    [CmdletBinding()]

    Param(
        [string] $identifier,

        [string] $value
    ) 

    Process {
        "output ""$identifier"" {`n  value = ""$value""`n}"
    }
}

if($PSScriptRoot) {Set-Location $PSScriptRoot}
Remove-Item -Path Generated -Force -Confirm:$false -Recurse
mkdir Generated | Out-Null

$regionids = @{
    "0" = "Global"
}

$json.values | 
    Sort-Object -Property id |
    ForEach-Object `
        -Begin {
            $inc = 1
            $total = $json.values | Measure-Object | Select-Object -ExpandProperty Count
        } `
        -Process {
            Write-Verbose "Processing entry $inc / $total - $($_.id)"
            $inc += 1

            $regionfolder = "Generated/$($_.properties.regionId)"
            $servicefolder = "Generated/$($_.properties.systemService)"
            
            if(!(Test-Path $regionfolder)) {
                mkdir $regionfolder | Out-Null
            }

            if(!(Test-Path $servicefolder)) {
                mkdir $servicefolder | Out-Null
            }

            if(!$regionids.ContainsKey("$($_.properties.regionId)")) {
                $regionids["$($_.properties.regionId)"] = $_.name -split "\." | Select-Object -Last 1
            }

            $tfnameregion = "{0}_region{1}" -f $_.properties.systemService, $_.properties.regionId
            if([String]::IsNullOrEmpty($_.properties.systemService)) {
                $tfnameregion = "region{1}" -f $_.properties.systemService, $_.properties.regionId
            }
            $tfnameservice = "region{0}" -f $_.properties.regionId

            $ipv4 = $_.properties.addressPrefixes | Where-Object {$_ -like "*.*.*.*"}
            $ipv6 = $_.properties.addressPrefixes | Where-Object {$_ -like "*:*:*"}
            $ip = $_.properties.addressPrefixes | Where-Object {$_ -like "*.*.*.*" -or $_ -like "*:*:*"}

            
            New-TerraformStringArrayOutput -identifier "$($tfnameregion)_ipv4" -values $ipv4 | Add-Content "$regionfolder/outputs.tf"
            New-TerraformStringArrayOutput -identifier "$($tfnameregion)_ipv6" -values $ipv6 | Add-Content "$regionfolder/outputs.tf"
            New-TerraformStringArrayOutput -identifier "$($tfnameregion)" -values $ip | Add-Content "$regionfolder/outputs.tf"
            
            if(![String]::IsNullOrWhiteSpace($_.properties.systemService)) {
                New-TerraformStringArrayOutput -identifier "$($tfnameservice)_ipv4" -values $ipv4 | Add-Content "$servicefolder/outputs.tf"
                New-TerraformStringArrayOutput -identifier "$($tfnameservice)_ipv6" -values $ipv6 | Add-Content "$servicefolder/outputs.tf"
                New-TerraformStringArrayOutput -identifier "$($tfnameservice)" -values $ip | Add-Content "$servicefolder/outputs.tf"
            }
        }

Get-ChildItem Generated | ForEach-Object `
    -Begin {
        $tfoutputs = @(
            New-TerraformStringOutput -identifier "change_number" -value $json.changeNumber
            New-TerraformStringOutput -identifier "file_name" -value (Split-path $url -Leaf)
            New-TerraformStringOutput -identifier "file_url" -value $url
            New-TerraformStringOutput -identifier "file_date" -value ((Split-path $url -Leaf).Split(".")[0]).Split("_")[-1]
            New-TerraformStringOutput -identifier "cloud" -value $json.cloud
        )
    } `
    -Process {
        Set-Content -path "$($_.FullName)/metadata.tf" -Verbose -Value $tfoutputs
    }

$regionids.Keys | 
    ForEach-Object{[int] $_} | 
    Sort-Object | 
    ForEach-Object `
    -Begin {
        $README = Get-Content README_top.md
        $README += "| Region ID | Name |"
        $README += "| - | - |"
    } `
    -Process {
        $README += "| {0} | {1} |" -f $_, $regionids["$($_)"]
        
        $README | Set-Content README.md
    }