<#PSScriptInfo

.VERSION 2.3.3

.GUID 2c80336a-7d9b-41c0-8eb3-a80abef2dbb8

.AUTHOR Jeff Gilbert

.COMPANYNAME 

.COPYRIGHT 

.TAGS Intune

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
v2.3.3 - 4.14.26 - Corrected telemetry check values; minor bug fixes
v2.3.2 - 4.8.26 - Added HTML summary report and logging functionality. Hosted on GitHub for Get-Help -Online help.
v2.2.0 - 4.3.26 - Added Windows Event log checks and report functionality
v2.1.1 - 4.1.26 - Incorporated tester feedback and updated Get-Help documentation
v2.0.1 - 3.25.26 - Removed deprecated network endpoint from connectivity checks
v2.0.0 - 3.23.26 - Added more checks and function documentation
v1.0.0 - 3.10.26 - Original published version
#>

<#
.SYNOPSIS
Validates Windows Autopatch and Feature Update readiness by performing comprehensive 
device configuration, policy, service, registry, network, and scheduled task health checks.

.DESCRIPTION
This script performs a read only, Windows Autopatch health assessment. It validates OS servicing branch,
telemetry level, Intune enrollment and IME activity, co‑management workloads, Windows Update policy
authority, WSUS or registry blockers, required services, network endpoints, and scheduled tasks. It runs
safely in SYSTEM or user context and outputs console results, a readiness summary, and an exit code suitable for
Intune detection/remediation.

GENERAL CONFIGURATION HEALTH CHECKS
Operating System Release Branch:  
Ensures the device is on a supported GA/production channel (not Windows Insiders/Preview).

Registry Settings:  
Checks for Autopatch‑blocking or WSUS‑redirecting values:  
- HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate
 -- DoNotConnectToWindowsUpdateInternetLocations, DisableWindowsUpdateAccess, WUServer, WUStatusServer
- HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU  
 -- NoAutoUpdate  
- Update source override keys:  
 -- SetPolicyDrivenUpdateSourceForDriverUpdates, FeatureUpdates, OtherUpdates, QualityUpdates  
If set to '1' and a WUSserver is configured, the device tries to use WSUS instead of Autopatch.

Telemetry:  
Reads the AllowTelemetry policy value from the local registry to confirm minimum level = **1 (Required)**.

Intune Enrollment & IME Activity:
Validates Intune enrollment indicators and IME log activity within the last 28 days.  
For comanaged devices, checks required workload ownership:  
- Windows Update policies  
- Device configuration  
- Office Click to Run apps

Update Policy Authority:
Reads the PolicySources value to ensure Intune/Autopatch is configured:
HKLM\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState\PolicySources
Values:  
1=GPO, 2=SCCM, 4=Intune/Autopatch, 5=GPO+MDM (MDM wins), 6=SCCM+MDM (MDM wins).  
Also attempts to identify the Autopatch ring a device is assigned to (test, ring1, ring2, etc.)

AUTOPATCH SERVICE HEALTH CHECKS
Validates required Windows Update–related services:  
- BITS (downloads update payloads)  
- CryptSvc (signature validation)  
- DiagTrack (telemetry pipeline)  
- DoSvc (Delivery Optimization)  
- UsoSvc (update orchestration)  
- WaaSMedicSvc (repairs Windows Update stack)  
- wuauserv (core Windows Update client)

NETWORK ENDPOINT CONNECTIVITY CHECKS
Confirms reachability of required Autopatch and Microsoft endpoints:  
- mmdcustomer.microsoft.com (Microsoft Managed Desktop (MMD) / Windows Autopatch service endpoint)
- mmdls.microsoft.com (part of the Autopatch logging and service communication layer)
- login.windows.net (endpoint used to issue and refresh authentication tokens)
- device.autopatch.microsoft.com (Service endpoint that must be reachable from Autopatch devices)
- services.autopatch.microsoft.com (Service API endpoint that must be reachable for Autopatch functionality)
- Global Device Listener: devicelistenerprod.microsoft.com (global Autopatch device listener communication endpoint required for Autopatch‑managed devices)  
- EU Device Listener: devicelistenprod.eudb.microsoft.com (EU tenants) (EU endpoint used instead of the global listener within the EU Data Boundary)

WINDOWS UPDATE SCHEDULED TASK CHECKS
Validates required scheduled tasks:
- \Microsoft\Windows\WindowsUpdate\Scheduled Start (triggers scans/downloads)  
- \Microsoft\Windows\UpdateOrchestrator\Report policies (evaluates effective policy)

WINDOWS UPDATE EVENT LOG CHECKS
Scans device event logs for known Windows Update error code entries within the last 7 days 
(Edit $DaysBack to change time period):
- Microsoft-Windows-WindowsUpdateClient/Operational
- Microsoft-Windows-WindowsUpdateClient/Admin
- Microsoft-Windows-UpdateOrchestrator/Operational
- Microsoft-Windows-DeliveryOptimization/Operational

.PARAMETER Remediation  
(Optional)
Use this parameter to test the script's behavior as an Intune remediation: .\Get-AutopatchHealth.ps1 -Remediation

