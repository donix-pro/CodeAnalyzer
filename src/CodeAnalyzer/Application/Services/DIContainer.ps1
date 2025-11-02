class DIContainer {
    [hashtable]$Services = @{}

    # Регистрация: "ILogger" → [ConsoleLogger]
    [void] Register([string]$interfaceName, [object]$instance) {
        $this.Services[$interfaceName] = $instance
    }

    # Получение: дай мне ILogger
    [object] Resolve([string]$interfaceName) {
        if (-not $this.Services.ContainsKey($interfaceName)) {
            throw "Сервис не зарегистрирован: $interfaceName"
        }
        return $this.Services[$interfaceName]
    }
}
