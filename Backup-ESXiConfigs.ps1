Function Backup-ESXiConfigs {

param (
    
    [ValidateNotNullOrEmpty()]
    [string]
    $BackupLocation,

    [ValidateNotNullOrEmpty()]
    [int]
    $FileRotation,

    [ValidateNotNullOrEmpty()]
    [string]
    $Server

)
    
    Add-PSSnapin VMware.VimAutomation.Core -ErrorAction Stop
    Connect-VIServer -Server $Server

    TRY {

        GET-VMHOST | ForEach-Object {
    
            $ESXiBak = "$BackupLocation\$($_.name)"

            IF (-not(Test-path $ESXiBak)) {MKDIR $ESXiBak}

            WHILE (((Get-ChildItem $ESXiBak).count) -gt $FileRotation) {Get-ChildItem $ESXiBak | Sort-Object lastwritetime | select -First 1 | Remove-Item -Force -Confirm:$false}

            Get-VMHostFirmware -VMHost $_.name -BackupConfiguration -DestinationPath $ESXiBak

            Get-ChildItem $ESXiBak | Sort-Object lastwritetime | select -Last 1 | Rename-Item -NewName "$(get-date -Format yyyy-MM-dd)_$($_.name).tgz"

        }
    } CATCH {

        Write-Error $_.Exception -ErrorAction Continue

    } Finally {Disconnect-VIServer -Confirm:$false}

    

}