There is also a line in the script's READ ME section to hard-code it to run as a remediation. Uncomment the 
line below (delete the #) in the READ ME section of the script: # $Remediation = $true. This will change 
the format of the pass/fail images from ✅/❌ to $($script:Symbols.Fail)$($script:Symbols.Pass)/$($script:Symbols.Fail) 
so they will display properly in the remediation pre-remediation detection output.

If the script runs as a remedation (detection only), a log file will be generated at 
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IR_AutopatchHealth_ERR.log. If subsequent remediation runs
pass, the ERR log file will be deleted after it has aged over 14 days. 

.PARAMETER EU  
(Optional)
Use this if running the script against an EU tenant to check network endpoint connectivity: 
.\Get-AutopatchHealth.ps1 -EU 

You can also modify the script to include EU data network boundaries in network tests. Uncomment the line below in the 
READ ME section of the script (delete the #): # $EU = $true 

.PARAMETER Report 
When the Report parameter is specified, a transcript of script activity is recorded at 
$env:WINDIR\Temp\AutopatchHealth_$env:COMPUTERNAME.log and an html report is automatically generated C:\Users\Public\Documents\<computername>.html.
The report is automaticlaly opened in the default web browser when the script exits. 

.EXAMPLE
Test running the script as an Intune remediation. If actually using it as a remediation script instead of just testing, you need
to un-comment the $Remediation line in READ ME. This will also result in a log file beign retained in the IME logs location is there is a test failure.

Modify the script invocation to:
PS C:\> .\Get-AutopatchHealth.ps1 -Remediation

.EXAMPLE
Run network checks including EU Data Boundary endpoints:
Modify the script invocation to:
PS C:\> .\Get-AutopatchHealth.ps1 -EU

.EXAMPLE
Test running the script as an Intune remediation and run network checks including EU Data Boundary endpoints:
Modify the script invocation to:
PS C:\> .\Get-AutopatchHealth.ps1 -Remediation -EU

.EXAMPLE
Generate a report at the end of the health check script execution.
Modify the script invocation to:
PS C:\> .\Get-AutopatchHealth.ps1 -Report

.NOTES
This script aligns with Microsoft guidance for:
- Windows Autopatch onboarding
- Windows Update for Business (WUfB)
- Delivery Optimization network requirements

.LINK
https://github.com/jeffgilb/Get-AutopatchHealth/blob/main/Get-AutopatchHealth.ps1
#>

param (
    [switch]$Remediation, # Test running the script as a remediation: Get-AutopatchHealth.ps1 -Remediation
    [switch]$EU, # Use to test EU Autopatch endpoint: Get-AutopatchHealth.ps1 -EU
    [switch]$Report # Use to create and open a summary report at script completion
)

#-------------------------------------------------------- Functions ---------------------------------------------------------
Function Use-NoUniCode {  
<#
    Use Unicdode symbols for console output running the script directly for the best visual 
    experience. Do not use Unicode symbols for Intune remediations because the unicode symbols will 
    not render as expected in the admin center. Use ASCII markers instead.

    Unicode gets stripped or mangled by the Intune reporting pipeline before the Admin Center renders 
    it. Scripts are required to be UTF‑8 encoded and Intune uses a restricted text renderer that is 
    effectively ASCII‑safe, not Unicode‑safe. Intune captures only standard output and that output is 
    truncated to ~2048 characters.

    This is by design because remediation output is designed for machine status, CSV export, so Intune 
    intentionally keeps this path plain‑text safe.
#>

    if ($Remediation) {  # NoUnicode
    $script:Symbols = @{
        Pass = "[PASS]"
        Fail = "[FAIL]"
        Warn = "[WARN]"
        Info = "[INFO]"
    }
    }
    else {
        $script:Symbols = @{
            Pass = "✅"
            Fail = "❌"
            Warn = "⚠️"
            Info = "ℹ️"
        }
    }
}

Function RU-Admin{
<#
    Determines if the current Windows identity is a member of the local Administrators group.
    If the session is not elevated, the function displays a warning indicating that running
    Autopatch health checks without administrative permissions can result in false‑negative
    reporting due to restricted access to system resources.
#>
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    If (!($IsAdmin)){  
        Write-Host "-------------------------------------------------" -ForegroundColor Red 
        Write-Host "$($script:Symbols.Fail) When running Autopatch health checks with limited permissions (non-admin)`nYou WILL encounter false negative reporting results." -ForegroundColor Red 
        Write-Host "-------------------------------------------------" -ForegroundColor Red 
        $script:summary += " $($script:Symbols.Fail) Health checks not run as admin - expect inaccurate results" }
}

Function Test-Branch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Branch
    )
    
    $policyStatePath = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState'
    if (-not (Test-Path $policyStatePath)) { Write-Host "PolicyState registry path not found: $policyStatePath" -ForegroundColor Yellow
        return
    }
    $policyState = Get-ItemProperty -Path $policyStatePath -ErrorAction SilentlyContinue
        # -----------------------------
        # BranchReadinessLevel
        # -----------------------------
        $brl = [string]$policyState.BranchReadinessLevel
        $brlLabel = switch ($brl) {
            'CB'  { 'Current Branch' }
            'B'   { 'Business (SAC)' }
            'RP'  { 'Release Preview' }
            'WIF' { 'Windows Insider Fast' }
            'WIS' { 'Windows Insider Slow' }
            'WIP' { 'Windows Insider Preview' }
            default { $brl }   # fall back to raw value
        }
        
        If ($brl -eq $branch ){ Write-Host ("  Operating System branch is {0} ({1})" -f $brl, $brlLabel) ; return $true }
        else { Write-Host ("  $($script:Symbols.Fail) BranchReadinessLevel is NOT supported: {0} ({1})" -f $brl, $brlLabel) -ForegroundColor Red ; return $false }
}

