function Move-VMCold {

[CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'High')] 

param (
    [parameter(position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyname=$True,Mandatory=$True)]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl[]]
    $VM,

    [Parameter(Mandatory=$true)]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]
    $Destination,

    [validateset("true","false")]
    [string]
    $PowerON="true"
)

Process {

    $VM | ForEach-Object {
        
        $currentVM = $_

         IF ($PSCmdlet.ShouldProcess($currentVM.name,"Shut down and Move to $($Destination.name)")) {

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

        }#IF PScmdlet

    }#foreach

}#process

}