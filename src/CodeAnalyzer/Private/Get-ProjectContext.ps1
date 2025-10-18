function Get-ProjectContext {
    [CmdletBinding()]
    param()

    function Write-Info([string]$msg){ Write-Host $msg -ForegroundColor Gray }
    function Write-Warn([string]$msg){ Write-Host $msg -ForegroundColor Yellow }
    function Write-Host([string]$msg, [string]$ForegroundColor){ 
        [Console]::WriteLine($msg) 
    }

    $context = @{
        ProjectPassport   = ""
        ArchitectureRules = ""
    }

    if (Test-Path -LiteralPath "project-passport.txt") {
        $context.ProjectPassport = Get-Content -LiteralPath "project-passport.txt" -Raw -Encoding UTF8
        Write-Host "   📋 Загружен паспорт проекта" -ForegroundColor Cyan
    } else {
        Write-Warn "   project-passport.txt не найден (не критично)"
    }

    if (Test-Path -LiteralPath "architecture-rules.txt") {
        $context.ArchitectureRules = Get-Content -LiteralPath "architecture-rules.txt" -Raw -Encoding UTF8
        Write-Host "   🏗️  Загружены архитектурные правила" -ForegroundColor Cyan
    }

    return $context
}