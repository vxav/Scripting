Function Get-Datastore2 {

param(
    [parameter(position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyname=$True)]
    [VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.VmfsDatastore[]]
    $Datastore
)

Process{

    $Datastore | ForEach-Object {

        [pscustomobject]@{
            Name          = $_.name
            CapacityGB    = [Math]::Round(($_.extensiondata.summary.capacity   / 1GB),2)
            FreeSpaceGB   = [Math]::Round(($_.extensiondata.summary.FreeSpace  / 1GB),2)
            UsedSpaceGB   = [Math]::Round((($_.extensiondata.summary.capacity  / 1GB) - ($_.extensiondata.summary.FreeSpace / 1GB)),2)
            ProvisionedGB = [Math]::Round((($_.extensiondata.summary.capacity  / 1GB) - ($_.extensiondata.summary.FreeSpace / 1GB) + ($_.extensiondata.summary.Uncommitted / 1GB)),2)
            NbRunningVMs  = ($_ | Get-VM | where powerstate -eq Poweredon).count
        }

    }

}

}