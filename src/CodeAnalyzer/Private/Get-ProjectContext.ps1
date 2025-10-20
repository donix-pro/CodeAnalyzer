function Get-ProjectContext {
    param(
        [string]$ProjectPassportPath = '',
        [string]$ArchitectureRulesPath = ''
    )

    function Write-Info([string]$msg){ Write-Host $msg -ForegroundColor Gray }
    function Write-Warn([string]$msg){ Write-Host $msg -ForegroundColor Yellow }

    # ← ДОБАВЛЯЕМ ИНИЦИАЛИЗАЦИЮ!
    $context = @{
        ProjectPassport   = ""
        ArchitectureRules = ""
    }

    # 1. Пробуем загрузить из переданных путей
    if ($ProjectPassportPath -and (Test-Path $ProjectPassportPath)) {
        $context.ProjectPassport = Get-Content -LiteralPath $ProjectPassportPath -Raw -Encoding UTF8
        Write-Host "   📋 Загружен паспорт проекта: $ProjectPassportPath" -ForegroundColor Cyan
    }
    # 2. Ищем в текущей директории
    elseif (Test-Path -LiteralPath "project-passport.txt") {
        $context.ProjectPassport = Get-Content -LiteralPath "project-passport.txt" -Raw -Encoding UTF8
        Write-Host "   📋 Загружен паспорт проекта (локальный)" -ForegroundColor Cyan
    }
    else {
        Write-Warn "   project-passport.txt не найден (не критично)"
    }

    # Аналогично для Architecture Rules
    if ($ArchitectureRulesPath -and (Test-Path $ArchitectureRulesPath)) {
        $context.ArchitectureRules = Get-Content -LiteralPath $ArchitectureRulesPath -Raw -Encoding UTF8
        Write-Host "   🏗️  Загружены архитектурные правила: $ArchitectureRulesPath" -ForegroundColor Cyan
    }
    elseif (Test-Path -LiteralPath "architecture-rules.txt") {
        $context.ArchitectureRules = Get-Content -LiteralPath "architecture-rules.txt" -Raw -Encoding UTF8
        Write-Host "   🏗️  Загружены архитектурные правила (локальные)" -ForegroundColor Cyan
    }

    return $context
}