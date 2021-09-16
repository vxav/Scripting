Function Port-Ping {

param(
    [Parameter(ValueFromPipeline = $True)]
    [string]
    $IP,

    [ValidateRange(1,65535)]
    [int]
    $Port,

    [int]
    $Timeout

)

$before = get-date

$PortPing = New-Object System.Net.Sockets.TCPClient

$PortConnect = $PortPing.beginConnect("$IP",$Port,$null,$null)

While (((get-date) -lt $before.AddMilliseconds($Timeout)) -and ($PortPing.Connected -ne "true")) {}

$timems = [math]::round(((get-date) - $before).TotalMilliseconds,0)

[pscustomobject]@{

    LocalEndpoint   = $PortPing.Client.LocalEndPoint
    RemoteEndpoint  = $PortPing.Client.RemoteEndPoint
    Status          = $PortPing.Connected
    Timems          = $timems

}

$PortPing.Close()

}

Function Icmp-Ping {

param(
    [Parameter(ValueFromPipeline = $True)]
    [string]
    $IP,

    [int]
    $Timeout,

    [int]
    $Buffer,

    [System.Net.NetworkInformation.PingOptions]
    $icmpOption

)

$icmpconnect = $icmpping.Send("$IP",$Timeout,$buffer,$icmpoptions)

[pscustomobject]@{

    RemoteEndpoint = $IP
    Bytes          = $buffer
    Time           = IF ($icmpconnect.Status -eq "Success") {$icmpconnect.RoundtripTime} ELSE {$icmpconnect.Status}
    TTL            = $icmpconnect.Options.Ttl

} 

}

Function Pingou {

<#

.NOTES
---------------------------
Website : www.vxav.fr
Email   : contact@vxav.fr
---------------------------

.SYNOPSIS
Test the connectity to a destination on ICMP or any specified TCP port.

.DESCRIPTION


.PARAMETER DESTINATION
Remote IP or hostname to test.

.PARAMETER COUNT
(-t) Number of test issued.

.PARAMETER PORT
TCP port to check on the remote host, validate range is 1 to 65535.

.PARAMETER CONTINUOUS
(-n) Number of tests infinite. can be stopped with ctrl+c or by closing the invite.

.PARAMETER TIMEOUT
(-w) Number of milliseconds after which a timeout is issued for each test.

.PARAMETER DELAYMS
Number of milliseconds between each test.

.PARAMETER HOPS
(-i) Number of hops after which the packet is dropped (TTL expired). Works only with ICMP tests.

.PARAMETER BUFFER
(-l) Size in bytes of the buffer to send. Works only with ICMP tests.

#>

[CmdletBinding(DefaultParameterSetName=1)]  

param(
    [Parameter(Mandatory=$true,ValueFromPipeline = $True,position=0)]
    [string]
    $Destination,

    [parameter(position=1)]
    [ValidateRange(1,65535)]
    [int]
    $Port,

    [parameter(parametersetname=2)]
    [Alias('t')]
    [switch]
    $Continuous,

    [parameter(parametersetname=1)]
    [Alias('n')]
    [int]
    $Count = 4,

    [Alias('w')]
    [int]
    $Timeout = 1000,

    [ValidateRange(50,10000)]
    [int]
    $Delayms = 750,

    [ValidateRange(1,255)]
    [Alias('i')]
    [int]
    $Hops = 128,

    [ValidateRange(1,255)]
    [Alias('l')]
    [int]
    $Buffer = 32,

    [switch]
    $NoResolv = $false

)

#$ErrorActionPreference = "SilentlyContinue"

if (!$NoResolv) {
    $Resolve = [System.Net.Dns]::GetHostAddresses($Destination).IPAddressToString
    IF ($Resolve.count -gt 1) {$Resolve = $Resolve[0]}
} else {$Resolve = $Destination}

IF ($Resolve) {

    IF ($Port) {

        While ($i -lt $Count) {

            Port-Ping -IP $Resolve -Port $Port -Timeout $Timeout
            IF (!$Continuous) {$i++}
            Sleep -Milliseconds $Delayms

        }

    } ELSE {

        $icmpping = New-Object system.Net.NetworkInformation.Ping

        $icmpoptions = New-Object System.Net.NetworkInformation.PingOptions($Hops,$false)

        While ($i -lt $Count) {

            Icmp-Ping -IP $Resolve -Timeout $Timeout -icmpOption $icmpoptions -Buffer $Buffer
            IF (!$Continuous) {$i++}
            Sleep -Milliseconds $Delayms

        }

    }

} ELSE { # ELSE RESOLVE

    Write-Warning "cannot resolve $Destination"

}

}

