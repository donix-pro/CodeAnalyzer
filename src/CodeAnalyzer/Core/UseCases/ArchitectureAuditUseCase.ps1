class ArchitectureAuditUseCase {
    [IAIProvider]$AI
    [ILogger]$Logger
    [hashtable]$Config
    [string]$ProjectPath
    [string]$TargetArchitecture
    [int]$MaxInputChars

    ArchitectureAuditUseCase([IAIProvider]$ai, [ILogger]$log, [hashtable]$cfg, [string]$path = ".", [string]$arch = "Auto", [int]$max = 100000) {
        $this.AI = $ai
        $this.Logger = $log
        $this.Config = $cfg
        $this.ProjectPath = (Resolve-Path $path).Path
        $this.TargetArchitecture = $arch
        $this.MaxInputChars = $max
    }

    [string] Execute() {
        $this.Logger.Info("АРХИТЕКТУРНЫЙ АУДИТ: $($this.ProjectPath) | Цель: $($this.TargetArchitecture)")

        # === Исключения ===
        $excluded = @('bin','obj','.git','.vs','node_modules')
        if ($this.Config.excludedDirectories) {
            $excluded += $this.Config.excludedDirectories
        }
        $pattern = '(?i)(^|[\\/])(' + (($excluded | ForEach-Object { [Regex]::Escape($_) }) -join '|') + ')([\\/]|$)'
        $rx = [Regex]::new($pattern)

        # === Сбор файлов ===
        $files = Get-ChildItem -Path $this.ProjectPath -Recurse -File -Include *.cs, *.ps1, *.psm1 -ErrorAction Stop |
                 Where-Object { -not $rx.IsMatch($_.FullName) }

        if ($files.Count -eq 0) {
            return "Нет файлов для анализа"
        }

        # === Код проекта ===
        $projectCode = ""
        foreach ($file in $files) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            $preview = $content.Substring(0, [Math]::Min(2000, $content.Length))
            $snippet = "ФАЙЛ: $($file.FullName)`n```$($file.Extension.TrimStart('.'))`n$preview`n``` `n`n"
            if (($projectCode.Length + $snippet.Length) -gt $this.MaxInputChars) { break }
            $projectCode += $snippet
        }

        # === Промпт архитектуры ===
        $archPrompt = switch ($this.TargetArchitecture) {
            'Clean' { "Clean Architecture: Use Cases, Domain, Infrastructure, Presentation" }
            'DDD'   { "DDD: Bounded Contexts, Aggregates, Entities, Value Objects" }
            'MVC'   { "MVC: Models, Views, Controllers" }
            'Layered' { "Layered: Presentation, Business, Data Access" }
            'Microservices' { "Microservices: API Gateway, Database per Service" }
            default { "ПРОАНАЛИЗИРУЙ и ПРЕДЛОЖИ оптимальную архитектуру" }
        }

        # === Кастомные правила ===
        $customRules = ""
        $rulesPath = Join-Path $this.ProjectPath "architecture-rules.txt"
        if (Test-Path $rulesPath) {
            $customRules = Get-Content $rulesPath -Raw
        }

        # === ПРОМПТ ДЛЯ AI ===
        $prompt = @"
АНАЛИЗ АРХИТЕКТУРЫ ПРОЕКТА
КОД ($($files.Count) файлов):
$projectCode
ЦЕЛЕВАЯ АРХИТЕКТУРА:
$archPrompt
КАСТОМНЫЕ ПРАВИЛА:
$customRules
ЗАДАЧА:
1. Проанализируй текущую архитектуру
2. Сравни с целевой
3. Найди нарушения
4. Дай план рефакторинга
5. Оцени сложность
ФОРМАТ:
📊 ТЕКУЩЕЕ СОСТОЯНИЕ: ...
🎯 РЕКОМЕНДОВАННАЯ АРХИТЕКТУРА: ...
🔧 ПЛАН РЕФАКТОРИНГА: ...
⚡ ОЦЕНКА СЛОЖНОСТИ: ...
"@

        try {
            $response = $this.AI.Analyze($prompt)
            $this.Logger.Info("AI-аудит архитектуры завершён")
            return $response
        }
        catch {
            $this.Logger.Error("AI ошибка: $($_.Exception.Message)")
            return "Ошибка AI-аудита: $($_.Exception.Message)"
        }
    }
}