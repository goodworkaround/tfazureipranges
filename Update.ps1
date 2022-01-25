[CmdletBinding()]

Param(
    [String] $url = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519"
)

# Download json file
$ProgressPreference = "SilentlyContinue"
$r = Invoke-WebRequest $url -UseBasicParsing -Verbose:$false
$url = [Regex]::Matches($r.Content,'"https://download.microsoft.com/(.)+json"')[-1].Value

# Locate url
if($url) {
    $url = $url.Trim('"')
    Write-Verbose "Downloading JSON from $url"
    $json = Invoke-RestMethod $url -ErrorAction Stop -Verbose:$false
} else {
    throw "Unable to determine url of JSON with IP addresses"
}

# Function to return a HCL string array output
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

# Function to return a HCL string output
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

# Clean up Generated folder
if($PSScriptRoot) {Set-Location $PSScriptRoot}
$originalhash = (Get-ChildItem -Recurse -File | Where-Object extension -in ".tf",".md" | Get-FileHash | Sort-Object Path | ForEach-Object{$_.Hash}) -join ""
Remove-Item -Path Generated -Force -Confirm:$false -Recurse
mkdir Generated | Out-Null

# Map to store all region ids
$regionids = @{
    "0" = "Global"
}

# Loop through all entries in the json in an ordered manner (to make sure files are always the same)
$json.values | 
    Where-Object id -notlike "*.*Stage" |
    Sort-Object -Property id |
    ForEach-Object `
        -Begin {
            # Progress tracking
            $inc = 1
            $total = $json.values | Measure-Object | Select-Object -ExpandProperty Count
        } `
        -Process {
            # Progress tracking
            Write-Verbose "Processing entry $inc / $total - $($_.id)"
            $inc += 1

            $service = $_.properties.systemService
            if($_.id -like "*.*" -and $($_.properties.regionId) -ne "0") {
                $service = $_.id -split "\." | Select-Object -First 1
            } elseif($_.id -ne "AzureCloud") {
                $service = $_.id -replace "\.","_"
            }

            # Create folders for services and regions
            $regionfolder = "Generated/$($_.properties.regionId)"
            $servicefolder = "Generated/$($service)"
            
            if(!(Test-Path $regionfolder)) {
                mkdir $regionfolder | Out-Null
            }

            if(!(Test-Path $servicefolder)) {
                mkdir $servicefolder | Out-Null
            }

            # Add the regionid to the regionid map
            if(!$regionids.ContainsKey("$($_.properties.regionId)")) {
                $regionids["$($_.properties.regionId)"] = $_.name -split "\." | Select-Object -Last 1
            }

            
            $tfnameregion = "{0}" -f $service
            #if("$($_.properties.regionId)" -eq "0") {
            #    $tfnameregion = "{0}_region{1}" -f $service, $_.properties.regionId
            #} else
            if([String]::IsNullOrEmpty($service)) {
                $tfnameregion = "region{1}" -f $service, $_.properties.regionId
            }
            $tfnameservice = "region{0}" -f $_.properties.regionId

            # Extract IP addresses split by ipv4 and ipv6
            $ipv4 = $_.properties.addressPrefixes | Where-Object {$_ -like "*.*.*.*"}
            $ipv6 = $_.properties.addressPrefixes | Where-Object {$_ -like "*:*:*"}
            $ip = $_.properties.addressPrefixes | Where-Object {$_ -like "*.*.*.*" -or $_ -like "*:*:*"}

            # Add to the region, as everything will point to one. 0 is global.
            New-TerraformStringArrayOutput -identifier "$($tfnameregion)_ipv4" -values $ipv4 | Add-Content "$regionfolder/outputs.tf"
            New-TerraformStringArrayOutput -identifier "$($tfnameregion)_ipv6" -values $ipv6 | Add-Content "$regionfolder/outputs.tf"
            New-TerraformStringArrayOutput -identifier "$($tfnameregion)" -values $ip | Add-Content "$regionfolder/outputs.tf"
            
            # If systemService is set, add entry to the service folder
            if(![String]::IsNullOrWhiteSpace($_.properties.systemService)) {
                New-TerraformStringArrayOutput -identifier "$($tfnameservice)_ipv4" -values $ipv4 | Add-Content "$servicefolder/outputs.tf"
                New-TerraformStringArrayOutput -identifier "$($tfnameservice)_ipv6" -values $ipv6 | Add-Content "$servicefolder/outputs.tf"
                New-TerraformStringArrayOutput -identifier "$($tfnameservice)" -values $ip | Add-Content "$servicefolder/outputs.tf"
            # Otherwise, if the name if AzureCloud (Global), add "All" to the region output
            } elseif($_.name -like "AzureCloud.*") {
                New-TerraformStringArrayOutput -identifier "All_ipv4" -values $ipv4 | Add-Content "$regionfolder/outputs.tf"
                New-TerraformStringArrayOutput -identifier "All_ipv6" -values $ipv6 | Add-Content "$regionfolder/outputs.tf"
                New-TerraformStringArrayOutput -identifier "All" -values $ip | Add-Content "$regionfolder/outputs.tf"
            }
        }

# Generate metadata.tf files
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

# Generate README.md
$README = Get-Content README.template

# Add region id table
$regionids.Keys | 
    ForEach-Object{[int] $_} | 
    Sort-Object | 
    ForEach-Object `
    -Begin {
        $REGIONIDTABLE = "| Region ID | Name |`n"
        $REGIONIDTABLE += "| - | - |`n"
    } `
    -Process {
        $REGIONIDTABLE += "| {0} | {1} |`n" -f $_, $regionids["$($_)"]
    } `
    -End {
        $README = $README -creplace "REGIONIDTABLE", $REGIONIDTABLE
    }


$OUTPUTSECTIONS = Get-ChildItem Generated | 
    Where-Object {Test-path (Join-Path $_.FullName "outputs.tf")} |
    ForEach-Object {
        if($regionids.ContainsKey($_.BaseName)) {
            $regionname = $regionids[$_.BaseName]
            "## Region $regionname"

        } else {
            "## $($_.BaseName)"
        }

        ""
        "``````HCL"
        'module "modulename" {'
        '  source = "github.com/goodworkaround/tfazureipranges/Generated/{0}"' -f $_.BaseName
        '}'
        "``````"
        ""
        "Available outputs:"
        ""

        Get-Content (Join-Path $_.FullName "outputs.tf") | 
            Where-Object {$_ -like "output*"} |
            ForEach-Object {$_ -split '"' | Select-Object -Index 1} |
            ForEach-Object {
                "- $($_)"
            }
        ""
    }

$README = $README -creplace "OUTPUTSECTIONS", ($OUTPUTSECTIONS -join "`n")

#$README -creplace "LASTUPDATE", (Get-Date).ToString("yyyy-MM-dd HH:mm")
$README | Set-Content README.md

$hash = (Get-ChildItem -Recurse -File | Where-Object extension -in ".tf",".md" | Get-FileHash | Sort-Object Path | ForEach-Object{$_.Hash}) -join ""
if($hash -ne $originalhash) {
    Write-Host "Found diff - commiting"
    git config --local user.email "noreply@goodworkaround.com"
    git config --local user.name "github-actions[bot]"
    git commit -m "Add changes" -a
} else {
    Write-Host "No updates required :)"
}