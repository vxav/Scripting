Function Get-VsanHealthSilentChecks {

<#
.SYNOPSIS
    Function : Get-VsanHealthSilentChecks
    EMail    : Xavier.avrillier@gmail.com
    Date     : 25/04/2018
    Info     : Display all health checks that have been silenced.

.DESCRIPTION
Display all health checks that have been silenced.

.PARAMETER Cluster
Specify a Cluster object (Get-Cluster)
#>

param(
    [parameter(ValueFromPipeline=$True,Mandatory=$True)]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl]
    $Cluster
)

Process {

    $VsanView = Get-VsanView | Where MoRef -eq "VsanVcClusterHealthSystem-vsan-cluster-health-system"

    $SilentCheckId = $vsanview.VsanHealthGetVsanClusterSilentChecks($cluster.id)

    $vsanview.VsanQueryAllSupportedHealthChecks() | where testid -in $SilentCheckId

}

}


Function Set-VsanHealthSilentChecks {

<#
.SYNOPSIS
    Function : Set-VsanHealthSilentChecks
    EMail    : Xavier.avrillier@gmail.com
    Date     : 25/04/2018
    Info     : Silence or unsilence a VSAN Health check

.DESCRIPTION
Silencing and unsilencing of VSAN health checks cannot be done in the web ui.
For example, a health check can be in a warning state if no internet connection exists which may be by design.

.PARAMETER Cluster
Specify a Cluster object (Get-Cluster)

.PARAMETER TestId
Id(s) of the health check(s) to silence or unsilence.
This can be found with the Get-VsanHealthChecks function.

.PARAMETER CheckState
Silence of Unsilence. Will be applied to all healthchecks specified in TestId.  
#>

param(
    [parameter(ValueFromPipeline=$True,Mandatory=$True)]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl]
    $Cluster,

    [parameter(Mandatory=$True)]
    [string[]]
    $HealthCheckId,

    [parameter(Mandatory=$True)]
    [validateset("Silence","Unsilence")]
    [string[]]
    $CheckState
)

Process {

            switch ($CheckState) {

    "Silence"   {$add = $HealthCheckId; $remove = $null}
    "Unsilence" {$remove = $HealthCheckId; $add = $null}

    }

    $VsanView = Get-VsanView | Where MoRef -eq "VsanVcClusterHealthSystem-vsan-cluster-health-system"

    $vsanview.VsanHealthSetVsanClusterSilentChecks($cluster.id,$add,$remove) | Out-Null

    $SilentCheckId = $vsanview.VsanHealthGetVsanClusterSilentChecks($cluster.id)

    $vsanview.VsanQueryAllSupportedHealthChecks() | where testid -in $SilentCheckId

}

}


Function Get-VsanHealthChecks {

<#
.SYNOPSIS
    Function : Get-VsanHealthChecks
    EMail    : Xavier.avrillier@gmail.com
    Date     : 25/04/2018
    Info     : Display the health state of objects for a VSAN cluster

.DESCRIPTION
Health of checks for a VSAN cluster.
Equivalent in vSphere web client to Cluster>Monitor>VSAN>Health (expanded view)

.PARAMETER Cluster
Specify a Cluster object (Get-Cluster)

.PARAMETER Health
Filter checks by Green, Yellow or Red state.

.PARAMETER DontFetchFromCache
By default if this switch is not set, the Health status will be pulled from the latest cached ones.
If it is set to $true the execution will take more time but will be up to date.  
#>

param(
    [parameter(ValueFromPipeline=$True,Mandatory=$True)]
    $Cluster,

    [validateset("Green","Yellow","Red","skipped")]
    [string[]]
    $Health = @("Green","Yellow","Red","skipped"),

    [switch]
    $DontFetchFromCache
)

Process {

    $VsanView = Get-VsanView | Where MoRef -eq "VsanVcClusterHealthSystem-vsan-cluster-health-system"

    $status = $vsanview.VsanQueryVcClusterHealthSummary($cluster.id,$null,$check.testid,$true,"groups",!$DontFetchFromCache,"defaultView")

    foreach ($group in $status.Groups) {

        $group.grouptests | where TestHealth -in $Health | select TestHealth,@{l="TestId";e={$_.testid.split(".") | select -last 1}},TestName,TestShortDescription,@{l="Group";e={$group.GroupName}}

    }

}

}


Function Get-VsanHealthGroups {

<#
.SYNOPSIS
    Function : Get-VsanHealthGroups
    EMail    : Xavier.avrillier@gmail.com
    Date     : 25/04/2018
    Info     : Display the health state per groups for a VSAN cluster

.DESCRIPTION
Health of group of checks for a VSAN cluster.
Equivalent in vSphere web client to Cluster>Monitor>VSAN>Health (collapsed view)

.PARAMETER Cluster
Specify a Cluster object (Get-Cluster)

.PARAMETER Health
Filter checks by Green, Yellow or Red state.

.PARAMETER DontFetchFromCache
By default if this switch is not set, the Health status will be pulled from the latest cached ones.
If it is set to $true the execution will take more time but will be up to date.  
#>

param(
    [parameter(ValueFromPipeline=$True,Mandatory=$True)]
    $Cluster,

    [validateset("Green","Yellow","Red")]
    [string[]]
    $Health = @("Green","Yellow","Red"),

    [switch]
    $DontFetchFromCache
)

Process {
    
    $VsanView = Get-VsanView | Where MoRef -eq "VsanVcClusterHealthSystem-vsan-cluster-health-system"

    $VsanHealthChecks = $vsanview.VsanQueryVcClusterHealthSummary($cluster.id,$null,$check.testid,$true,"groups",!$DontFetchFromCache,"defaultView")

    foreach ($group in $VsanHealthChecks.groups) {

        $Green  = $group.GroupTests | where testhealth -eq "green"
        $Yellow = $group.GroupTests | where testhealth -eq "Yellow"
        $Red    = $group.GroupTests | where testhealth -eq "Red"

        [pscustomobject]@{

            GroupId      = $Group.GroupId.replace("com.vmware.vsan.health.test.","")
            GroupName    = $group.GroupName
            GroupHealth  = $group.GroupHealth
            ChecksGreen  = $Green.Count
            ChecksYellow = $Yellow.Count
            ChecksRed    = $red.Count

        }

    }

}

}
