<#
Stops one explicitly selected CBE audit batch after operator approval.
Checks executable, profile path and process start identity before terminating;
never stops unrelated Arma sessions or trusts a potentially reused PID alone.
Writes shutdown evidence only after every matching process has exited.
Example: ./releaseVerificationAndDeployment/stop_mod_audit.ps1 -Runtime .qa/runtime-20261011-145921-734
#>
param(
    [Parameter(Mandatory)][string]$Runtime,
    [ValidateRange(1,60)][int]$ExitTimeoutSeconds=15
)
$ErrorActionPreference='Stop'
$auditRoot=(Resolve-Path -LiteralPath $Runtime).Path
$launch=Get-Content -LiteralPath (Join-Path $auditRoot 'launch.json') -Raw | ConvertFrom-Json
if ([IO.Path]::GetFullPath($launch.runtime) -ne $auditRoot) {throw 'Launch record does not match selected runtime'}
$targets=@()
$alreadyExited=@()
foreach ($auditPid in $launch.process_ids) {
    $instance=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$auditPid)"
    if (!$instance) {$alreadyExited+=[int]$auditPid; continue}
    if ($instance.Name -notin @('arma3_x64.exe','arma3server_x64.exe') -or
        !$instance.CommandLine -or
        $instance.CommandLine.IndexOf($auditRoot,[StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "PID $auditPid no longer identifies this audit; refusing to terminate it"
    }
    $handle=Get-Process -Id $auditPid -ErrorAction Stop
    if ([Math]::Abs(($handle.StartTime-$instance.CreationDate).TotalSeconds) -gt 2) {
        throw "PID $auditPid identity changed during inspection"
    }
    $targets+=$handle
}
# Validate all identities first so a bad record cannot cause a partially approved shutdown.
foreach ($handle in $targets) {
    if (!$handle.HasExited) {Stop-Process -InputObject $handle -Force -ErrorAction Stop}
}
foreach ($handle in $targets) {
    if (!$handle.WaitForExit($ExitTimeoutSeconds*1000)) {
        throw "Audit process $($handle.Id) did not exit; replacement launch remains blocked"
    }
}
$remaining=@()
foreach ($auditPid in $launch.process_ids) {
    $instance=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$auditPid)"
    if ($instance -and $instance.CommandLine -and
        $instance.CommandLine.IndexOf($auditRoot,[StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $remaining+=[int]$auditPid
    }
}
if ($remaining.Count) {throw "Audit processes remain alive: $remaining"}
@{runtime=$auditRoot; status='EXIT_VERIFIED'; stopped=@($targets | ForEach-Object {$_.Id});
  already_exited=$alreadyExited; remaining=$remaining; verified_at=(Get-Date).ToUniversalTime().ToString('o')
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $auditRoot 'shutdown.json')
Write-Output "Audit shutdown verified: $auditRoot; no matching processes remain"
