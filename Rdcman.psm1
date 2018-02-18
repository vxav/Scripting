Function Add-RDCManVM {

param(
    [System.IO.FileInfo]
    $RdgFilePath,
    
    [parameter(position=0)]
    [VMware.VimAutomation.ViCore.types.V1.Inventory.VirtualMachine[]]
    $VM,

    [string]
    $Group
)

# RDCMan must be closed otherwise the changes won't persist
if (get-process RDCMan -ErrorAction SilentlyContinue) {Write-Warning "Close RDCMan before running editting the file"; break}

# Grab rdg file
$rdgfile    = Get-ChildItem $RdgFilePath
$RdgContent = $rdgfile | Get-Content

# Check if group exists
if (!($RdgContent -match "<name>$Group</name>")) {Write-Warning "No $Group group found in specified rdg file"; break}

# Process VMs

$VM = $VM | where {$_.powerstate -eq "poweredon" -and $_.guest.OSFullName -match "windows"}

foreach ($V in $VM) {

    if ($v.guest.OSFullName -match "windows" -and !($RdgContent -match "<displayName>$($v.guest.HostName)</displayName>") -and !($RdgContent -match "<name>$IP</name>")) {
        
        $i++

        Write-Progress -Activity "Group $Group : VM #$i/$($VM.count)" -Status $V.name -PercentComplete ($i/$VM.count*100)

        $IP = $v.guest.IPAddress | where {$_ -like "*.*.*.*"}
        if ($ip.count -gt 1){$connectName = $ip[0]}else{$connectName = $ip}
        $VMNotes = @()
        $VMNotes += $v.Notes
        $v.CustomFields | where value | ForEach-Object {$VMNotes += "$($_.key) = $($_.value)"}


        $AddContent += 
@"
      <server>
        <properties>
          <displayName>$($v.guest.HostName)</displayName>
          <name>$($connectName)</name>
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
    
    
    } else {"$($v.name): non windows host or already in rdg file"}

}

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

    Write-Progress -Activity "Domain $VMDomain : Domain #$a/$($Domains.count)" -Status $VMDomain -PercentComplete ($a/$Domains.count*100)

    $V = $VM | where {$_.guest.ExtensionData.IpStack.dnsconfig.domainname -eq $VMDomain}

    Add-RDCManVM -RdgFilePath $RdgFilePath -VM $V -Group $VMDomain

}

Write-Progress -Activity "Domain No-Domain : Domain #$a/$($Domains.count)" -Status "No-Domain" -PercentComplete ($a++/$Domains.count*100)

$VMNoDomain = $VM | where {!($_.guest.ExtensionData.IpStack.dnsconfig.domainname)}
Add-RDCManVM -RdgFilePath $RdgFilePath -VM $VMNoDomain -Group "No-Domain"

"-End-"
}