Function Check-Registry {
    # -----------------------------
    # AutopatchRegistryBlockerCheck
    # -----------------------------
    $blockingKey = 0
    # --- Paths (use Registry:: to avoid 32-bit WOW64 redirection issues) ---
    $regChecks = @(
    'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DoNotConnectToWindowsUpdateInternetLocations',
    'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DisableWindowsUpdateAccess',
    'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate'
    )
    foreach ($path in $regChecks) {
    if (Test-Path $path) { Write-Host "  Autopatch device registration blocking registry key value found: $path" -ForegroundColor Red ; $blockingKey++ } 
    }
    if ($blockingKey -eq 0){ Write-Host "  No Autopatch device registration blockers found" }

    # -----------------------------
    # WSUS Server Keys Checks
    # -----------------------------   
    $SUPreg = 0
    # --- Paths (use Registry:: to avoid 32-bit WOW64 redirection issues) ---
    $WSrvKeys = @{ Path = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; ValueName = "WUServer"; WSrvValue = $null },
                @{ Path = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; ValueName = "WUStatusServer"; WSrvValue = $null }
    
    foreach ($Key in $WSrvKeys) {
        $reg = Get-ItemProperty -Path $Key.Path -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($reg.$($Key.ValueName))) { Write-Host "  $($Key.ValueName) key value not found or blank " }
        else { Write-Host "  $($Key.ValueName) value is configured" -ForegroundColor Red ; $SUPreg++ } # WSUS config registry value found
        }
    
    # The update source key values only apply if the WUServer and/or WUStatusServer values are present [1 means WSUS, 0 means Autopatch]
    $UpdateSourceKeys = @(
            @{ Path = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; ValueName = "SetPolicyDrivenUpdateSourceForDriverUpdates"; WSUSValue = "1"  },
            @{ Path = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; ValueName = "SetPolicyDrivenUpdateSourceForFeatureUpdates"; WSUSValue = "1"  },
            @{ Path = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; ValueName = "SetPolicyDrivenUpdateSourceForOtherUpdates"; WSUSValue = "1"  },
            @{ Path = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; ValueName = "SetPolicyDrivenUpdateSourceForQualityUpdates"; WSUSValue = "1" }         
        )
    ForEach ($Key in $UpdateSourceKeys){               
            $value = Get-ItemProperty -Path $Key.Path -Name $Key.ValueName -ErrorAction SilentlyContinue
            if ($null -ne $value){  
                if ([string]$value.$($Key.ValueName) -eq $Key.WSUSValue){ Write-Host "  $($Key.ValueName) is set to 1 (WSUS)" -ForegroundColor Yellow ; $SUPreg++ } # WSUS config registry value found
            } else { Write-Host "  No WSUS update source policy registry values found" }
        
    # Summary
        If ( $SUPreg -eq 0 -and
         $blockingKey -eq 0 ){ return $true }
         else { return $false}
    }
}

Function Test-Telemetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 3)]
        [int]$minRequired
    )
    $regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    $valueName = 'AllowTelemetry_PolicyManager'

    # AllowTelemetry_PolicyManager is written by Intune telemetry policies implemented via the Policy CSP
    # (Settings Catalog, OMA‑URI, or Device Restrictions). It represents the authoritative MDM‑enforced
    # telemetry level and supersedes the legacy AllowTelemetry policy key.

    try {
        $val = (Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction Stop).$valueName
        $val = [int]$val
        $map = @{ 0 = 'Diagnostic data off (Security)'; 1 = 'Required diagnostic data (Basic)'; 2 = '(Legacy) Enhanced'; 3 = 'Optional diagnostic data (Full)' }
        if ($val -ge $minRequired) { Write-Host "  Telemetry is set to $($map[$val]) [$($val)]" ; return $true } 
        else { return $false }
    }
    catch {
        Write-Host "  $($script:Symbols.Fail) Policy value not found ($regPath\$valueName)." ; return $false }
}

Function Intune-Checks{
    # -----------------------------
    # MDMEnrollmentCheck
    # -----------------------------
        $missingKey = 0
        $paths = @(
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IntuneManagementExtension',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\current\device'
        )
        foreach ($p in $paths) {
        if (!(Test-Path $p)){ Write-Host "  Enrollment key $p is NOT present" -ForegroundColor Red ; $missingKey++} 
        }
        If ($missingKey -eq 0){ Write-Host "  Intune enrollment indicators are present" }

    # -----------------------------
    # IMEActivityCheck
    # -----------------------------
    $stale = 0
    $latestImeLog = Get-ChildItem 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs' `
        -Filter '*.log' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($latestImeLog) {
        $lastActivity = $latestImeLog.LastWriteTime
        $cutoffDate   = (Get-Date).AddDays(-28)
        if ($lastActivity -ge $cutoffDate) { Write-Host "  Last Intune activity (IME): $lastActivity" }
        else { Write-Host "  STALE (device activity is older than 28 days)" -ForegroundColor Red ; $stale++ }
    } else { Write-Host "  No Intune Management Extension logs found." -ForegroundColor Red }

    # -----------------------------
    # ComanagementWorkloadCheck
    # -----------------------------
    # Get ConfigMgr co-management state
    $ccm = Get-CimInstance -Namespace 'root\ccm\InvAgt' -ClassName 'CCM_System' -ErrorAction SilentlyContinue
    if ($ccm.CoManaged) { 
    Write-Host "  Co-management indicators are present, checking required workload ownership"
    # Autopatch-required workloads
        $RequiredWorkloads = @{
            WindowsUpdatePolicies = 16     # Windows Update policies workload
            OfficeClickToRunApps  = 128    # Office Click-to-Run apps workload
            DeviceConfiguration  = 8       # Device configuration workload
        }
        $Missing = @()
        foreach ($workload in $RequiredWorkloads.GetEnumerator()) {
            if (-not ($ccm.ComgmtWorkloads -band $workload.Value)) { $Missing += $workload.Key }
        }
        if ($Missing.Count -eq 0) { Write-Host "  Autopatch-required co-management workloads are owned by Intune " }

        else {
            Write-Host "  The following workloads are NOT managed by Intune:" -ForegroundColor Red
            $Missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        }
    }
    If ($missingKey -eq 0 -and
        $stale -eq 0 -and
        $Missing.Count -eq 0 ){ return $true }
    else { return $false }
}

