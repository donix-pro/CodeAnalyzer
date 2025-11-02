class AnalyzeDiffUseCase {
    [IAIProvider]$AI
    [ILogger]$Logger

    AnalyzeDiffUseCase([IAIProvider]$ai, [ILogger]$log) {
        $this.AI = $ai
        $this.Logger = $log
    }

    [string] Execute([hashtable]$GitChanges, [hashtable]$ProjectContext) {
        $this.Logger.Info("Начинаем анализ изменений...")

        # === Статистика ===
        $this.Logger.Info("Файлов изменено: $($GitChanges.ChangedFiles.Count)")
        $this.Logger.Info("Размер diff: $($GitChanges.DiffContent.Length) символов")
        if ($GitChanges.Truncated) {
            $this.Logger.Warn("Diff усечён (лимит символов)")
        }

        # === Формируем контекст ===
        $projectInfo = if ($ProjectContext.ProjectPassport) {
            "КОНТЕКСТ ПРОЕКТА:`n$($ProjectContext.ProjectPassport)`n"
        } else { "" }

        $architectureInfo = if ($ProjectContext.ArchitectureRules) {
            "АРХИТЕКТУРНЫЕ СТАНДАРТЫ:`n$($ProjectContext.ArchitectureRules)`n"
        } else { "" }

        # === Формируем промпт ===
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
2. Если тебе не хватает контекста о бизнес-правилах или архитектуре - ПОПРОСИ уточнить
3. Найди архитектурные проблемы между измененными файлами
4. Проверь согласованность изменений
5. Выяви потенциальные баги и регрессии
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

        # === Отправляем в AI ===
        try {
            $response = $this.AI.Analyze($prompt)
            $this.Logger.Info("Анализ получен от AI")
            return $response
        }
        catch {
            $this.Logger.Error("Ошибка при запросе к AI: $($_.Exception.Message)")
            throw "Не удалось получить анализ: $($_.Exception.Message)"
        }
    }
}
