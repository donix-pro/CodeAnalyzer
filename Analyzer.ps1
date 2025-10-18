[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('diff','architecture','ask')]
    [string]$Mode = 'diff',

    [Parameter(Mandatory=$false)]
    [string]$CompareBranch = 'develop',

    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = '.',

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = 'analysis-results',

    [Parameter(Mandatory=$false)]
    [switch]$IncludeUncommitted,

    [Parameter(Mandatory=$false)]
    [int]$MaxInputChars = 100000,

    [Parameter(Mandatory=$false)]
    [string]$Query,

    [Parameter(Mandatory=$false)]
    [ValidateSet('plain','cheatsheet')]
    [string]$AskFormat = 'cheatsheet',

    [Parameter(Mandatory=$false)]
    [int]$AskMaxTokens = 1500
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ========== КОНФИГУРАЦИЯ ==========
try {
    $configPath = Join-Path $PSScriptRoot "config.json"
    
    if (-not (Test-Path -LiteralPath $configPath)) {
        Write-Error "❌ Файл config.json не найден: $configPath"
        exit 1
    }

    $configRaw = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
    $configObj = $configRaw | ConvertFrom-Json
    
    # Преобразуем в hashtable
    $config = @{
        modelId = $configObj.modelId
        awsRegion = $configObj.awsRegion
    }
    
    # Добавляем excludedDirectories если есть
    if ($configObj.PSObject.Properties.Name -contains 'excludedDirectories') {
        $config.excludedDirectories = $configObj.excludedDirectories
    }

    Write-Host "✅ Конфигурация загружена" -ForegroundColor Green
    Write-Host "   Model: $($config.modelId)" -ForegroundColor Gray
    Write-Host "   Region: $($config.awsRegion)" -ForegroundColor Gray
    
} catch {
    Write-Error "❌ Ошибка загрузки конфигурации: $($_.Exception.Message)"
    exit 1
}

# ========== ИМПОРТ МОДУЛЯ ==========
try {
    $modulePath = Join-Path $PSScriptRoot "src" "CodeAnalyzer" "CodeAnalyzer.psm1"
    if (-not (Test-Path $modulePath)) {
        throw "Модуль не найден: $modulePath"
    }
    Import-Module $modulePath -Force
    Write-Host "✅ Модуль CodeAnalyzer загружен" -ForegroundColor Green
} catch {
    Write-Error "❌ Ошибка загрузки модуля: $($_.Exception.Message)"
    exit 1
}

# ========== ФИКСИРУЕМ ПУТИ ==========
# Делаем OutputPath абсолютным (чтобы не зависел от смены директории)
if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $PSScriptRoot $OutputPath
}
Write-Host "   OutputPath: $OutputPath" -ForegroundColor Gray