Function Test-UpdateEngine{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$PolicySource
    )
    $policySources = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState' -ErrorAction Stop).PolicySources
    $srcLabel = switch ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState').PolicySources) {
        1 { 'GPO (Legacy WSUS)' }
        2 { 'Configuration Manager' }
        4 { 'Intune/Autopatch' }
        5 { 'GPO + MDM (MDM wins)' }
        6 { 'SCCM + MDM (MDM wins)' }
        default { 'Unknown / Not set' }
    }
    Write-Host "  The active update engine is $($srcLabel)"

    # Determine if a device is in an Autopatch Group ring
    $ringErr = 0
    $regPath = 'HKLM:\SOFTWARE\Microsoft\WindowsAutopatch\ClientBroker'
    $valueName = 'Ring'
    $ringValue = (Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue).$valueName
    if ([string]::IsNullOrWhiteSpace($ringValue)) { Write-Host "  This device is not assigned an Autopatch ring" -ForegroundColor Red ; $ringErr++ }
    else { Write-Host "  Device is in an Autopatch ring: $($ringValue)" }
    if (($policySources -band 4) -and ($ringErr -eq 0)) { $true }
    else { $false }
}

function Get-AutopatchServiceStatus {
    [CmdletBinding()]
    param( [string[]] $ServiceNames )

    $results   = @()
    $svcIssue = 0
    $total     = $ServiceNames.Count
    $index     = 0

    foreach ($service in $ServiceNames) {
        $index++
        $percent = [math]::Round(($index / $total) * 100, 0)
        Write-Progress `
            -Activity "Checking Windows Update-related services" `
            -Status "Checking $service ($index of $total)" `
            -PercentComplete $percent
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        $cim = Get-CimInstance -ClassName Win32_Service -Filter "Name='$service'" -ErrorAction SilentlyContinue

        $issueReason = $null
        if (-not $cim){ $issueReason = 'Service not installed' ; $svcIssue++ }
        elseif ($cim.StartMode -eq 'Disabled'){ $issueReason = 'Service is disabled' ; $svcIssue++ }
        elseif (
            $svc -and
            $svc.Status -ne 'Running' -and
            $cim.Name -in @('UsoSvc','DiagTrack','CryptSvc')
        ) { $issueReason = 'Service not running' ; $svcIssue++ }

        $results += [pscustomobject]@{
            ServiceName = $service
            DisplayName = if ($cim) { $cim.DisplayName } else { '<Not Installed>' }
            Installed   = [bool]$cim
            StartupType = if ($cim) { $cim.StartMode } else { $null }
            Status      = if ($svc) { $svc.Status } else { $null }
            Issue       = $issueReason
        } 
    }

    Write-Progress -Activity "Checking Windows Update-related services" -Completed

    # Build health summary object
    [pscustomobject]@{
        CheckName        = 'Windows Update / Autopatch Services'
        TotalServices    = $total
        HealthyServices  = $total - $svcIssue
        ServicesWithIssues = $svcIssue
        OverallHealth    = if ($svcIssue -eq 0) { 'Healthy' } else { 'Unhealthy' }
        Timestamp        = (Get-Date)
        Services         = $results | Sort-Object ServiceName
        IssueSummary     = $results |
                           Where-Object Issue |
                           Group-Object Issue |
                           Select-Object Name, Count
    }
}

Function Update-Events{
    param (
    [switch]$IncludeWarnings 
    )
    $startTime = (Get-Date).AddDays(-$DaysBack)
    $logs = @(
        'Microsoft-Windows-WindowsUpdateClient/Operational',
        'Microsoft-Windows-WindowsUpdateClient/Admin',
        'Microsoft-Windows-UpdateOrchestrator/Operational',
        'Microsoft-Windows-DeliveryOptimization/Operational'
    )

    $levels = @(1,2) # Critical, Error
    if ($IncludeWarnings) { $levels += 3 }

    # --- Known bad Event IDs ---
    $KnownBadEventIds = @{
        20   = @{ Severity='High';     Category='Install';   Hint='Update installation failed. Check CBS.log and DISM health.' }
        25   = @{ Severity='Medium';   Category='Scan';      Hint='Windows Update scan failed.' }
        31   = @{ Severity='High';     Category='Download';  Hint='Update download failed. Check network or Delivery Optimization.' }
        34   = @{ Severity='High';     Category='Install';   Hint='Update installation failed.' }
        41   = @{ Severity='Critical'; Category='Servicing'; Hint='Servicing stack failure or reboot pending.' }
        500  = @{ Severity='High';     Category='Orchestration'; Hint='Update orchestration failure.' }
        501  = @{ Severity='Medium';   Category='Policy'; Hint='Update deferred or blocked by policy.' }
        1006 = @{ Severity='Medium';   Category='DeliveryOptimization'; Hint='Content download failure.' }
        1012 = @{ Severity='High';     Category='DeliveryOptimization'; Hint='Delivery Optimization network failure.' }
        16398 = @{ Severity='High';    Category='BITS'; Hint='BITS job failure.' }
    }

    $events = foreach ($log in $logs) {
        if (Get-WinEvent -ListLog $log -ErrorAction SilentlyContinue) {
            Get-WinEvent -FilterHashtable @{
                LogName   = $log
                Level     = $levels
                StartTime = $startTime
            } -ErrorAction SilentlyContinue |
            ForEach-Object {
                $classification = $KnownBadEventIds[$_.Id]

                [pscustomobject]@{
                    TimeCreated = $_.TimeCreated
                    Level       = $_.LevelDisplayName
                    EventId     = $_.Id
                    Provider    = $_.ProviderName
                    LogName     = $_.LogName
                    Message     = $_.Message
                    KnownBad    = [bool]$classification
                    Severity    = $classification.Severity
                    Category    = $classification.Category
                    RemediationHint = $classification.Hint
                }
            }
        }
    }

    # --- Health summary ---
    $badEvents = $events | Where-Object KnownBad
    $summary = [pscustomobject]@{
        CheckName        = 'Windows Update Event Log Scan'
        TimeWindowDays   = $DaysBack
        TotalEvents      = $events.Count
        KnownBadEvents   = $badEvents.Count
        CriticalEvents   = ($badEvents | Where-Object Severity -eq 'Critical').Count
        OverallHealth    = if ($badEvents.Count -eq 0) { 'Healthy' } else { 'Issues Found' }
        Timestamp        = Get-Date
        FailureProfile   = $badEvents |
                        Group-Object Category |
                        Select-Object Name, Count
        Events           = $events | Sort-Object TimeCreated -Descending
    }

    $summary | Add-Member -MemberType NoteProperty -Name IsHealthy -Value ($badEvents.Count -eq 0)
    if (-not $summary.IsHealthy) {
    Write-Host "  Known Windows Update failure events were detected in the last $DaysBack days" -ForegroundColor Red
    $summary.Events |
        Where-Object KnownBad |
        Format-List TimeCreated, EventId, Severity, Category, Message, RemediationHint, LogName
    } else { Write-Host "  No known Windows Update failures detected in the last $DaysBack days" }

    return $summary
}

function Test-AutopatchNetworkConnection {
    [CmdletBinding()]
    param (
        [switch]$IncludeEUDataBoundary,
        [int[]]$Ports = @(80,443),
        [int]$TimeoutSeconds = 5
    )
    $endpoints = @(
        @{ Name = "MMD Customer"; Host = "mmdcustomer.microsoft.com" }
        @{ Name = "MDM Download Service"; Host = "mmdls.microsoft.com" }
        @{ Name = "Azure AD Login"; Host = "login.windows.net" }
        @{ Name = "Autopatch Device Listener"; Host = "device.autopatch.microsoft.com" }
        @{ Name = "Autopatch Services"; Host = "services.autopatch.microsoft.com" }
        @{ Name = "Autopatch Payload Storage"; Host = "payloadprod1.blob.core.windows.net"; Wildcard = "payloadprod*.blob.core.windows.net" }
        @{ Name = "Windows Autopatch Device Listener"; Host = "devicelistenerprod.microsoft.com" }
        # Deprecated @{ Name = "Azure Web PubSub"; Host = "autopatch.webpubsub.azure.com"; Wildcard = "*.webpubsub.azure.com" }
    )

    if ($IncludeEUDataBoundary) {
        $endpoints += @{
            Name = "EU Data Boundary Device Listener"
            Host = "devicelistenprod.eudb.microsoft.com"
        }
        $endpoints = $endpoints | Where-Object {
            $_.Host -ne "devicelistenerprod.microsoft.com"
        }
    }

    $results = foreach ($ep in $endpoints) {
        $dnsResolved = $false
        $portResults = @{}
        $errorText   = $null

        try {
            Resolve-DnsName -Name $ep.Host -ErrorAction Stop | Out-Null
            $dnsResolved = $true

            foreach ($port in $Ports) {
                $tcp = Test-NetConnection -ComputerName $ep.Host -Port $port -WarningAction SilentlyContinue
                $portResults["Port$port"] = $tcp.TcpTestSucceeded
            }
        }
        catch {
            $errorText = $_.Exception.Message
            foreach ($port in $Ports) { $portResults["Port$port"] = $false }
        }

        [PSCustomObject]@{
            Name          = $ep.Name
            Target        = $ep.Host
            Wildcard      = $ep.Wildcard
            DnsResolved   = $dnsResolved
            Tcp80Success  = $portResults["Port80"]
            Tcp443Success = $portResults["Port443"]
            Reachable     = ($dnsResolved -and ($portResults.Values -contains $true))
            Error         = $errorText
        }
    }
    return $results
}

function Get-WindowsUpdateTaskStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $TaskPaths
    )

    $taskIssue = 0
    $results = foreach ($taskPath in $TaskPaths) {
        # Split full task path into folder + task name
        $taskName = Split-Path $taskPath -Leaf
        $taskFolder = Split-Path $taskPath -Parent
        $task = Get-ScheduledTask `
            -TaskName $taskName `
            -TaskPath ($taskFolder + '\') `
            -ErrorAction SilentlyContinue
        $issueReason = $null
        if (-not $task) { $issueReason = 'Task not found' ; $taskIssue++ }
        elseif ($task.State -eq 'Disabled') { $issueReason = 'Task is disabled' ; $taskIssue++ }
        [pscustomobject]@{
            TaskPath   = $taskPath
            Exists     = [bool]$task
            State      = if ($task) { $task.State } else { $null }
            Issue      = $issueReason
        }
    }


    if ($taskIssue -eq 0){ Write-Host "$($script:Symbols.Pass) All required Windows Update scheduled task(s) are healthy" -ForeGroundColor Green ; $script:summary+= "$($script:Symbols.Pass) All required Windows Update tasks are healthy" } 
    else { Write-Host "$($script:Symbols.Fail) $taskIssue required Windows Update scheduled task(s) are missing or disabled" -ForeGroundColor Red ; $script:exitCode++ ; $script:summary+= "$($script:Symbols.Fail) Issue found with required Windows Update tasks" }
    # Output results for logging
    $results
}

