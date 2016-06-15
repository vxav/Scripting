function Assign-TagQOS {

param(
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [string]$vCenterServer
)

    $ErrorActionPreference = 'stop'
    Add-PSSnapin VMware.VimAutomation.Core
    $Session = Connect-VIServer -Server $vCenterServer 3>&1 | Out-Null

    Get-Tag -Name "QOS_*" | ForEach-Object {

        try {

            $tag = $_

            IF ($tag.name -eq "QOS_NOLIMIT") {
                $Limit = $null                      ; $Check = -1
            } ELSE {
                $Limit = (($tag.name).Trim("QOS_")) ; $Check = $Limit
            }

            Get-VM -Tag $tag | Get-VMResourceConfiguration | Where-Object {$_.CpuLimitMhz -ne $Check} |

                Set-VMResourceConfiguration -CpuLimitMhz $Limit | Select-Object VM,@{l='Tag';e={$tag.name}},CpuLimitMhz
        }
    
        catch {Write-Error $_.Exception -ErrorAction Continue}

        Clear-Variable Limit,tag
    
    }
} 
