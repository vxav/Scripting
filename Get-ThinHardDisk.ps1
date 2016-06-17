Function Get-ThinHardDisk {

param(
    [parameter(position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyname=$True)]
    [ValidateNotNullOrEmpty()]
    [VMware.VimAutomation.ViCore.types.V1.Inventory.VirtualMachine[]]
    $VM = (get-VM)
)

Process{

    $VM | ForEach-Object {

        (Get-HardDisk -VM ($_) | where StorageFormat -eq Thin) | select Parent,Name,CapacityGB,StorageFormat

    }

}

}