function Build-Report {
    [CmdletBinding()]
    param ()

    # ----------------------------
    # Helper: object -> HTML table
    # ----------------------------
    function Convert-ToHtmlTable {
        param (
            [object[]]$Data,
            [string[]]$Columns
        )

        if (-not $Data -or $Data.Count -eq 0) {
            return '<p><em>No data available</em></p>'
        }

        if ($Columns) {
            $Data = $Data | Select-Object $Columns
        }

        return ($Data | ConvertTo-Html -Fragment)
    }

    # ----------------------------
    # CSS (wrap-safe, table-safe)
    # ----------------------------
    $css = @"
<style>
body {
    font-family: Segoe UI, Arial;
    font-size: 13px;
    background-color: #f9f9f9;
}
h1 {
    background: #0078d4;
    color: white;
    padding: 12px;
}
h2 {
    color: #0078d4;
    border-bottom: 1px solid #ddd;
}
table {
    border-collapse: collapse;
    width: 100%;
    table-layout: fixed;
}
th, td {
    border: 1px solid #ddd;
    padding: 6px;
    word-break: break-word;
    white-space: normal;
}
th {
    background-color: #f2f2f2;
}
.pass { color: green; font-weight: bold; }
.fail { color: red; font-weight: bold; }
.warn { color: darkorange; font-weight: bold; }
</style>
"@

    # ----------------------------
    # Summary section
    # ----------------------------
    $summaryHtml = "<ul>" +
        ($script:summary | ForEach-Object { "<li>$_</li>" }) +
        "</ul>"

    # ----------------------------
    # Services table
    # ----------------------------
    $servicesHtml = Convert-ToHtmlTable `
        -Data $health.Services `
        -Columns ServiceName, DisplayName, StartupType, Status, Issue

    # ----------------------------
    # Network connectivity table
    # ----------------------------
    $networkHtml = Convert-ToHtmlTable `
        -Data $results `
        -Columns Name, Target, Reachable

    # ----------------------------
    # Scheduled tasks table
    # ----------------------------
    $tasksHtml = Convert-ToHtmlTable `
        -Data $taskResults `
        -Columns TaskPath, Exists, State, Issue

    # ----------------------------
    # Event log failures table
    # ----------------------------
    $eventFailures = $wuEvents.Events | Where-Object KnownBad

    $eventsHtml = Convert-ToHtmlTable `
        -Data $eventFailures `
        -Columns TimeCreated, EventId, Severity, Category, Message, RemediationHint

    # ----------------------------
    # Assemble HTML
    # ----------------------------
    $html = @"
<html>
<head>
<title>Autopatch Device Health Report</title>
$css
</head>
<body>

<h1>Autopatch Device Health Report</h1>

<p>
<b>Computer:</b> $env:COMPUTERNAME<br/>
<b>User:</b> $env:USERNAME<br/>
<b>Generated:</b> $(Get-Date)<br/>
<b>Transcript:</b> $transcriptFile<br/>
<b>Script Information:</b> <a href="https://www.powershellgallery.com/packages/Get-AutopatchHealth" target="_blank" rel="noopener noreferrer">Get-AutopatchHealth on the PowerShell Gallery</a> 
</p>

<h2>Summary</h2>
$summaryHtml

<h2>Windows Update Services</h2>
$servicesHtml

<h2>Autopatch Network Connectivity</h2>
$networkHtml

<h2>Windows Update Scheduled Tasks</h2>
$tasksHtml

<h2>Windows Update Event Log Failures</h2>
$eventsHtml

</body>
</html>
"@

    # ----------------------------
    # Write + open report
    # ----------------------------
    $html | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Host "HTML report created at $reportFile" -ForegroundColor Green

    if (-not $Remediation) {
        Invoke-Item $reportFile
    }
}

