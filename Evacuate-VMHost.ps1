Function Evacuate-VMHost {

param (
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyname=$True)]
    [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
    $VMHost,

    [ValidateRange(1,100)]
    [int]
    $VMHostMaxCPUUsagePercent = 75,

    [ValidateRange(1,100)]
    [int]
    $VMHostMaxMEMUsagePercent = 75,

    [int]
    $VMHostMaxVCpuPerCore = 9,

    [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]
    $ExcludedVMHost,

    [VMware.VimAutomation.ViCore.types.V1.Inventory.VirtualMachine[]]
    $ExcludedVM,

    [switch]
    $fullyAutomated,

    [switch]
    $Whatif
)

Try {

    IF ($VMHost.connectionstate -eq "connected") {

    $VM = $VMHost | Get-VM | where {$_ -notin $ExcludedVM}

        $VM | where powerstate -eq poweredon | ForEach-Object {
        
            $CurVM = $_

            $PossibleHost = Get-VMHost `
                | Where name -ne $VMHost.name `
                | where {$_ -notin $ExcludedVMHost} `
                | where connectionstate -eq "connected" `
                | where {(Compare-Object $CurVM.ExtensionData.network.value $_.ExtensionData.network.value).sideindicator -notcontains "<="}

            $i = 0
            $choice = "a"

            $selectedVMHost = $PossibleHost | ForEach-Object {
            
                $i++

                $HostVM = $_ | get-vm | where powerstate -eq poweredon

                [pscustomobject]@{
                    id = $i
                    name = $_.name
                    "ProjectedCpuUsage" = [math]::round(($_.CpuUsageMhz + $CurVM.ExtensionData.Runtime.MaxCpuUsage) / $_.CpuTotalMhz * 100,1)
                    "ProjectedMemUsage" = [math]::round(($_.MemoryUsageMB + $CurVM.memoryMB) / $_.MemoryTotalMB * 100,1)
                    "ProjectedVCPUperCORE" =[math]::round(($HostVM | Measure-Object -Property numcpu -Sum).sum / $_.NumCpu,1)
                    "Projected#LiveVM" = $HostVM.count + 1
                }

            } | where {$_.ProjectedCpuUsage -lt $VMHostMaxCPUUsagePercent -and $_.ProjectedMemUsage -lt $VMHostMaxMEMUsagePercent -and $_.ProjectedVCPUperCORE -lt $VMHostMaxVCpuPerCore}

            IF ($selectedVMHost) {

                $BestVMHost = $selectedVMHost | where id -eq ($selectedVMHost | select id,@{l="sum";e={$_.ProjectedCpuUsage + $_.ProjectedMemUsage}} | Sort-Object sum | select -First 1).id

                ($selectedVMHost | where id -eq $BestVMHost.id).id = "*"

                IF (!$fullyAutomated) {

                    Clear-Host

                    $_ | select name,powerstate,numcpu,memorygb
                
                    $selectedVMHost | Sort-Object id | ft -au

                    Write-Host "Select host manually by its ID"
                    Write-Host "Press enter to follow the recommendation ( * )"
                    Write-Host "Enter N to skip this VM"

                    While ($choice -notin @("","n") -and $choice -notin (1..$i)) { $choice = Read-Host " " }

                    IF (!$Choice) {$selectedVMHost = $BestVMHost}
                        ELSEIF ($choice -eq "n") {Write-Warning "$($CurVM.name) skipped"}
                            ELSE {$selectedVMHost = $selectedVMHost | where id -eq $Choice}

                } ELSE {
                    $selectedVMHost = $BestVMHost
                }

                IF ($choice -ne "n") {

                    Write-Host "$($CurVM.name) moving to $($selectedVMHost.name)" -ForegroundColor green

                    $params = @{VM = $_ ; Destination = get-vmhost $selectedVMHost.name}

                    IF ($Whatif) {$params.Add('whatif', $true)}

                    Move-VM @params | Out-Null

                }

            } ELSE {Write-Warning "There is no host capable of fulfilling the destination resource requirements"}

        }

    } ELSE {Write-warning "$($VMHost.name) is in a $($VMHost.connectionstate) state"}

} CATCH {
    Write-Error $_.Exception -ErrorAction stop
}

}