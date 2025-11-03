class BedrockAdapter : IAIProvider {
    [hashtable]$Config

    BedrockAdapter([hashtable]$cfg) {
        @('modelId', 'awsRegion') | ForEach-Object {
            if (-not $cfg.ContainsKey($_) -or [string]::IsNullOrWhiteSpace($cfg[$_])) {
                throw "config.json: обязательное поле '$_' отсутствует или пустое"
            }
        }
        $this.Config = $cfg
    }

    [string] Analyze([string]$prompt, [int]$maxTokens = 2000) {
        # Создаём ContentBlock
        $contentBlock = New-Object Amazon.BedrockRuntime.Model.ContentBlock
        $contentBlock.Text = $prompt

        $message = New-Object Amazon.BedrockRuntime.Model.Message
        $message.Role = "user"
        $message.Content = [System.Collections.Generic.List[Amazon.BedrockRuntime.Model.ContentBlock]]@($contentBlock)

        try {
            $response = Invoke-BDRRConverse `
                -ModelId $this.Config.modelId `
                -Region $this.Config.awsRegion `
                -Message $message `
                -InferenceConfig_MaxTokens $maxTokens
                
            if (-not $response) {
                throw "AWS Bedrock: ответ null"
            }
            if (-not $response.output) {
                throw "AWS Bedrock: нет поля output"
            }
            if (-not $response.output.message) {
                throw "AWS Bedrock: нет поля output.message"
            }
            if ($response.output.message.content.Count -eq 0) {
                throw "AWS Bedrock: content пустой"
            }

            $text = $response.output.message.content[0].text
            if ([string]::IsNullOrWhiteSpace($text)) {
                throw "AWS Bedrock: текст ответа пустой"
            }

            return $text

        }
        catch {
            throw "AWS Bedrock error: $($_.Exception.Message)"
        }
    }
}
