# Get-AutopatchHealth

A **read-only Windows Autopatch health assessment** PowerShell script that validates Autopatch and Feature Update readiness by performing comprehensive checks across **device configuration**, **policy authority**, **services**, **registry**, **network connectivity**, **scheduled tasks**, and **Windows Update event logs**.

> Designed to run safely in **SYSTEM** or **user** context, and to produce console output plus an **exit code suitable for Intune detection/remediation workflows**.

***

## What it checks

### 1) General configuration health

*   **OS servicing branch / release channel**: verifies the device is on a supported GA/production channel (not Insider/Preview).
*   **Registry settings**: checks for Autopatch-blocking or WSUS-redirecting values under:
    *   `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` (`DoNotConnectToWindowsUpdateInternetLocations`, `DisableWindowsUpdateAccess`, `WUServer`, `WUStatusServer`)
    *   `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU` (`NoAutoUpdate`)
    *   Update source override keys (e.g., `SetPolicyDrivenUpdateSourceForDriverUpdates`, `FeatureUpdates`, `OtherUpdates`, `QualityUpdates`) that can push devices toward WSUS when combined with WSUS configuration.
*   **Telemetry**: reads local policy to confirm minimum telemetry is **1 (Required/Basic)**. 
*   **Intune enrollment & IME activity**: validates enrollment indicators and checks IME activity/log signals within a recent window (script references last 28 days).
*   **Co-management workloads (if applicable)**: confirms required workloads are owned appropriately (Windows Update policies, device configuration, Office C2R apps). [\[Get-Autopa...Health.ps1
*   **Update policy authority (source of truth)**: reads `PolicySources` from  
    `HKLM\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState\PolicySources` and interprets values such as `4 = Intune/Autopatch`.

> Note: The script explicitly comments that legacy WSUS keys under `...\Policies\Microsoft\Windows\WindowsUpdate` are only authoritative for WSUS/GPO/ConfigMgr, and that Intune/WUfB/Autopatch relies on policy state under `...\Microsoft\WindowsUpdate\UpdatePolicy\PolicyState`.

### 2) Autopatch service health

Validates Windows Update–related services such as:

*   `BITS`, `CryptSvc`, `DiagTrack`, `DoSvc`, `UsoSvc`, `WaaSMedicSvc`, `wuauserv`

### 3) Network endpoint connectivity

Confirms reachability of Microsoft/Autopatch endpoints including:

*   `mmdcustomer.microsoft.com`, `mmdls.microsoft.com`, `login.windows.net`,  
    `device.autopatch.microsoft.com`, `services.autopatch.microsoft.com`,  
    `devicelistenerprod.microsoft.com`
*   EU boundary variant: `devicelistenprod.eudb.microsoft.com` (EU tenants)
*   Payload storage: `payloadprod*.blob.core.windows.net`

Microsoft’s published Autopatch network allowlist documentation aligns with the endpoint set this script tests. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/deployment/windows-autopatch/prepare/windows-autopatch-configure-network)

### 4) Scheduled task checks

Validates required scheduled tasks, including:

*   `\Microsoft\Windows\WindowsUpdate\Scheduled Start`
*   `\Microsoft\Windows\UpdateOrchestrator\Report policies`
### 5) Windows Update event log checks

Scans for known update-related issues within the last **7 days** (configurable via `$DaysBack`) across:

*   `Microsoft-Windows-WindowsUpdateClient/Operational`
*   `Microsoft-Windows-WindowsUpdateClient/Admin`
*   `Microsoft-Windows-UpdateOrchestrator/Operational`
*   `Microsoft-Windows-DeliveryOptimization/Operational`
***

## Requirements

*   Windows PowerShell (script relaunches itself in **64-bit PowerShell** when invoked from a 32-bit process on x64 systems).
*   Recommended: run **elevated** (some checks may return false negatives without admin rights; the script explicitly warns about this).
*   No external PowerShell modules required (script is self-contained).

***

## Quick start

Clone the repo and run:

```powershell
.\Get-AutopatchHealth.ps1
```

This prints results to the console and returns an exit code that you can use in automation.

***

## Parameters

### `-Remediation`

Use this to **test the script’s behavior as an Intune remediation** (detection-only mode output formatting and logging behavior).

```powershell
.\Get-AutopatchHealth.ps1 -Remediation
```

**Remediation mode logging:**

*   Writes transcript to:  
    `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IR_AutopatchHealth.log`
*   If failures are detected, the transcript is retained/renamed as:  
    `IR_AutopatchHealth_ERR.log`
*   If later runs succeed, the ERR log is cleaned up after **14 days**.

**Why output formatting changes in Remediation mode:**  
The script contains a helper that avoids Unicode symbols because they may not render in the Intune admin center remediation output.

> Microsoft’s remediation guidance also notes script/output considerations (e.g., encoding in UTF‑8). [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/remediations)

### `-EU`

Includes EU Data Boundary endpoints during network checks.[\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/deployment/windows-autopatch/prepare/windows-autopatch-configure-network)

```powershell
.\Get-AutopatchHealth.ps1 -EU
```

### `-Report`

Creates a transcript and generates an **HTML report** at the end of execution, then opens it in the default browser.

```powershell
.\Get-AutopatchHealth.ps1 -Report
```

Report artifacts:

*   Transcript: `%WINDIR%\Temp\AutopatchHealth_<COMPUTERNAME>.log`
*   HTML report: `C:\Users\Public\Documents\AutopatchHealth_<COMPUTERNAME>.html`

***

## “Force mode” options (editing the script)

Inside the script there is a **READ ME section** showing how to hard-code flags by uncommenting lines to force:

*   `$Remediation = $true`
*   `$EU = $true`
*   `$Report = $true` 

This is useful when packaging the script into platforms where passing parameters is inconvenient.

***

## Exit codes (Intune-friendly)

*   **Exit `0`**: Healthy / no failures detected. 
*   **Exit `1`**: One or more failures detected (Remediation mode uses this to indicate remediation is needed).

***

## Using with Microsoft Intune Remediations

This script is designed to behave well as an Intune remediation detection script:

*   Run it in detection-only mode with `-Remediation` for Admin Center friendly output.
*   Leverage the exit code for compliance reporting. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/remediations)

