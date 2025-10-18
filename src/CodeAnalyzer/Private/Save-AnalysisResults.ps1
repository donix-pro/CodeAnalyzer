function Save-AnalysisResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] 
        [string]$AnalysisResult,
        
        [array]$ChangedFiles = @(),
        
        [Parameter(Mandatory)]
        [string]$CompareBranch,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter(Mandatory)]
        [ValidateSet('diff','architecture','ask')]
        [string]$Mode,
        
        [string]$ProjectPathForReport = '',
        
        [string]$AskQueryForReport = ''
    )

    # Преобразуем OutputPath в абсолютный путь (относительно скрипта)
    if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
        $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
        $OutputPath = Join-Path $scriptRoot $OutputPath
    }

    # Создаём директорию
    if (-not (Test-Path -LiteralPath $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-Host "   📁 Создана директория: $OutputPath" -ForegroundColor Gray
    }

    # Единый шаблон для всех режимов
    $templates = @{
        diff = @{
            FileName = "diff-analysis-{0}.md"
            Title = "Анализ Git изменений"
            Metadata = @{
                "Сравнение" = "$CompareBranch → $(try { & git branch --show-current 2>$null } catch { 'unknown' })"
                "Измененных файлов" = $ChangedFiles.Count
            }
        }
        architecture = @{
            FileName = "architecture-audit-{0}.md" 
            Title = "Архитектурный аудит проекта"
            Metadata = @{
                "Папка анализа" = $ProjectPathForReport
                "Целевая архитектура" = "DDD + Clean Architecture"
            }
        }
        ask = @{
            FileName = "ask-answer-{0}.md"
            Title = "Ответ на запрос" 
            Metadata = @{
                "Запрос" = if ([string]::IsNullOrWhiteSpace($AskQueryForReport)) { "(не указан)" } else { $AskQueryForReport }
            }
        }
    }

    $template = $templates[$Mode]
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $reportFile = Join-Path $OutputPath ($template.FileName -f $timestamp)

    # Генерация метаданных
    $metadataContent = ($template.Metadata.GetEnumerator() | 
        ForEach-Object { "**$($_.Key):** $($_.Value)" }) -join "  "

    # Единый шаблон отчёта
    $reportContent = @"
# $($template.Title)

**Дата анализа:** $(Get-Date)  
**Режим:** $(($Mode -replace '^.', { $_.Value.ToUpper() }))  
$metadataContent

## 📊 Результат анализа

$AnalysisResult

## 🔍 Детали
- **Время анализа:** $(Get-Date -Format 'HH:mm:ss')
"@

    # Добавляем список файлов только для diff режима
    if ($Mode -eq 'diff' -and $ChangedFiles.Count -gt 0) {
        $fileList = $ChangedFiles -join "`n"
        $reportContent = $reportContent -replace '## 📊 Результат анализа', "## 📋 Измененные файлы`n`n$fileList`n`n## 📊 Результат анализа"
    }

    $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
    return $reportFile
}