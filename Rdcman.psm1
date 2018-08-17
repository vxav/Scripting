<#

xavier.avrillier@gmail.com

Create an "RDCMan ready" RDG file with all the running Windows VMs connected in PowerCLI.

- Only Windows OS is supported.
- The VM must have the VMware tools installed.
- RDCMan must be closed.

[ Update 201808/17 ]

- Added 3389 TCP port check on VM IP(s) - Set the first one the responds as hostname and "NO-RDP-RESPONSE" if none does.
- Added TCPCheckTimeout parameter to Add-RDCManVM function to configure the time it takes for the TCP port check to time out.

#>

Function Add-RDCManVM {

param(
    [System.IO.FileInfo]
    $RdgFilePath,
    
    [parameter(position=0)]
    [VMware.VimAutomation.ViCore.types.V1.Inventory.VirtualMachine[]]
    $VM,

    [int]
    $TCPCheckTimeout = 300

)

# RDCMan must be closed otherwise the changes won't persist
if (get-process RDCMan -ErrorAction SilentlyContinue) {Write-Warning "Close RDCMan before running editting the file"; break}

# Grab rdg file
$rdgfile    = Get-ChildItem $RdgFilePath
$RdgContent = $rdgfile | Get-Content


# Process VMs

$VM = $VM | where {$_.powerstate -eq "poweredon" -and $_.guest.OSFullName -match "windows"}

foreach ($V in $VM) {

    if ($v.guest.OSFullName -match "windows" -and !($RdgContent -match "<displayName>$($v.guest.HostName)</displayName>") -and !($RdgContent -match "<name>$IP</name>")) {

        $Prog++

        if (!$v.guest.ExtensionData.IpStack.dnsconfig.domainname) {$group = "No-Domain"}
        else {$group = $v.guest.ExtensionData.IpStack.dnsconfig.domainname}
        $group = $group.ToLower()

        # Check if group exists
        if (!($RdgContent -match "<name>$Group</name>")) {Write-Warning "Group $Group found in specified rdg file; $($V.name) skipped"; break}


        Write-Progress -Activity "Group $Group : VM #$Prog/$($VM.count)" -Status $V.name -PercentComplete ($Prog/$VM.count*100) -Id 1

        $IP = $v.guest.IPAddress | where {$_ -like "*.*.*.*"}

        while (!$3389 -and $i -lt $ip.count) {
            foreach ($IPP in $IP) {
                $PortPing = New-Object System.Net.Sockets.TCPClient
                
                # Try TCP port and stop after the $TCPCheckTimeout timeout
                $ExecFrame = (get-date).AddMilliseconds($TCPCheckTimeout)
                
                $PortConnect = $PortPing.BeginConnect("$IPP",3389,$null,$null)

                While (((get-date) -lt $ExecFrame) -and ($PortPing.Connected -ne "true")) {}
                
                # Populate $3389 and break from loop if tcp open
                if ($PortPing.Connected) {$3389 = $IPP; break}
                $PortPing.Close()

                $i++
            }
        }

        if (!$3389) {$3389 = "NO-RDP-RESPONSE"}

        $VMNotes = @()
        $VMNotes += $v.Notes
        $v.CustomFields | where value | ForEach-Object {$VMNotes += "$($_.key) = $($_.value)"}


        $AddContent += 
@"
      <server>
        <properties>
          <displayName>$($v.guest.HostName)</displayName>
          <name>$($3389)</name>
          <comment>$($v.guest.HostName)
VM     : $($v.name)
Cluster: $($v | get-cluster | select -ExpandProperty name)
IP(s)  : $([string]$IP)
OS     : $($v.guest.OSFullName)
VM Notes:
$($VMNotes -replace "@",' at ' -replace "<","" -replace ">","" -replace "&"," and ")
</comment>
        </properties>
      </server>
"@
    
    Clear-Variable i,3389 -ErrorAction SilentlyContinue
    
    } else {Write-warning "$($v.name): non windows host or already in rdg file"}

}

if (!$AddContent) {break}

# Find the index of the record </properties> following the group name
$StringIndexToReplace = ($RdgContent | where {$_ -match "<name>$Group</name>"}).readcount

# If more than one record the script will fail as it is not expecting an array
if ($StringIndexToReplace.count -gt 1) {Write-Warning "More than one entity called $Group"; break}

# Append the new servers to the record </Properties>
$RdgContent[$StringIndexToReplace] = "</properties>$AddContent"

# Write the rdg file
$RdgContent | Out-File $rdgfile -Confirm:$false -Encoding utf8

"File written"

}

Function New-RDCManFile {

param(
    [System.IO.FileInfo]
    $RdgFilePath,
    
    [parameter(position=0)]
    [VMware.VimAutomation.ViCore.types.V1.Inventory.VirtualMachine[]]
    $VM
)

Write-Progress -Activity "Creating base rdg file"
$VM = $VM | where {$_.powerstate -eq "poweredon" -and $_.guest.OSFullName -match "windows"}
$Domains = $VM | select @{l="domain";e={$_.guest.ExtensionData.IpStack.dnsconfig.domainname}} | where domain | select -ExpandProperty domain -Unique domain

$DomTxt = @"
    <group>
      <properties>
        <expanded>False</expanded>
        <name>No-Domain</name>
      </properties>
    </group>
"@

foreach ($dom in $Domains) {
$DomTxt += @"
    <group>
      <properties>
        <expanded>False</expanded>
        <name>$dom</name>
      </properties>
    </group>
"@
}

@"
<?xml version="1.0" encoding="utf-8"?>
<RDCMan programVersion="2.7" schemaVersion="3">
  <file>
    <credentialsProfiles />
    <properties>
      <expanded>True</expanded>
      <name>$($DefaultVIServer.name)</name>
    </properties>
    <remoteDesktop inherit="None">
      <sameSizeAsClientArea>True</sameSizeAsClientArea>
      <fullScreen>False</fullScreen>
      <colorDepth>24</colorDepth>
    </remoteDesktop>
$DomTxt
  </file>
  <connected />
  <favorites />
  <recentlyUsed />
</RDCMan>
"@ | Out-File $RdgFilePath

ForEach ($VMDomain in $Domains) {
    
    $a++

    Write-Progress -Activity "Domain #$a/$($Domains.count)" -Status $VMDomain -PercentComplete ($a/$Domains.count*100)

    $V = $VM | where {$_.guest.ExtensionData.IpStack.dnsconfig.domainname -eq $VMDomain}

    Add-RDCManVM -RdgFilePath $RdgFilePath -VM $V

}

Write-Progress -Activity "Domain No-Domain : Domain #$a/$($Domains.count)" -Status "No-Domain" -PercentComplete ($a++/$Domains.count*100) -Id 0

$VMNoDomain = $VM | where {!($_.guest.ExtensionData.IpStack.dnsconfig.domainname)}
Add-RDCManVM -RdgFilePath $RdgFilePath -VM $VMNoDomain

"-End-"
}
