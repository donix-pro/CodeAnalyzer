function Invoke-ArchitectureAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectPath = ".",
        
        [Parameter(Mandatory)]
        [hashtable]$Config,
        
        [ValidateSet('Auto', 'Clean', 'DDD', 'MVC', 'Layered', 'Microservices')]
        [string]$TargetArchitecture = 'Auto',
        
        [int]$MaxInputChars = 100000
    )

    function Write-Info([string]$msg){ Write-Host $msg -ForegroundColor Gray }
    function Write-Success([string]$msg){ Write-Host $msg -ForegroundColor Green }
    function Write-Warn([string]$msg){ Write-Host $msg -ForegroundColor Yellow }
    function Write-Err([string]$msg){ Write-Host $msg -ForegroundColor Red }

    Write-Host "`n🏗️  АРХИТЕКТУРНЫЙ АУДИТ ПРОЕКТА" -ForegroundColor Magenta
    Write-Info  ("   Анализируемая папка: $ProjectPath")
    Write-Info  ("   Целевая архитектура: $TargetArchitecture")

    # Определяем архитектурный промпт
    $architecturePrompt = switch ($TargetArchitecture) {
        'Clean' { 
            "ЦЕЛЕВАЯ АРХИТЕКТУРА: Clean Architecture`n• Use Cases (Application Layer)`n• Domain Entities & Business Rules`n• Infrastructure (External Concerns)`n• Presentation (Controllers, UI)"
        }
        'DDD' { 
            "ЦЕЛЕВАЯ АРХИТЕКТУРА: Domain-Driven Design`n• Bounded Contexts`n• Aggregates & Entities`n• Value Objects`n• Domain Services`n• Repositories"
        }
        'MVC' { 
            "ЦЕЛЕВАЯ АРХИТЕКТУРА: Model-View-Controller`n• Models (Business Data)`n• Views (Presentation)`n• Controllers (Coordination)`n• Separation of Concerns"
        }
        'Layered' { 
            "ЦЕЛЕВАЯ АРХИТЕКТУРА: Layered Architecture`n• Presentation Layer`n• Business Logic Layer`n• Data Access Layer`n• Clear Layer Dependencies"
        }
        'Microservices' { 
            "ЦЕЛЕВАЯ АРХИТЕКТУРА: Microservices`n• Independent Services`n• API Gateway`n• Database per Service`n• Inter-service Communication"
        }
        default { 
            "ПРОАНАЛИЗИРУЙ И ПРЕДЛОЖИ оптимальную архитектуру для этого типа проекта"
        }
    }

    # Сбор файлов .cs c исключениями
    if (-not (Test-Path -LiteralPath $ProjectPath)) {
        Write-Err "   ❌ Путь '$ProjectPath' не найден"
        return "Указанный путь не существует"
    }

    $root = (Resolve-Path -LiteralPath $ProjectPath).Path

    # Убедимся, что excludedDirectories — массив строк
    $excluded = @()
    if ($Config.excludedDirectories -is [System.Array]) {
        $excluded = $Config.excludedDirectories
    } elseif ($Config.excludedDirectories) {
        $excluded = @($Config.excludedDirectories.ToString())
    }
    if (-not $excluded -or $excluded.Count -eq 0) {
        $excluded = @('bin','obj','.git','.vs','node_modules')
    }

    # Регэксп для исключения директорий
    $escaped = $excluded | ForEach-Object { [Regex]::Escape($_) }
    $pattern = '(?i)(^|[\\/])(' + ($escaped -join '|') + ')([\\/]|$)'
    $rx = [Regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    try {
         $allFiles = @(
            Get-ChildItem -Path $root -Recurse -File -Include *.cs, *.ps1, *.psm1 -ErrorAction Stop |
            Where-Object { -not $rx.IsMatch($_.FullName) }
        )
    } catch {
        Write-Err "   ❌ Ошибка обхода файлов: $($_.Exception.Message)"
        return "Не удалось собрать список файлов"
    }

    Write-Success ("   Найдено C# файлов: " + $allFiles.Count)
    if ($allFiles.Count -eq 0) { 
        Write-Warn "   ⚠️ Не найдено C# файлов для анализа"
        return "Нет C# файлов для анализа. Поддерживаются C# проекты."
    }

    $projectCode = ""
    $fileCounter = 1
    foreach ($file in $allFiles) {
        try {
            $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
            $preview = $content.Substring(0, [Math]::Min(2000, $content.Length))
            $fileSnippet = "ФАЙЛ ${fileCounter}: $($file.FullName)`n```csharp`n$preview`n``` `n`n"

            if (($projectCode.Length + $fileSnippet.Length) -gt $MaxInputChars) {
                Write-Warn "   Достигнут лимит размера — пропускаем файл $($file.Name)"
                break
            }

            $projectCode += $fileSnippet
            $fileCounter++
        } catch {
            Write-Warn "   Ошибка чтения файла: $($file.FullName)"
        }
    }

    # Загружаем кастомные правила если есть
    $customRules = ""
    if (Test-Path -LiteralPath "architecture-rules.txt") {
        $customRules = Get-Content -LiteralPath "architecture-rules.txt" -Raw -Encoding UTF8
        Write-Info "   📋 Загружены кастомные правила"
    }

    $prompt = @"
АНАЛИЗ АРХИТЕКТУРЫ ПРОЕКТА

ТЕКУЩАЯ СТРУКТУРА ПРОЕКТА ($($allFiles.Count) файлов):
$projectCode

$architecturePrompt

КАСТОМНЫЕ ПРАВИЛА:
$customRules

ЗАДАЧА:
1. Проанализируй текущую архитектуру проекта
2. Предложи улучшения в соответствии с целевой архитектурой
3. Определи проблемные места и архитектурные нарушения
4. Предложи конкретный план рефакторинга
5. Оцени сложность миграции

Верни ответ в формате:

📊 ТЕКУЩЕЕ СОСТОЯНИЕ:
• Сильные стороны: ...
• Проблемы: ...

🎯 РЕКОМЕНДОВАННАЯ АРХИТЕКТУРА:
• Тип архитектуры: [Clean/DDD/MVC/etc.]
• Обоснование: ...

🔧 ПЛАН РЕФАКТОРИНГА:
1. Этап 1: [что сделать]
2. Этап 2: [что сделать]

📁 ПРЕДЛАГАЕМАЯ СТРУКТУРА:
• Слои/Компоненты: ...
• Распределение ответственности: ...

⚡ ОЦЕНКА СЛОЖНОСТИ:
• Сложность: [Низкая/Средняя/Высокая]
• Время: [примерная оценка]
• Риски: [что может пойти не так]
"@

    Write-Info  ("   Подготовлено " + $projectCode.Length + " символов ввода для модели")

    try {
        $response = Invoke-AIRequest -Prompt $prompt -Config $Config -MaxTokens 3000 -RequestType 'architecture' -Temperature 0.1
        
        if ($response.Success) {
            Write-Success "   ✅ Архитектурный аудит получен"
            return $response.Result
        }
        return "Не удалось выполнить архитектурный аудит"
    } catch {
        Write-Err "   ❌ Ошибка аудита: $($_.Exception.Message)"
        return "Ошибка архитектурного аудита: $($_.Exception.Message)"
    }
}
