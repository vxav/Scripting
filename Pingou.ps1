﻿Function Port-Ping {

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

} #Pingou subfunction

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

} #Pingou subfunction

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
Pingou allows to test connectivity to a remote host as well as a TCP port in a simplistic and intuitive way.
The command works almost like the ping command with the same main parameter letters (aliases).
To check if a port is open you just need to append the port number to the regular command to get the usual 4 checks output.

> Pingou 8.8.8.8

RemoteEndpoint Bytes Time TTL
-------------- ----- ---- ---
8.8.8.8           32   18  59
8.8.8.8           32   24  59
8.8.8.8           32   29  59
8.8.8.8           32   54  59

> Pingou 8.8.8.8 53

LocalEndpoint      RemoteEndpoint Status Timems
-------------      -------------- ------ ------
192.168.0.12:49783 8.8.8.8:53       True     47
192.168.0.12:49784 8.8.8.8:53       True     16
192.168.0.12:49785 8.8.8.8:53       True     16
192.168.0.12:49786 8.8.8.8:53       True     16

.REMARKS
Pingou doesn't support the specification of a source ip yet.

.PARAMETER DESTINATION
Remote IP or hostname to test.

.PARAMETER COUNT
(-n) Number of test issued.

.PARAMETER PORT
TCP port to check on the remote host, validate range is 1 to 65535.

.PARAMETER CONTINUOUS
(-t) Number of tests infinite. can be stopped with ctrl+c or by closing the invite.

.PARAMETER TIMEOUT
(-w) Number of milliseconds after which a timeout is issued for each test.

.PARAMETER DELAYMS
Number of milliseconds between each test.

.PARAMETER HOPS
(-i) Number of hops after which the packet is dropped (TTL expired). Works only with ICMP tests.

.PARAMETER BUFFER
(-l) Size in bytes of the buffer to send. Works only with ICMP tests.

.EXAMPLE
> Pingou 8.8.8.8

RemoteEndpoint Bytes Time TTL
-------------- ----- ---- ---
8.8.8.8           32   18  59
8.8.8.8           32   24  59
8.8.8.8           32   29  59
8.8.8.8           32   54  59

.EXAMPLE
> pingou 8.8.8.8 -n 3 -l 255

RemoteEndpoint Bytes Time TTL
-------------- ----- ---- ---
8.8.8.8          255   16  59
8.8.8.8          255   29  59
8.8.8.8          255   19  59

.EXAMPLE
 > Pingou -destination 8.8.8.8 -port 53

LocalEndpoint      RemoteEndpoint Status Timems
-------------      -------------- ------ ------
192.168.0.12:49783 8.8.8.8:53       True     47
192.168.0.12:49784 8.8.8.8:53       True     16
192.168.0.12:49785 8.8.8.8:53       True     16
192.168.0.12:49786 8.8.8.8:53       True     16

.EXAMPLE
> pingou www.google.fr 80 -Timeout 10 -Count 2 -Delayms 200

LocalEndpoint RemoteEndpoint   Status Timems
------------- --------------   ------ ------
0.0.0.0:51376 62.252.232.55:80  False     10
0.0.0.0:51377 62.252.232.55:80  False     10


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
    $Buffer = 32

)

#$ErrorActionPreference = "SilentlyContinue"

$Resolve = [System.Net.Dns]::GetHostAddresses($Destination).IPAddressToString
IF ($Resolve.count -gt 1) {$Resolve = $Resolve[0]}

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