#----------------------------------------------------------- Prep ----------------------------------------------------------

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process first
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
		& "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath"
		Exit $lastexitcode
		}
	}

#****************************************************************************************************************************
#                                                      *** READ ME ***
#****************************************************************************************************************************

# By default, these are $false unless you specify parameters on the command line or un-comment the lines below to force $true

# Run script as remediation (detection only) 
#****************************************************************************************************************************
# Is this script supposed to run as an Intune remediation? If so, un-comment the following line (delete #) to set $Remediation to $true 
# This will force the script to use NoUniCode symbols and provide Intune Admin center friendly detecion output. 

#$Remediation = $true # <------ UNCOMMENT THIS LINE TO FORCE THE SCRIPT TO RUN IN REMEDIATION MODE

# EU Network Data Endpoint Checks
#****************************************************************************************************************************
# Are you running network tests on an EU tenant? If so, un-comment the line below to set $EU to $true

#$EU = $true # <------ UNCOMMENT THIS LINE TO PERFORM EU TENANT NETWORK ENDPOINT TESTING

# Summary report
#****************************************************************************************************************************
# Do you want to see a cool HTML health summary after the script runs? Un-comment the line below to set $Report to $true

#$Report = $true  # <------ UNCOMMENT THIS LINE TO SAVE TRANSCRIPT AND BUILD HTML REPORT

#****************************************************************************************************************************
#                                                      *** READ ME ***
#****************************************************************************************************************************

#------------------------------------------------------- Begin Script -------------------------------------------------------
# If the script runs as a remedation (detection only), a log file will be generated at 
# C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IR_AutopatchHealth.log. If there are no issues, the log file will
# automatically be deleted. If there are issues detected, the file will be renamed IR_AutopatchHealth_ERR.log. If subsequent
# remediation passes all pass, the ERR log file will be deleted after it has aged over 14 days (gives you time to pull the log). 
If ($Remediation){
    try {
    # This will fail if not run as admin
        $logPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
        $logFile = "IR_AutopatchHealth.log"
        $transcriptLogfile = Join-Path $logPath $logFile
        $errFile = Join-Path $logPath "IR_AutopatchHealth_ERR.log"
        Start-Transcript $transcriptLogFile        
        }
    catch {
        <#Do this if a terminating exception happens#>
    }
}

