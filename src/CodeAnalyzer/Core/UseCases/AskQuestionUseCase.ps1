class AskQuestionUseCase {
    [IAIProvider]$AI
    [ILogger]$Logger

    AskQuestionUseCase([IAIProvider]$ai, [ILogger]$log) {
        $this.AI = $ai
        $this.Logger = $log
    }

    [string] Execute([string]$query) {
        if ([string]::IsNullOrWhiteSpace($query)) {
            throw "Параметр -Query обязателен"
        }

        $this.Logger.Info("ASK: $query")

        # === УНИВЕРСАЛЬНЫЙ ПРОМПТ ===
        $prompt = @"
Ты — эксперт по программированию и архитектуре.
Ответь на вопрос максимально полезно, структурировано и с примерами кода.

ВОПРОС:
$query

ТРЕБОВАНИЯ К ОТВЕТУ:
1. Используй markdown
2. Добавь примеры кода (если применимо)
3. Укажи плюсы и минусы
4. Дай ссылки на документацию

ОТВЕТ:
"@

        try {
            $response = $this.AI.Analyze($prompt)
            $this.Logger.Info("AI ответил на вопрос")
            return "# Ответ на вопрос\n\n**Запрос:** $query\n\n**Ответ:**\n\n$response"
        }
        catch {
            $this.Logger.Error("Ошибка AI: $($_.Exception.Message)")
            return "# Ошибка\n\nНе удалось получить ответ от AI: $($_.Exception.Message)"
        }
    }
}