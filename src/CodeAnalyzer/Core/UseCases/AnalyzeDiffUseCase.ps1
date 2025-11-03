class AnalyzeDiffUseCase {
    [IAIProvider]$AI
    [ILogger]$Logger
    [string]$TemplatePath = "$PSScriptRoot\..\..\Application\PromptTemplates\DiffAnalysisPrompt.txt"

    AnalyzeDiffUseCase([IAIProvider]$ai, [ILogger]$log) {
        $this.AI = $ai
        $this.Logger = $log
    }

    [string] Execute([hashtable]$GitChanges, [hashtable]$ProjectContext) {

        if ($GitChanges.Truncated) {
            $this.Logger.Warn("Diff усечён")
        }

        if (-not $ProjectContext is [hashtable]){
            throw "ProjectContext должен быть hashtable"
        }

        $this.Logger.Info("Начинаем анализ diff...")

        # === СТАТИСТИКА ===
        $this.Logger.Info("Файлов изменено: $($GitChanges.ChangedFiles.Count)")
        $this.Logger.Info("Размер diff: $($GitChanges.DiffContent.Length) символов")

        # === ЧТЕНИЕ ШАБЛОНА ===
        if (-not (Test-Path $this.TemplatePath)) {
            throw "Шаблон не найден: $($this.TemplatePath)"
        }
        $template = Get-Content $this.TemplatePath -Raw

        # === ПОДСТАНОВКА ===
        $projectInfo = $ProjectContext.ProjectPassport ?? ""
        $architectureInfo = $ProjectContext.ArchitectureRules ?? ""

        $prompt = $template `
            -replace '\$projectInfo', $projectInfo `
            -replace '\$architectureInfo', $architectureInfo `
            -replace '\$GitChanges\.ChangedFiles', ($GitChanges.ChangedFiles -join "`n") `
            -replace '\$GitChanges\.DiffContent', $GitChanges.DiffContent

        # === ПРОВЕРКА ===
        if ($prompt -match '\$') {
            $this.Logger.Warn("Не все переменные заменены")
        }

        # === ОТПРАВКА В AI ===
        try {
            $response = $this.AI.Analyze($prompt)
            $this.Logger.Info("AI ответил")
            return $response
        }
        catch {
            $this.Logger.Error("AI ошибка: $($_.Exception.Message)")
            throw
        }
    }
}