if ($Report){ $transcriptFile = "$env:WINDIR\Temp\AutopatchHealth_$env:COMPUTERNAME.log" ; Start-Transcript $transcriptFile 
            $reportFile = "$env:PUBLIC\Documents\AutopatchHealth_$env:COMPUTERNAME.html" 
            } 

Clear-Host
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "|   Autopatch Device Configuration Validation   |" -ForegroundColor Cyan 
Write-Host "=================================================" -ForegroundColor Cyan 
Write-Host "          Get-Help Get-AutopatchHealh            `n" -Foregroundcolor Green

$script:exitCode = 0 # Variable holding the number of failures detected
$script:summary = @(
) # Arrary holding test results for summary
$script:detectionOutput = @(
) # Arrary holding pre-remediation detection output to display in Intune admin center when this is run as a remediation

# Decide which pass/fail markers to use in case we're running as a remediation
Use-NoUniCode # If this is running as a remediation, use NoUniCode characters

# ----------------------------
# R U Admin?
# ----------------------------
RU-Admin # Some checks will fail if this script is not run as admin

Write-Host "`nGeneral Autopatch Configuration Checks" -ForegroundColor Cyan 
Write-Host "================================================"

# ----------------------------
# Operating System Release Branch
# ----------------------------
    Write-Host "Checking Operating System release channel" -ForegroundColor Yellow
    $releaseBranch = Test-Branch -Branch "CB"
    If ($releaseBranch -eq $true ){ Write-host "$($script:Symbols.Pass) OS Release channel is supported" -ForegroundColor Green ; $script:summary += " $($script:Symbols.Pass) Operating System is supported" }
    else { Write-Host "$($script:Symbols.Fail) Operating System release branch is not supported for Autopatch" -ForegroundColor Red ; $script:exitCode++  ;$script:summary += "$($script:Symbols.Fail) Operating System is not supported" }

# ----------------------------
# Registry checks
# ----------------------------
<# Registry values found at HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate only apply when Windows Update is managed by WSUS / GPO / ConfigMgr.
When updates are managed by Intune, WUfB, or Windows Autopatch, Windows instead honors policies under
HKLM\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState, and legacy WSUS keys are ignored. #>
    Write-Host "Checking registry settings " -ForegroundColor Yellow

    If (Check-Registry -eq $true){ Write-Host "$($script:Symbols.Pass) No blocking or misconfigured WSUS registry values found" -ForegroundColor Green ; $script:summary+= "$($script:Symbols.Pass) No registry issues found" }
    else { Write-Host "$($script:Symbols.Fail) blocking or misconfigured registry values found" -ForegroundColor Red ; $script:exitCode++ ; $script:summary+= "$($script:Symbols.Fail) Registry checks failed" }  

# ----------------------------
# Telemetry
# ----------------------------
<# Devices registered to Windows Autopatch must be configured to send at least “Required” Windows 
   diagnostic data for Autopatch reports to accurately include device state and update status. #>
    try {
        write-host "Checking Telemetry Settings" -ForegroundColor Yellow
        $telemetryResult = Test-Telemetry -minRequired 1 # Security(0),Required/Basic(1),Enhanced(2),Optional/Full(3)
        if ( $telemetryResult) { Write-Host "$($script:Symbols.Pass) Telemetry is >= Required/Basic [1] "-ForegroundColor Green ; $script:summary+= "$($script:Symbols.Pass) Telemetry setting at or above miniumum required level"  }
        else{ Write-Host "$($script:Symbols.Fail) Telemetry set below required minimum" -ForegroundColor Red ; $script:exitCode++ ; $script:summary+= "$($script:Symbols.Fail) Telemetry setting below miniumum required level" }  
    }
    catch {
        # Do this if a terminating exception happens
        Write-Error "An error occurred: $_"
    }

# ----------------------------
# Intune checks
# ----------------------------
# Checks device is enrolled and has been active within the past 30 days
    Write-Host "Checking Intune enrollment and activity" -ForegroundColor Yellow
    If (intune-checks -eq $true) {Write-Host "$($script:Symbols.Pass) Device is enrolled correctly and active in Intune" -ForegroundColor Green ; $script:summary+= "$($script:Symbols.Pass) Device is enrolled correctly and active in Intune" }
    else { Write-Host "$($script:Symbols.Fail) Device is missing Intune enrollment or required co-management workloads" -ForegroundColor Red ; $script:exitCode++ ; $script:summary+= "$($script:Symbols.Fail) Device is missing Intune enrollment or required co-management workloads" }

# ----------------------------
# Authoritative/active update engine (WSUS vs Microsoft Update)
# ----------------------------
<# The authoritative way to determine which Windows Update engine is active is the PolicySources value at
HKLM\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState.
If the value includes 4, the device is controlled by MDM (Intune / Autopatch), and legacy WSUS registry keys 
do not apply. #>
    Write-Host "Checking Update policy authority (single source of truth)" -ForegroundColor Yellow
    $updateEngine = Test-UpdateEngine -PolicySource 4
    If ($updateEngine -eq $true ){ Write-host "$($script:Symbols.Pass) Device is configured for Intune/Autopatch updates" -ForegroundColor Green ; $script:summary+= "$($script:Symbols.Pass) Device is configured for Intune/Autopatch updates" }
    else { Write-Host "$($script:Symbols.Fail) Device is not configured for Intune/Autopatch updates" -ForegroundColor Red ; $script:exitCode++ ; $script:summary+= "$($script:Symbols.Fail) Device is not fully configured for Autopatch" }

# ----------------------------
# Windows Update Services Checks
# ----------------------------
Write-Host "`nWindows Update service status checks" -ForegroundColor Cyan
Write-Host "================================================"
Write-Host "Checking Autopatch (Windows Update) related services" -ForegroundColor Yellow

