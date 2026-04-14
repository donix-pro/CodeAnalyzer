. "$PSScriptRoot\..\..\Core\Interfaces\IAIProvider.ps1"

class GeminiAdapter : IAIProvider {
    [string]$ApiKey
    [string]$Model
    [int]$DefaultMaxTokens = 2000

    GeminiAdapter([hashtable]$cfg) {
        @('geminiApiKey', 'geminiModel') | ForEach-Object {
            if (-not $cfg.ContainsKey($_) -or [string]::IsNullOrWhiteSpace($cfg[$_])) {
                throw "config.json: обязательное поле '$_' отсутствует или пустое"
            }
        }
        $this.ApiKey = $cfg.geminiApiKey
        $this.Model = $cfg.geminiModel
    }

    [string] Analyze([string]$prompt) {
        return $this.Analyze($prompt, $this.DefaultMaxTokens)
    }

    [string] Analyze([string]$prompt, [int]$maxTokens = 2000) {
        $uri = "https://generativelanguage.googleapis.com/v1beta/models/$($this.Model):generateContent?key=$($this.ApiKey)"

        $body = @{
            contents = @(
                @{
                    role  = "user"
                    parts = @(
                        @{ text = $prompt }
                    )
                }
            )
            generationConfig = @{
                maxOutputTokens = $maxTokens
            }
        } | ConvertTo-Json -Depth 5

        try {
            $response = Invoke-RestMethod `
                -Uri $uri `
                -Method Post `
                -ContentType "application/json" `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($body))

            if (-not $response) {
                throw "Gemini API: ответ null"
            }
            if ($response.promptFeedback -and $response.promptFeedback.blockReason) {
                throw "Gemini API: запрос заблокирован — $($response.promptFeedback.blockReason)"
            }
            if (-not $response.candidates -or $response.candidates.Count -eq 0) {
                throw "Gemini API: нет candidates в ответе"
            }
            if (-not $response.candidates[0].content.parts) {
                throw "Gemini API: нет content.parts в ответе"
            }

            $text = $response.candidates[0].content.parts[0].text
            if ([string]::IsNullOrWhiteSpace($text)) {
                throw "Gemini API: текст ответа пустой"
            }

            return $text

        }
        catch {
            if ($_.Exception.Response) {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errorBody = $reader.ReadToEnd()
                $reader.Close()
                throw "Gemini API error: $($_.Exception.Message) — $errorBody"
            }
            throw "Gemini API error: $($_.Exception.Message)"
        }
    }
}
