function Invoke-AIRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        
        [Parameter(Mandatory)]
        [hashtable]$Config,
        
        [int]$MaxTokens = 2000,
        [double]$Temperature = 0.1,
        
        [ValidateSet('diff', 'architecture', 'ask', 'general')]
        [string]$RequestType = 'general'
    )
    
    try {
        Write-Host "🤖 [$RequestType] Отправка запроса ($MaxTokens токенов)..." -ForegroundColor Gray
        
        if (-not (Get-Command Invoke-BDRRConverse -ErrorAction SilentlyContinue)) {
            throw "Команда Invoke-BDRRConverse недоступна. Проверьте AWS Tools for PowerShell."
        }

        $messages = @(@{ role = "user"; content = @(@{ text = $Prompt }) })
        
        $response = Invoke-BDRRConverse -ModelId $Config.modelId `
                                        -Message $messages `
                                        -InferenceConfig_Temperature $Temperature `
                                        -InferenceConfig_MaxTokens $MaxTokens `
                                        -Region $Config.awsRegion

        Write-Host "✅ [$RequestType] Ответ получен" -ForegroundColor Green
        
        return @{
            Success = $true
            Result = $response.Output.Message.Content[0].Text.Trim()
            RequestType = $RequestType
            Timestamp = Get-Date
            ModelId = $Config.modelId
        }
    }
    catch {
        Write-Error "❌ [$RequestType] Ошибка: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            RequestType = $RequestType  
            Timestamp = Get-Date
        }
    }
}