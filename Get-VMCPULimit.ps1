Function Get-VMCpuLimit {

Param(
     [parameter(position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyname=$True,Mandatory=$True)]
     [VMware.VimAutomation.ViCore.types.V1.Inventory.VirtualMachine[]]
     $VM
)

$VM | ForEach-Object {
    
    [pscustomobject]@{
        VM    = $_.name
        Limit = $_.ExtensionData.Config.CpuAllocation.Limit
    }
}

}