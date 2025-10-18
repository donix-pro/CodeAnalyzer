function Invoke-DiffAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$GitChanges,
        
        [Parameter(Mandatory)]
        [hashtable]$ProjectContext,
        
        [Parameter(Mandatory)]
        [hashtable]$Config,
        
        [int]$MaxTokens = 2500,
        [double]$Temperature = 0.1
    )
    
    if ($ProjectPath -ne '.' -and (Test-Path $ProjectPath)) {
    Set-Location $ProjectPath
    Write-Host "📁 Рабочая директория изменена на: $ProjectPath" -ForegroundColor Cyan
    }

    function Write-Info([string]$msg) { Write-Host $msg -ForegroundColor Gray }
    function Write-Success([string]$msg) { Write-Host $msg -ForegroundColor Green }
    function Write-Err([string]$msg) { Write-Host $msg -ForegroundColor Red }

    Write-Host "`n🤖 АНАЛИЗ ИЗМЕНЕНИЙ МОДЕЛЬЮ" -ForegroundColor Magenta
    Write-Info  ("   Файлов изменено: " + $GitChanges.ChangedFiles.Count)
    Write-Info  ("   Размер изменений: " + $GitChanges.DiffContent.Length + " символов")
    
    if ($GitChanges.Truncated) {
        Write-Warning "   ⚠️ Diff усечён (лимит символов)"
    }

    $projectInfo = if ($ProjectContext.ProjectPassport) { 
        "КОНТЕКСТ ПРОЕКТА:`n$($ProjectContext.ProjectPassport)`n" 
    } else { "" }
    
    $architectureInfo = if ($ProjectContext.ArchitectureRules) { 
        "АРХИТЕКТУРНЫЕ СТАНДАРТЫ:`n$($ProjectContext.ArchitectureRules)`n" 
    } else { "" }

    $prompt = @"
АНАЛИЗ GIT ИЗМЕНЕНИЙ

$projectInfo
$architectureInfo

СПИСОК ИЗМЕНЕННЫХ ФАЙЛОВ:
$($GitChanges.ChangedFiles -join "`n")

GIT DIFF (КОНКРЕТНЫЕ ИЗМЕНЕНИЯ):
$($GitChanges.DiffContent)

ЗАДАЧА АНАЛИЗА:
1. Проанализируй ВСЕ изменения ЦЕЛИКОМ
2. Найди архитектурные проблемы между измененными файлами
3. Проверь согласованность изменений
4. Выяви потенциальные баги и регрессии
5. Проверь соответствие архитектурным стандартам
6. Дай общую оценку качества изменений

Верни ответ в формате:
📊 ОБЩАЯ ОЦЕНКА: [✅ Хорошо / ⚠️ Есть проблемы / ❌ Критично]

🔍 ГЛАВНЫЕ ПРОБЛЕМЫ:
• Проблема 1: описание
• Проблема 2: описание

💡 РЕКОМЕНДАЦИИ:
• Рекомендация 1: что исправить
• Рекомендация 2: что проверить

🏗️ АРХИТЕКТУРНЫЕ ЗАМЕЧАНИЯ:
• Замечание 1
• Замечание 2
"@

    try {
        $response = Invoke-AIRequest -Prompt $prompt -Config $Config -MaxTokens $MaxTokens -RequestType 'diff' -Temperature $Temperature
        
        if ($response.Success) {
            Write-Success "   ✅ Анализ получен"
            return $response.Result
        } else {
            Write-Err "   ❌ Ошибка анализа: $($response.Error)"
            return "Не удалось получить анализ изменений: $($response.Error)"
        }
    }
    catch {
        Write-Err "   ❌ Ошибка анализа: $($_.Exception.Message)"
        return "Ошибка при анализе изменений: $($_.Exception.Message)"
    }
}