# ========== СМЕНА ДИРЕКТОРИИ ==========
$originalLocation = Get-Location
try {
    if ($ProjectPath -ne '.' -and (Test-Path $ProjectPath)) {
        $resolvedPath = Resolve-Path $ProjectPath
        Set-Location $resolvedPath
        Write-Host "📁 Рабочая директория изменена на: $resolvedPath" -ForegroundColor Cyan
    }
    
    Write-Host "`n" + "="*50 -ForegroundColor Cyan
    Write-Host "🚀 .NET CODE ANALYZER" -ForegroundColor Cyan
    Write-Host "="*50 -ForegroundColor Cyan
    
    $modeText = switch ($Mode) {
        'diff'         { '🔍 DIFF-АНАЛИЗ' }
        'architecture' { '🏗️ АРХИТЕКТУРНЫЙ АУДИТ' }
        'ask'          { '💬 ASK' }
        default        { $Mode }
    }
    Write-Host "Режим: $modeText" -ForegroundColor Magenta
    Write-Host "Проект: $(Get-Location)" -ForegroundColor Gray
    Write-Host "Время: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray

    # ========== ЛОГИКА РЕЖИМОВ ==========
    $result = ""

    if ($Mode -eq "diff") {
        Write-Host "`n1️⃣  ПОЛУЧЕНИЕ ИЗМЕНЕНИЙ ИЗ GIT" -ForegroundColor Yellow
        $gitChanges = Get-GitChanges -BaseBranch $CompareBranch -IncludeUncommitted:$IncludeUncommitted -MaxInputChars $MaxInputChars
        
        if (-not $gitChanges) { 
            Write-Host "❌ Нет изменений для анализа" -ForegroundColor Red
            exit 1 
        }

        Write-Host "`n2️⃣  ЗАГРУЗКА КОНТЕКСТА ПРОЕКТА" -ForegroundColor Yellow
        $projectContext = Get-ProjectContext

        if ($gitChanges.Truncated) {
            Write-Host "⚠️  Diff усечён до $MaxInputChars символов" -ForegroundColor Yellow
        }

        Write-Host "`n3️⃣  AI АНАЛИЗ ИЗМЕНЕНИЙ" -ForegroundColor Yellow
        $result = Invoke-DiffAnalysis -GitChanges $gitChanges -ProjectContext $projectContext -Config $config

        Write-Host "`n4️⃣  СОХРАНЕНИЕ РЕЗУЛЬТАТОВ" -ForegroundColor Yellow
        $reportFile = Save-AnalysisResults -AnalysisResult $result -ChangedFiles $gitChanges.ChangedFiles -CompareBranch $CompareBranch -OutputPath $OutputPath -Mode "diff"

        Write-Host "✅ Дифф-анализ завершён" -ForegroundColor Green
        Write-Host "📄 Отчёт: $reportFile" -ForegroundColor Cyan

    } elseif ($Mode -eq "architecture") {
        Write-Host "`n🏗️  АРХИТЕКТУРНЫЙ АУДИТ" -ForegroundColor Yellow
        $result = Invoke-ArchitectureAudit -ProjectPath "." -Config $config

        Write-Host "`n💾 СОХРАНЕНИЕ ОТЧЁТА" -ForegroundColor Yellow
        $reportFile = Save-AnalysisResults -AnalysisResult $result -CompareBranch "" -OutputPath $OutputPath -Mode "architecture" -ProjectPathForReport (Get-Location).Path

        Write-Host "✅ Архитектурный аудит завершён" -ForegroundColor Green
        Write-Host "📄 Отчёт: $reportFile" -ForegroundColor Cyan

    }
    elseif ($Mode -eq "ask") {
        if ([string]::IsNullOrWhiteSpace($Query)) {
            Write-Error "❌ Укажите -Query для режима ask"
            exit 1
        }

        Write-Host "`n💬 ASK-РЕЖИМ" -ForegroundColor Yellow
        $result = Invoke-Ask -Query $Query -AskFormat $AskFormat -MaxTokens $AskMaxTokens -Config $config

        Write-Host "`n📝 СОХРАНЕНИЕ ОТВЕТА" -ForegroundColor Yellow
        $reportFile = Save-AnalysisResults -AnalysisResult $result -CompareBranch "N/A" -OutputPath $OutputPath -Mode "ask" -AskQueryForReport $Query

        Write-Host "✅ Ask-ответ готов" -ForegroundColor Green
        Write-Host "📄 Файл: $reportFile" -ForegroundColor Cyan
    }
} 
catch {
     Write-Error "❌ Ошибка выполнения: $($_.Exception.Message)"
    # Не выходим сразу, чтобы выполнился finally
}
finally {
    # ========== ВОЗВРАТ ДИРЕКТОРИИ ==========
    Set-Location $originalLocation
    Write-Host "`n📁 Возврат в исходную директорию" -ForegroundColor Cyan
}

# ========== ВЫВОД РЕЗУЛЬТАТА В КОНСОЛЬ ==========
if ($result) {
    Write-Host "`n" + "="*60 -ForegroundColor Green
    Write-Host "📋 РЕЗУЛЬТАТ:" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Green
    Write-Host $result -ForegroundColor White
}

Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "🎉 АНАЛИЗ ЗАВЕРШЁН" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Cyan
