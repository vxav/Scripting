Function VMPing {

[CmdletBinding(DefaultParameterSetName="1")]

param(
    [parameter(position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyname=$True,Mandatory=$True)]
    $VM,

    [parameter(parametersetname=1)][Alias('n')][int]$Count = 4,
    [parameter(parametersetname=2)][Alias('t')][switch]$Continuous,
    [ValidateRange(50,10000)][int]$Delayms = 700,
    [Alias('w')][int]$Timeout = 800,

    [switch]$enableIPv6
)

    TRY {

        IF (!($VM -as [VMware.VimAutomation.ViCore.types.V1.Inventory.VirtualMachine]) -as [bool]) {
            $VMnotFound = $VM
            $VM = Get-VM $VM -ErrorAction SilentlyContinue
            IF (!$VM) {throw "$VMnotFound not found"}
        } 

            
        IF ($VM.powerstate -eq "poweredon") {

            $IP = $VM.ExtensionData.guest.net.ipaddress
            IF (!$enableIPv6) {$IP = $IP | where {($_ -as [ipaddress]).AddressFamily -eq "InterNetwork"}} #exclude IPv6 addresses

            $ping = New-Object system.Net.NetworkInformation.Ping
            $r = 0

                while ($r -lt $count) {

                    $Table = @()

                    $IP | ForEach-Object {
                        $Result = $ping.Send($_,$Timeout)
                        [pscustomobject]@{

                            VM             = $VM.name
                            IP             = $_
                            Time           = IF ($result.Status -eq "Success") {$result.RoundtripTime} ELSE {$result.Status}
                            TTL            = $result.Options.Ttl

                        } 
                    }
                    Sleep -Milliseconds $Delayms
                    IF (!$Continuous) {$r++}
            
              }

    } ELSE {Write-Warning "$($VM.name) is powered off"}

    } CATCH {
        Write-Warning $_.Exception -ErrorAction Stop
    }
}