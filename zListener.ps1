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

            Write-Host "$($client.Client.RemoteEndPoint) => OK => $($client.Client.LocalEndPoint)" -ForegroundColor Green

        } ELSE {

            Write-Host "Reached $Timeout sec timeout : No handshake established" -ForegroundColor Green -BackgroundColor Black

        }     

} Finally {

    $listener.Stop()

} #Close TCP listener anyway

}