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

    [string] Analyze([string]$prompt) {
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
                -InferenceConfig_MaxTokens 2000

            return $response.output.message.content[0].text
        }
        catch {
            throw "AWS Bedrock error: $($_.Exception.Message)"
        }
    }
}