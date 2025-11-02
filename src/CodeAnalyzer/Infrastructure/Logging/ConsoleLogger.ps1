class ConsoleLogger : ILogger {
    [void] Info([string]$msg)  { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
    [void] Warn([string]$msg)  { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
    [void] Error([string]$msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }
}
