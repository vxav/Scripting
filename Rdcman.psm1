<#

xavier.avrillier@gmail.com

Create an "RDCMan ready" RDG file with all the running Windows VMs connected in PowerCLI.

- Only Windows OS is supported.
- The VM must have the VMware tools installed.
- RDCMan must be closed.

### CHANGE LOG

    01/03/2019
    ! Bug found - The RDG file must be opened at least once before running the set command to update it

    07/11/2018
    - [Set-RDCManFile] Adds new VMs and new domains to an existing file.
    - Added Function Set-RDCManFile.

    17/08/2018
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
if (get-process RDCMan -ErrorAction SilentlyContinue) {Write-Warning "Close RDCMan before editing the file"; break}

# Grab rdg file
$rdgfile    = Get-ChildItem $RdgFilePath
$RdgContent = $rdgfile | Get-Content


# Process VMs

$VM = $VM | where {$_.powerstate -eq "poweredon" -and $_.guest.OSFullName -match "windows"}

foreach ($V in $VM) {

    if ($v.guest.OSFullName -match "windows" -and !($RdgContent -match "<displayName>$($v.guest.HostName)</displayName>") -and !($RdgContent -match "<name>$IP</name>")) {
        
        if ($v.guest.State -eq "Running") { # Tools running

        $Prog++

        if (!$v.guest.ExtensionData.IpStack.dnsconfig.domainname) {$group = "No-Domain"}
        else {$group = $v.guest.ExtensionData.IpStack.dnsconfig.domainname}
        $group = $group.ToLower()

        # Check if group exists
        if (!($RdgContent -match "<name>$Group</name>")) {Write-Warning "Group $Group not found in specified rdg file; $($V.name) skipped"; break}


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
vCenter: $($DefaultVIServer.name)
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

    } else {Write-Warning "Tools not running on $($v.name)"} # Tools running
    
    } else {Write-warning "$($v.name): not a windows host or already in rdg file"}

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

Function Start-RDCMan {

param(
    [System.IO.FileInfo]
    $RdgFile
)

"Opening $RdgFile in RDCMan (required before using Set-RDCManFile)"

Start-Process $RdgFile

While ( !(get-process RDCMan -ErrorAction SilentlyContinue) ) {sleep -Milliseconds 200}

}

Function New-RDCManFile {

param(
    [System.IO.FileInfo]
    $RdgFilePath,
    
    [parameter(position=0)]
    [VMware.VimAutomation.ViCore.types.V1.Inventory.VirtualMachine[]]
    $VM
)

# RDCMan must be closed otherwise the changes won't persist
if (get-process RDCMan -ErrorAction SilentlyContinue) {Write-Warning "Close RDCMan before editing the file"; break}

Write-Progress -Activity "Gathering VM and Domain lists"
$VM = $VM | where {$_.powerstate -eq "poweredon" -and $_.guest.OSFullName -match "windows"}
$Domains = $VM | select @{l="domain";e={$_.guest.ExtensionData.IpStack.dnsconfig.domainname}} | where domain | select -ExpandProperty domain -Unique domain

Write-Progress -Activity "Creating base rdg file"
$RDGFile = New-Item -Path $RdgFilePath -ItemType File -Force

# Prepare the no-domain section
$DomTxt = @"
    <group>
      <properties>
        <expanded>False</expanded>
        <name>No-Domain</name>
      </properties>
    </group>
"@

# Prepare each domain's section
foreach ($dom in $Domains.tolower()) {
$DomTxt += @"
    <group>
      <properties>
        <expanded>False</expanded>
        <name>$dom</name>
      </properties>
    </group>
"@
}

# Fit the prepared section in the global rdg frame and write to file
@"
<?xml version="1.0" encoding="utf-8"?>
<RDCMan programVersion="2.7" schemaVersion="3">
  <file>
    <credentialsProfiles />
    <properties>
      <expanded>True</expanded>
      <name>$($RDGFile.BaseName)</name>
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

    # Gather all VMs that are part of the domain being currently processed
    $V = $VM | where {$_.guest.ExtensionData.IpStack.dnsconfig.domainname -eq $VMDomain}

    # Add gathered VMs to the created RDG file
    Add-RDCManVM -RdgFilePath $RdgFilePath -VM $V

}

Write-Progress -Activity "Domain No-Domain : Domain #$a/$($Domains.count)" -Status "No-Domain" -PercentComplete ($a++/$Domains.count*100) -Id 0

$VMNoDomain = $VM | where {!($_.guest.ExtensionData.IpStack.dnsconfig.domainname)}
Add-RDCManVM -RdgFilePath $RdgFilePath -VM $VMNoDomain

"-End-"

Start-RDCMan -RdgFilePath $RdgFile

}

Function Set-RDCManFile {

param(
    [System.IO.FileInfo]
    $RdgFilePath,
    
    [parameter(position=0)]
    [VMware.VimAutomation.ViCore.types.V1.Inventory.VirtualMachine[]]
    $VM
)

if ( !($RDGFile = Get-ChildItem $RdgFilePath) ) { Break }

# RDCMan must be closed otherwise the changes won't persist
if (get-process RDCMan -ErrorAction SilentlyContinue) {Write-Warning "Close RDCMan before editing the file"; break}

Write-Progress -Activity "Updating base rdg file"
$VM = $VM | where {$_.powerstate -eq "poweredon" -and $_.guest.OSFullName -match "windows"}
$Domains = $VM | select @{l="domain";e={$_.guest.ExtensionData.IpStack.dnsconfig.domainname}} | where domain | select -ExpandProperty domain -Unique domain

[xml]$DataXML = Get-content $RdgFilePath

# Enter loop for each detected domain
foreach ($dom in $Domains.tolower()) {

# If current domain not in rdg file
if ($DataXML.rdcman.file.group.properties.name -notcontains $dom) {
    $DomTxt += @"
    <group>
      <properties>
        <expanded>False</expanded>
        <name>$dom</name>
      </properties>
    </group>
"@
}

}

# Add sections for new domains in the rdg file
if ($DomTxt) {
    (Get-content $RDGFile) -replace "</file>","$DomTxt
    </file>" | Out-File $RdgFile
}

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

Start-RDCMan -RdgFile $RdgFilePath

}

