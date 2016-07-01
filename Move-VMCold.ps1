function Move-VMCold {

[CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'High')] 

param (
    [parameter(position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyname=$True,Mandatory=$True)]
    [VMware.VimAutomation.ViCore.types.V1.Inventory.VirtualMachine[]]
    $VM,

    [Parameter(Mandatory=$true)]
    [VMware.VimAutomation.ViCore.Types.V1.Inventory.VMHost]
    $Destination,

    [validateset("true","false")]
    [string]
    $PowerON="true"
)

Begin {

    $HostVlan = ($Destination | get-virtualportgroup).name
    $hostDS   = ($Destination | get-datastore).name

}

Process {

    $VM | ForEach-Object {
        
        $currentVM = $_


        $VMVlan   = ($currentVM | get-virtualportgroup).name
        $VMDS     = ($currentVM | get-datastore).name
        $Problems = @()
        $VMVlan | ForEach-Object { IF ($HostVlan -notcontains $_) {$Problems += $_} }
        $VMDS   | ForEach-Object { IF ($hostDS -notcontains $_)   {$Problems += $_} }


         IF ($PSCmdlet.ShouldProcess($currentVM.name,"Shut down and Move to $($Destination.name)") -and !$Problems) {

            TRY {
            
                IF ($currentVM.PowerState -eq "PoweredOn") {

                    Write-Verbose "Shutting down guest os on $($currentVM.name)"
                    $currentVM | Stop-VMGuest -Confirm:$False | Out-Null

                    Write-Warning "Waiting on $($currentVM.name) for PowerOff state"

                    While ((Get-vm $currentVM).PowerState -ne "PoweredOff") {

                        Write-Verbose "Wait for PowerOff state"
                        sleep 2 
                                           
                    }

                }

                Write-Verbose "vMotion $($currentVM.name) to $($Destination.name)"
                Move-VM -Destination $Destination -VM $currentVM -Confirm:$False | Out-Null

                IF ($PowerON -eq "True") {

                    Write-Verbose "Restart $($currentVM.name) on $($Destination.name)"
                    Start-VM $currentVM

                }

            }

            CATCH {Write-Error $_.Exception -ErrorAction Continue}

        } ELSEIF ($Problems) {Write-error "The following objects were not found on destination: $Problems"} #IF PScmdlet and $Problems

        Clear-Variable VMVlan,VMDS,Problems

    }#foreach VM

}#process

}