> Tip: Keep scripts encoded in UTF‑8 as recommended in Microsoft’s remediation documentation. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/remediations)

***

## Network allowlist references

If devices fail the network connectivity checks, confirm your proxy/firewall allowlist matches Microsoft’s documented Windows Autopatch endpoint requirements. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/deployment/windows-autopatch/prepare/windows-autopatch-configure-network)

*   Microsoft Learn: Configure your network for Windows Autopatch. [Configure your network | Microsoft Learn](https://learn.microsoft.com/en-us/windows/deployment/windows-autopatch/prepare/windows-autopatch-configure-network)

***

## Versioning / release notes

The script embeds release notes in the header. Recent highlights include:

*   v2.3.2: added HTML summary report and logging functionality.
*   v2.2.0: added Windows Update event log checks and reporting.
*   v2.0.0+: expanded checks and documentation; removed deprecated endpoints.

***

## Contributing

Contributions are welcome:

1.  Fork the repo
2.  Create a feature branch
3.  Submit a merge request with a clear description and test notes

If you add new checks, please include:

*   what problem the check detects
*   expected pass/fail output
*   any safe remediation guidance (if applicable)

***

## Disclaimer

This script is intended for **read-only health validation** and troubleshooting support. Always validate changes in a test ring before applying policy or registry modifications broadly.

***

## Support / Feedback

If you find a bug or want a new check added:

*   Open an issue with:
    *   Windows version/build
    *   Enrollment/co-management context
    *   Relevant output (and attach the remediation log if available)