Function zListener {

[CmdletBinding(DefaultParameterSetName="Close")]  

Param(
    [parameter(Mandatory=$true,position=0)]
    [ValidateRange(1,65536)]
    [int]
    $Port,

    [parameter(parametersetname='Close')]
    [int]
    $Timeout,

    [parameter(parametersetname='NoClose')]
    [switch]
    $NoClose
)

TRY {

    #Initialize TTL
    $date = (Get-Date).AddSeconds($Timeout)

    #Check if already listening on port, if yes error and close
    $ListeningPorts = ([System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()).port
    IF ($ListeningPorts -eq $Port) {Throw "Already listening on port $Port"}

    #Initialize listener
    $listener = [System.Net.Sockets.TcpListener]$Port
    $listener.start()

    Write-Warning "Waiting for a connection on port $Port..."

    IF ($NoClose) {while ($true) {}}

        $ar = $listener.BeginAcceptTcpClient($null,$null)    

        #Check if asynchronous handle established every 1 second or within timeout
        IF ($Timeout) {while (($ar.AsyncWaitHandle.WaitOne([timespan]'0:0:1') -eq $false) -and ((Get-Date) -lt $date)) {}}
        ELSE {while ($ar.AsyncWaitHandle.WaitOne([timespan]'0:0:1') -eq $false) {}}

        #Display remote IP/Port
        IF ($ar.AsyncWaitHandle.WaitOne([timespan]'0:0:1')) {

            $client = $listener.EndAcceptTcpClient($ar)

            Write-Host "$($client.Client.RemoteEndPoint) ==> OK ==> $($client.Client.LocalEndPoint)" -ForegroundColor Green

        } ELSE {

            Write-Host "Reached $Timeout sec timeout : No handshake established" -ForegroundColor red 

        }     

} Finally {

    $listener.Stop()

} #Close TCP listener anyway

}

Function zPinger {

param(
    [Parameter(ValueFromPipeline = $True)]
    [string[]]
    $IPs = @("8.8.8.8","109.233.117.100","109.233.117.108","172.31.1.5","134.19.161.153","10.39.0.3"),

    [ValidateRange(1,65536)]
    [int]
    $Port

)

    Write-Host "Initializing"
 
        $DashOffset = 2
        $ping = New-Object system.Net.NetworkInformation.Ping
        IF ($input) {$IPs = $input}
  

    While ($True) {

        $Width = ($Host.UI.RawUI.WindowSize.Width - $DashOffset)

        $Table = @()
    
        $IPs | ForEach-Object {
            $IP = $_
            $i = 0
        
            While (($i -lt 3) -and ($result.status -ne "Success")) {
                $Result = $ping.Send($IP,800)
                $i++
            }

            IF ($IP.Length -le 15) {$IP = "$IP $(' ' * (15 - $IP.Length))"}

            $Table += [PSCustomObject]@{
                    Time     = (Get-Date -Format T)
                    IP       = $IP
                    Result   = $result.Status
                    PingTime = $result.RoundtripTime
            }
            Clear-Variable Result
        } # IPs foreach
    
        Sleep 1

        CLS

        $Table | ForEach-Object {
            IF ($_.Result -eq "Success"){

                $output = "$($_.Time) | $($_.IP) | $($_.PingTime)"
            
                Write-Host "$output $(' ' * ($Width - $output.length))" -backgroundcolor Green -ForegroundColor black

            } ELSE {

                $output = "$($_.Time) | $($_.IP) | $($_.Result)"
            
                Write-Host "$output $(' ' * ($Width - $output.length))" -backgroundcolor Red -ForegroundColor black
            }
        }
    } # while true

}

Function Test-IPExist {

<#
.SYNOPSIS
    
.DESCRIPTION
    This function will check if an IP:
    - Replies to ping
    - Has TCP 3389 open (RDP)
    - Goes into the ARP cache
    - Exists in DNS
    
    It can verify multiple IPs

.EXAMPLE
    > Test-IPExist -IP "10.10.10.10"

    Address : 10.10.10.10
    ICMP    : False
    RDP     : False
    ARP     : False
    DNS     : False

.EXAMPLE
    Test the range 10.10.10.10 to 10.10.10.20

    > $IPs = 10..20 | foreach-object {"10.10.10.$_"}
    > Test-IPExist -IP $IPs | ft

    Address                        ICMP               RDP               ARP              DNS
    -------                        ----               ---               ---              ---
    10.10.10.10                   False             False             False            False
    10.10.10.11                   False             False             False            False
    10.10.10.12                   False             False             False            False
    10.10.10.13                   False             True              True             True
    10.10.10.14                   False             False             False            False
    10.10.10.15                   False             False             False            False
    10.10.10.16                   False             False             False            False
    10.10.10.17                   False             True              True             True
    10.10.10.18                   False             False             False            False
    10.10.10.19                   True              False             True             True
    10.10.10.20                   True              True              True             True

.EXAMPLE
    Test and Display the resolvable IPs.

    PS> Test-IPExist -IP $dns -Timeoutms 100 -DisplayIP | ft -au

    Address                        ICMP   RDP   ARP   DNS IP
    -------                        ----   ---   ---   --- --
    CS-P-VDIAP51.consilium.eu.int False False False  True 170.255.69.126 170.255.69.111
    CS-P-VDIAP53.consilium.eu.int False False False  True 170.255.69.113
    CS-P-VDIAP55.consilium.eu.int False False False False
    CS-P-VDIAP52.consilium.eu.int False  True False  True 170.255.69.112
    CS-P-VDIAP54.consilium.eu.int False  True False  True 170.255.69.114
    CS-P-VDIAP56.consilium.eu.int False  True False  True 170.255.69.116
    cs-p-vdidb56.consilium.eu.int False False False  True 170.255.69.247
#>

param (
    [string[]]
    $IP,

    [int]
    $Timeoutms = 500,

    [switch]
    $DisplayIP
)

ForEach ($Address in $IP) {
    
    $ErrorActionPreference = "silentlycontinue"

    $PortPing = New-Object System.Net.Sockets.TCPClient
    $PortConnect = $PortPing.beginConnect("$Address",3389,$null,$null)
    
    $icmpping = New-Object system.Net.NetworkInformation.Ping
    $icmpconnect = $icmpping.Send("$Address",$Timeoutms)
    if ($icmpconnect.status -eq "success") {$icmp = $true} else {$icmp = $false}

    $Arp = arp -a
    if ($arp -match " $Address ") {$arp = $True} else {$arp=$False}

    $DNS = $false

    $params = @{Address=$Address; ICMP=$icmp; RDP=$PortPing.Connected; ARP=$ARP; DNS=$DNS}
    if ($DisplayIP) {$params.Add('IP',"")}

    if ($DNS = [System.Net.Dns]::GetHostEntry("$Address")) {       
        if ($DisplayIP) {$params.IP = [string]$DNS.AddressList.IPAddressToString}
        $params.DNS = $True
    }

    $PortPing.Close()

    New-Object -TypeName psobject -Property $params | select Address,ICMP,RDP,ARP,DNS,*

}

}