try {
    $myServicesList = @(
        "WaaSMedicSvc",
        "wuauserv",
        "UsoSvc",
        "BITS",
        "DiagTrack",
        "DoSvc",
        "CryptSvc"
    )

    $health = Get-AutopatchServiceStatus -ServiceNames $myServicesList
    if ($health.ServicesWithIssues -eq 0) {
        $message = "$($script:Symbols.Pass) All required services are healthy"
        Write-Host $Message -ForegroundColor Green ; $script:summary += $message}
    else { $message = "$($script:Symbols.Fail) Required services(s) issue found"
        Write-Host $Message -ForegroundColor Red ; $script:exitCode++ ; $script:summary += $message }

    # Show detailed table
    $health.Services | Format-Table -AutoSize
}
catch {
    Write-Error "An error occurred: $_"
}

# ----------------------------
# Autopatch Network Connectivity Checks
# ----------------------------
try {
    Write-Host "`nAutopatch Network Connectivity Checks" -ForegroundColor Cyan
    Write-Host "================================================"
    Write-Host "Checking Autopatch & DO Network Connectivity Checks" -ForegroundColor Yellow

    # Use this line for non-EU tenants:
    If ( $EU ){ $results = Test-AutopatchNetworkConnection -IncludeEUDataBoundary }
    else { $results = Test-AutopatchNetworkConnection }
     if ($results.Reachable -contains $false) { Write-Host "$($script:Symbols.Fail) Some Autopatch network connectivity checks were unsuccessful" -ForegroundColor Red ; $script:exitCode++ ; $script:summary+= "$($script:Symbols.Fail) Autopatch network connectivity checks unsuccessful" }
    else{ Write-Host "$($script:Symbols.Pass) Autopatch network connectivity checks successful" -ForegroundColor Green ; $script:summary+= "$($script:Symbols.Pass) Autopatch network connectivity checks successful" }

    $results | Select-Object Name, Target, DnsResolved, Reachable | Format-Table -AutoSize
}
catch {
    Write-Error "An error occurred: $_"
}

# ----------------------------
# Windows Update Task Checks
# ----------------------------
Write-Host "`nWindows Update scheduled task checks" -ForegroundColor Cyan
Write-Host "================================================"
Write-Host "Checking Windows Update related scheduled tasks" -ForegroundColor Yellow
$windowsUpdateTasks = @(
    '\Microsoft\Windows\WindowsUpdate\Scheduled Start',
    '\Microsoft\Windows\UpdateOrchestrator\Report policies'
)
try {
    $taskResults = Get-WindowsUpdateTaskStatus -TaskPaths $windowsUpdateTasks
    $taskResults | Format-Table
}
catch {
    Write-Error "An error occurred: $_"
}

# ----------------------------
# Windows Update Event Logs Checks
# ----------------------------
Write-Host "`nWindows Update event log error checks" -ForegroundColor Cyan
Write-Host "================================================"
Write-Host "WindowsUpdateClient, UpdateOrchestrator, and DeliveryOptimization" -ForegroundColor Yellow
$DaysBack = 7 # Number of days to check back in event logs for issues
$wuEvents = Update-Events -DaysBack $DaysBack

if ($wuEvents.IsHealthy){ 
    $message = "$($script:Symbols.Pass) No Windows Update event log failures detected from the last $DaysBack days"
    Write-Host $message -ForegroundColor Green 
    $script:summary += $message 
} else {
    $wuEvents.Events | Where-Object KnownBad | Format-List TimeCreated, EventId, Severity, Category, Message, RemediationHint, LogName | Out-Host
    $message = "$($script:Symbols.Fail) Windows Update event log failures detected"
    Write-Host $message -ForegroundColor Red ; $script:exitCode++ ; $script:summary += $message 
}

# ----------------------------
# Summary
# ----------------------------
Write-Host "`n==================================================" -ForegroundColor Cyan 
Write-Host "|         Autopatch Device Health Summary        |" -ForegroundColor Cyan 
Write-Host "==================================================" -ForegroundColor Cyan
Write-Output ($script:summary -join " `n ") 
Write-Host "==================================================" -ForegroundColor Cyan ; 
Write-Host "          Get-Help Get-AutopatchHealh            `n" -Foregroundcolor Green

# Remediation exit codes for Intune reporting
if ($Remediation) {
    if ($script:exitCode -ge 1) {
    # Create ERR log file
        Stop-Transcript | Out-Null
        If (!(Test-Path $errFile )){ Rename-Item $transcriptLogfile $errFile -Force } 
        else { Remove-Item $errFile -Force -ErrorAction SilentlyContinue 
            Rename-Item $transcriptLogfile $errFile }
    # Create Intune Admin Center detection output
        $failSummary = @()
        $fails = $summary | Where-Object { $_ -match '\bFAIL\b' } # Get only failed entries
        if ($fails) { $fails | ForEach-Object { $failSummary += $_ } } # Add fails to detection output summary
        Write-Host ($failSummary -join " | ") # This is what's displayed in the Intune admin center's detection output
    # Remediation needed    
        Exit 1 
    } else { 
        Write-Output "[PASS] Healthy Autopatch configuration" # This is what's displayed in the Intune admin center's detection output
        Stop-Transcript | Out-Null
        Remove-Item $transcriptLogfile -Force -ErrorAction SilentlyContinue
    # Clean up old ERR logs
        if (Test-Path $errFile){
            $retainDays = 14
            $cutOff = (Get-Date).AddDays(-$retainDays)
            $errAge = (Get-Item $errFile).LastWriteTime
        if ( $errAge -lt $cutOff ){ Remove-Item $errFile -Force -ErrorAction SilentlyContinue }
        }
    # Remediation not needed    
        Exit 0  
    }
}

If ($Report){ Stop-Transcript | Out-Null ; Build-Report } 
Exit
