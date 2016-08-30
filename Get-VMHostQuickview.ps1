function Get-VMHostQuickview {

Param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyname=$True)]
    [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost[]]
    $VMHost,

    [int]
    $LengthBar = 30,

    [int]
    $CPURed = 80,

    [int]
    $CPUYellow = 60,

    [int]
    $MEMRed = 80,

    [int]
    $MEMYellow = 60

)

Begin {
    $W = 0
    $VMHost.name | ForEach-Object {IF ($_.length -gt $W){$W = $_.length}}
    IF ("hostname".Length -lt $W) {$offset = $W - "hostname".Length + 7} else {$offset = 7}
    Write-Host "Hostname$(" " * $offset)CPU$(" " * ($LengthBar + 15 - "CPU".length))MEMORY"
}

Process {

    $VMHost | ForEach-Object {
        
        IF ($_.name.length -lt $W) {$offset = $W - $_.name.length + 7} else {$offset = 7}

        $vHost = [pscustomobject]@{

            Name          = $_.Name
            HostGHz       = [math]::round($_.CpuTotalMHz / 1000,0)
            HostGB        = [math]::round($_.ExtensionData.Summary.Hardware.MemorySize / 1GB,0)
            CPUUsageGHz   = [math]::round($_.CpuUsageMHz / 1000,0)
            MemoryUsageGB = [math]::round($_.MemoryUsageGB,0)
        }

        $UsedCPUBar = [math]::round($vHost.CPUUsageGHz / $vHost.HostGHz * $LengthBar,0)
        $FreeCPUBar = $LengthBar - $UsedCPUBar
        $CPUpercent = $UsedCPUBar / $LengthBar * 100
        IF ($CPUpercent -gt $CPURed) {$CPUcolor = "red"} ELSEIF ($CPUpercent -gt $CPUYellow) {$CPUcolor = "yellow"} ELSE {$CPUcolor = "green"}
        IF ($vHost.HostGHz -lt 10) {$PrintCPU = "$($vHost.HostGHz)  GHz"} ELSEIF ($vHost.HostGHz -lt 100) {$PrintCPU = "$($vHost.HostGHz) GHz"}ELSE{$PrintCPU = "$($vHost.HostGHz)GHz"}

        $UsedMEMBar = [math]::round($vHost.MemoryUsageGB / $vHost.HostGB * $LengthBar,0)
        $FreeMEMBar = $LengthBar - $UsedMEMBar
        $MEMpercent = $UsedMEMBar / $LengthBar * 100
        IF ($MEMpercent -gt $MEMRed) {$MEMcolor = "red"} ELSEIF ($MEMpercent -gt $CPUYellow) {$MEMcolor = "yellow"} ELSE {$MEMcolor = "green"}
        IF ($vHost.HostGB -lt 10) {$PrintMEM = "$($vHost.HostGB)  GB"} ELSEIF ($vHost.HostGB -lt 100) {$PrintMEM = "$($vHost.HostGB) GB"}ELSE{$PrintMEM = "$($vHost.HostGB)GB"}

        Write-Host "$($vHost.name)$(" " * $offset)" -NoNewline
        Write-Host "$("o" * $UsedCPUBar)" -ForegroundColor $CPUcolor -NoNewline
        Write-Host "$("-" * $FreeCPUBar): $PrintCPU" -NoNewline
        Write-Host "$(" " * 7)" -NoNewline
        Write-Host "$("o" * $UsedMEMBar)" -ForegroundColor $MEMcolor -NoNewline
        Write-Host "$("-" * $FreeMEMBar): $PrintMEM"

    } 

}

}