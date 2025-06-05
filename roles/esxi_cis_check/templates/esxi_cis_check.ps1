# Temporary Variables

$vcenter_hostname = "vdi-vcsa.unil.ch"
$vcenter_username = "cis-check@vsphere.local"
$vcenter_password = "Thales123!"

# Connect to vCenter
$vcHost = $vcenter_hostname
$vcUser = $vcenter_username
$vcPass = ConvertTo-SecureString $vcenter_password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($vcUser, $vcPass)

if(!$global:DefaultVIServer){
    Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
    Connect-VIServer -Server $vcHost -Credential $cred
}

# VMware cluster name
$ClusterName = "CL-R-VDI-TEST"

# Destination folder
$OutputDir = "/Users/toan/Documents/GitHub/cis-vsphere/roles/esxi_cis_check/templates/temp"

# Create the folder if required
if (-not (Test-Path -Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory | Out-Null
}

# Retrieve the ESXi hostnames
$VMHosts = Get-Cluster -Name $ClusterName | Get-VMHost

foreach ($VMHost in $VMHosts) {
    $Hostname = $VMHost.Name
    $FilePath = Join-Path -Path $OutputDir -ChildPath "$Hostname.yaml"

    # Ordered dictionnary
    $EsxSettings = [ordered]@{}

    # Services
    $EsxSettings["TSM-SSH.Service"] = "$(($VMHost | Get-VMHostService | Where-Object { $_.Key -eq "TSM-SSH" }).Running -eq $true)"
    $EsxSettings["TSM.Service"] = "$(($VMHost | Get-VMHostService | Where-Object { $_.Key -eq "TSM" }).Running -eq $true)"
    $EsxSettings["Config.HostAgent.plugins.solo.enableMob"] = "$(($VMHost | Get-AdvancedSetting -Name Config.HostAgent.plugins.solo.enableMob).Value)"
    $EsxSettings["Slpd.Service"] = "$(($VMHost | Get-VMHostService | Where-Object { $_.Key -eq "slpd" }).Running -eq $true)"
    $EsxSettings["Sfcbd-watchdog.Service"] = "$(($VMHost | Get-VMHostService | Where-Object { $_.Key -eq "sfcbd-watchdog" }).Running -eq $true)"
    $EsxSettings["Snmpd.Service"] = "$(($VMHost | Get-VMHostService | Where-Object { $_.Key -eq "snmpd" }).Running -eq $true)"

    # Advanced Settings
    $EsxSettings["UserVars.DcuiTimeOut"] = "$(($VMHost | Get-AdvancedSetting -Name UserVars.DcuiTimeOut).Value)"
    $EsxSettings["UserVars.ESXiShellInteractiveTimeOut"] = "$(($VMHost | Get-AdvancedSetting -Name UserVars.ESXiShellInteractiveTimeOut).Value)"
    $EsxSettings["UserVars.ESXiShellTimeOut"] = "$(($VMHost | Get-AdvancedSetting -Name UserVars.ESXiShellTimeOut).Value)"
    $EsxSettings["UserVars.SuppressShellWarning"] = "$(($VMHost | Get-AdvancedSetting -Name UserVars.SuppressShellWarning).Value)"
    $EsxSettings["Security.PasswordQualityControl"] = "$(($VMHost | Get-AdvancedSetting -Name Security.PasswordQualityControl).Value)"
    $EsxSettings["Security.AccountLockFailures"] = "$(($VMHost | Get-AdvancedSetting -Name Security.AccountLockFailures).Value)"
    $EsxSettings["Security.AccountUnlockTime"] = "$(($VMHost | Get-AdvancedSetting -Name Security.AccountUnlockTime).Value)"
    $EsxSettings["Security.PasswordHistory"] = "$(($VMHost | Get-AdvancedSetting -Name Security.PasswordHistory).Value)"
    $EsxSettings["Security.PasswordMaxDays"] = "$(($VMHost | Get-AdvancedSetting -Name Security.PasswordMaxDays).Value)"
    $EsxSettings["Config.HostAgent.Vmacore.Soap.SessionTimeout"] = "$(($VMHost | Get-AdvancedSetting -Name Config.HostAgent.vmacore.soap.sessionTimeout).Value)"
    $EsxSettings["UserVars.HostClientSessionTimeout"] = "$(($VMHost | Get-AdvancedSetting -Name UserVars.HostClientSessionTimeout).Value)"
    $EsxSettings["DCUI.Access"] = "$(($VMHost | Get-AdvancedSetting -Name DCUI.Access).Value)"
    $EsxSettings["Lockdown.Mode"] = "$(($VMHost.ExtensionData.Config.LockdownMode) -ne 'disabled')"
    $EsxSettings["Annotations.WelcomeMessage"] = "$(($VMHost | Get-AdvancedSetting -Name Annotations.WelcomeMessage).Value)"
    $EsxSettings["Config.Etc.Issue"] = "$(($VMHost | Get-AdvancedSetting -Name Config.Etc.Issue).Value)"
    $EsxSettings["UserVars.ESXiVPsDisabledProtocols"] = "$(($VMHost | Get-AdvancedSetting -Name UserVars.ESXiVPsDisabledProtocols).Value)"

    # Generate the output YAML file
    Set-Content -Path $FilePath -Value "---"
    foreach ($Key in $EsxSettings.Keys) {
        Add-Content -Path $FilePath -Value "$Key`: `"$($EsxSettings[$Key])`""
    }

    Write-Host "YAML file generated for $Hostname : $FilePath"
}