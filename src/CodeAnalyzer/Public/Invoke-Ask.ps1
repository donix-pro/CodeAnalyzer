function Invoke-Ask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [ValidateSet('plain','cheatsheet')]
        [string]$AskFormat = 'cheatsheet',

        [int]$MaxTokens = 1500,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # Каркас для сжатой «шпаргалки»
    $frame = if ($AskFormat -eq 'cheatsheet') {
@"
Ответь кратко и структурировано.
**Что это:** …
**Когда применять:** …
**Ключевые свойства/ограничения:** …
**Производительность:** …
**Подводные камни:** …
**Примеры (краткие):**
```csharp
// …
```
**Сравнение/Альтернативы:** …
"@
    } else { "" }

    $prompt = @"
ВОПРОС:
$Query

$frame
"@

    try {
         $response = Invoke-AIRequest -Prompt $prompt -Config $Config -MaxTokens $MaxTokens -RequestType 'ask' -Temperature 0.0
    
    if ($response.Success) {
        return $response.Result
    } else {
        return "Ошибка в режиме ask: $($response.Error)"
    }
    }
    catch {
        return "Ошибка в режиме ask: $($_.Exception.Message)"
    }
}