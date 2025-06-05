

# VMware cluster name
$ClusterName = "CL-R-VDI-TEST"

# Output directory for the YAML files
$OutputDir = "/Users/toan/Documents/GitHub/cis-vsphere/roles/esxi_cis_check/templates/temp"

# Create the directory if it doesn't exist
if (-not (Test-Path -Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory | Out-Null
}

# Function to get the running status of a service (returns "True" or "False")
function Get-ServiceStatus {
    param ($ESXHost, $ServiceKey)
    try {
        $service = Get-VMHostService -VMHost $ESXHost | Where-Object { $_.Key -eq $ServiceKey }
        return $(if ($service.Running) { "True" } else { "False" })
    } catch {
        return "Unknown"
    }
}

# Function to retrieve the value of an advanced setting
function Get-AdvValue {
    param ($AdvSettings, $Name)
    $setting = $AdvSettings | Where-Object { $_.Name -eq $Name }
    return $setting.Value
}

# Get all ESXi hosts from the specified cluster
$VMHosts = Get-Cluster -Name $ClusterName | Get-VMHost

foreach ($VMHost in $VMHosts) {
    $Hostname = $VMHost.Name
    $FilePath = Join-Path -Path $OutputDir -ChildPath "$Hostname.yml"

    # Load all advanced settings once
    $advSettings = Get-AdvancedSetting -Entity $VMHost
    $esxcli = Get-EsxCli -VMHost $(Get-VMHost -Name vdi-r1-test.dcsr.unil.ch) -V2

    $yamlLines = @("---")

    ## SECTION 1 - HARDWARE ##  
    
    ### <======= Waiting input from Sebastien =======> ####

    $yamlLines += "## 1 - Hardware ##"

    ## SECTION 2 - BASE ##

    $BaseSettings = [ordered]@{}    
    
    $BaseSettings["Software.Acceptance.Level"] = $esxcli.software.acceptance.get.Invoke()
    $BaseSettings["VMkernel.Boot.ExecInstalledOnly"] = Get-AdvValue $advSettings "VMkernel.Boot.execInstalledOnly"
    $BaseSettings["Ntp.Servers"] = (Get-VMHostNtpServer -VMHost (Get-VMHost -Name vdi-r1-test.dcsr.unil.ch)) -join ','
    $BaseSettings["Ntpd.Service"] = (Get-VMHostService -Host $VMHost | Where-Object { $_.Key -eq "ntpd" }).Running
    $BaseSettings["Hardware.TrustedPlatformModule"] = $esxcli.system.settings.encryption.get.Invoke().Mode
    $BaseSettings["UserVars.SuppressHyperthreadWarning"] = Get-AdvValue $advSettings "UserVars.SuppressHyperthreadWarning"
    $BaseSettings["Mem.ShareForceSalting"] = Get-AdvValue $advSettings "Mem.ShareForceSalting"

    $yamlLines += "`n## 2 - Base"
    foreach ($Key in $BaseSettings.Keys) {
        $escapedValue = $BaseSettings[$Key] -replace '"', '\"'
        $yamlLines += "$Key`: `"$escapedValue`""
    }

    ## SECTION 3 - MANAGEMENT ##

    $MgmtSettings = [ordered]@{}

    # Services
    $MgmtSettings["TSM-SSH.Service"] = Get-ServiceStatus -Host $VMHost -ServiceKey "TSM-SSH"
    $MgmtSettings["TSM.Service"] = Get-ServiceStatus -Host $VMHost -ServiceKey "TSM"
    $MgmtSettings["Slpd.Service"] = Get-ServiceStatus -Host $VMHost -ServiceKey "slpd"
    $MgmtSettings["Sfcbd-watchdog.Service"] = Get-ServiceStatus -Host $VMHost -ServiceKey "sfcbd-watchdog"
    $MgmtSettings["Snmpd.Service"] = Get-ServiceStatus -Host $VMHost -ServiceKey "snmpd"

    # Advanced Settings
    $MgmtSettings["Config.HostAgent.plugins.solo.enableMob"] = Get-AdvValue $advSettings "Config.HostAgent.plugins.solo.enableMob"
    $MgmtSettings["UserVars.DcuiTimeOut"] = Get-AdvValue $advSettings "UserVars.DcuiTimeOut"
    $MgmtSettings["UserVars.ESXiShellInteractiveTimeOut"] = Get-AdvValue $advSettings "UserVars.ESXiShellInteractiveTimeOut"
    $MgmtSettings["UserVars.ESXiShellTimeOut"] = Get-AdvValue $advSettings "UserVars.ESXiShellTimeOut"
    $MgmtSettings["UserVars.SuppressShellWarning"] = Get-AdvValue $advSettings "UserVars.SuppressShellWarning"
    $MgmtSettings["Security.PasswordQualityControl"] = Get-AdvValue $advSettings "Security.PasswordQualityControl"
    $MgmtSettings["Security.AccountLockFailures"] = Get-AdvValue $advSettings "Security.AccountLockFailures"
    $MgmtSettings["Security.AccountUnlockTime"] = Get-AdvValue $advSettings "Security.AccountUnlockTime"
    $MgmtSettings["Security.PasswordHistory"] = Get-AdvValue $advSettings "Security.PasswordHistory"
    $MgmtSettings["Security.PasswordMaxDays"] = Get-AdvValue $advSettings "Security.PasswordMaxDays"
    $MgmtSettings["Config.HostAgent.Vmacore.Soap.SessionTimeout"] = Get-AdvValue $advSettings "Config.HostAgent.vmacore.soap.sessionTimeout"
    $MgmtSettings["UserVars.HostClientSessionTimeout"] = Get-AdvValue $advSettings "UserVars.HostClientSessionTimeout"
    $MgmtSettings["DCUI.Access"] = Get-AdvValue $advSettings "DCUI.Access"
    $MgmtSettings["Annotations.WelcomeMessage"] = Get-AdvValue $advSettings "Annotations.WelcomeMessage"
    $MgmtSettings["Config.Etc.Issue"] = Get-AdvValue $advSettings "Config.Etc.Issue"
    $MgmtSettings["UserVars.ESXiVPsDisabledProtocols"] = Get-AdvValue $advSettings "UserVars.ESXiVPsDisabledProtocols"

    # Lockdown mode (True if enabled, False otherwise)
    $lockdownEnabled = $VMHost.ExtensionData.Config.LockdownMode -ne "disabled"
    $MgmtSettings["Lockdown.Mode"] = $(if ($lockdownEnabled) { "True" } else { "False" })

    # Generate the YAML output
    $yamlLines += "`n## 3 - Management"
    foreach ($Key in $MgmtSettings.Keys) {
        $escapedValue = $MgmtSettings[$Key] -replace '"', '\"'
        $yamlLines += "$Key`: `"$escapedValue`""
    }

    ## SECTION 4 - LOGGING ##

    $LogSettings = [ordered]@{}

    $LogSettings["Syslog.Global.LogDir"] = Get-AdvValue $advSettings "Syslog.global.logDir"
    $LogSettings["Syslog.Global.LogHost"] = Get-AdvValue $advSettings "Syslog.global.logHost"
    $LogSettings["Syslog.Global.LogLevel"] = Get-AdvValue $advSettings "Syslog.global.logLevel"
    $LogSettings["Config.HostAgent.Log.Level"] = Get-AdvValue $advSettings "Config.HostAgent.log.level"
    $LogSettings["Syslog.Global.LogFiltersEnable"] = Get-AdvValue $advSettings "Syslog.global.logFiltersEnable"
    $LogSettings["Syslog.Global.AuditRecord.StorageEnable"] = Get-AdvValue $advSettings "Syslog.global.auditRecord.storageEnable"
    $LogSettings["Syslog.Global.AuditRecord.StorageDirectory"] = Get-AdvValue $advSettings "Syslog.global.auditRecord.storageDirectory"
    $LogSettings["Syslog.Global.AuditRecord.StorageCapacity"] = Get-AdvValue $advSettings "Syslog.global.auditRecord.storageCapacity"
    $LogSettings["Syslog.Global.AuditRecord.RemoteEnable"] = Get-AdvValue $advSettings "Syslog.global.auditRecord.remoteEnable"
    $LogSettings["Syslog.Global.Certificate.CheckSSLCerts"] = Get-AdvValue $advSettings "Syslog.global.certificate.checkSSLCerts"
    $LogSettings["Syslog.Global.Certificate.StrictX509Compliance"] = Get-AdvValue $advSettings "Syslog.global.certificate.strictX509Compliance"

    # Generate the YAML output
    $yamlLines += "`n## 4 - Logging"
    foreach ($Key in $LogSettings.Keys) {
        $escapedValue = $LogSettings[$Key] -replace '"', '\"'
        $yamlLines += "$Key`: `"$escapedValue`""
    }   

    ## SECTION 5 - NETWORK ##

    $NetSettings = [ordered]@{}

    $NetSettings["Net.DVFilterBindIpAddress"] = Get-AdvValue $advSettings "Net.DVFilterBindIpAddress"
    $NetSettings["Net.BlockGuestBPDU"] = Get-AdvValue $advSettings "Net.BlockGuestBPDU"    

    # Generate the YAML output
    $yamlLines += "`n## 5 - Network"
    foreach ($Key in $NetSettings.Keys) {
        $escapedValue = $NetSettings[$Key] -replace '"', '\"'
        $yamlLines += "$Key`: `"$escapedValue`""
    }  

    ## SECTION 6 - FEATURES ##


    $yamlLines | Set-Content -Path $FilePath -Encoding UTF8

    Write-Host "YAML file generated for $Hostname`: $FilePath"

### CIS BASELINE COMPARISON

# Path to baseline CIS YAML
$CISBaselinePath = "/Users/toan/Documents/GitHub/cis-vsphere/roles/esxi_cis_check/templates/cis_baseline_3.yml"
$Baseline = [ordered]@{}

# Load the baseline YAML
if (Test-Path -Path $CISBaselinePath) {
    $Baseline = (Get-Content -Path $CISBaselinePath -Raw | ConvertFrom-Yaml)
} else {
    Write-Warning "Baseline file not found: $CISBaselinePath"
    continue
}

# Load the host-specific generated YAML
$Generated = (Get-Content -Path $FilePath -Raw | ConvertFrom-Yaml)

# Store diff results
$DiffOutput = @("---", "## Differences between $Hostname and CIS baseline")

foreach ($section in $Baseline.Keys) {
    if (-not $Generated.ContainsKey($section)) {
        $DiffOutput += "Missing section in host config: $section"
        continue
    }

    $baselineValue = $Baseline[$section].ToString()
    $hostValue = $Generated[$section].ToString()
    if ($baselineValue -ne $hostValue) {
        $DiffOutput += "$section -> baseline=`"$baselineValue`", host=`"$hostValue`""
    }
}

# Output the diff to file
$DiffFilePath = Join-Path -Path $OutputDir -ChildPath "diff_$Hostname.yml"
$DiffOutput | Set-Content -Path $DiffFilePath -Encoding UTF8

Write-Host "Diff file generated for $Hostname`: $DiffFilePath"

}
