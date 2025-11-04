param(
    [ValidateSet('diff','architecture','ask')]
    [string]$Mode = 'diff',

    [string]$CompareBranch = 'origin/main',
    [string]$TargetBranch = 'HEAD',

    [int]$MaxInputChars = 100000,
    [switch]$IncludeUncommitted,

    [string]$ProjectPassportPath = '',
    [string]$ArchitectureRulesPath = '',

    [string]$OutputPath = 'analysis-results',

    [string]$ProjectPath = '.',
    [ValidateSet('Auto', 'Clean', 'DDD', 'MVC', 'Layered', 'Microservices')]
    [string]$Architecture = 'Auto',

    [string]$Query = '',
    [switch]$WhatIf
)

if (-not (Get-Module AWS.Tools.BedrockRuntime -ListAvailable)) {
    Install-Module AWS.Tools.BedrockRuntime -Force -Scope CurrentUser
}

# === ПРОВЕРКА ФАЙЛОВ ===
$required = @(
    "$PSScriptRoot\src\CodeAnalyzer\Private\Get-GitChanges.ps1",
    "$PSScriptRoot\src\CodeAnalyzer\Private\Get-ProjectContext.ps1",
    "$PSScriptRoot\src\CodeAnalyzer\Private\Save-AnalysisResults.ps1"
)
foreach ($f in $required) { if (-not (Test-Path $f)) { throw "ОТСУТСТВУЕТ: $f" } }

# === ИМПОРТ AWS ===
Import-Module AWS.Tools.BedrockRuntime -ErrorAction Stop

# === ПОДКЛЮЧЕНИЕ ===
. "$PSScriptRoot\src\CodeAnalyzer\Core\Interfaces\ILogger.ps1"
. "$PSScriptRoot\src\CodeAnalyzer\Core\Interfaces\IAIProvider.ps1"
. "$PSScriptRoot\src\CodeAnalyzer\Application\Services\DIContainer.ps1"
. "$PSScriptRoot\src\CodeAnalyzer\Infrastructure\Logging\ConsoleLogger.ps1"
. "$PSScriptRoot\src\CodeAnalyzer\Infrastructure\AI\BedrockAdapter.ps1"

# === UseCase ===
. "$PSScriptRoot\src\CodeAnalyzer\Core\UseCases\AnalyzeDiffUseCase.ps1"
. "$PSScriptRoot\src\CodeAnalyzer\Core\UseCases\ArchitectureAuditUseCase.ps1"
. "$PSScriptRoot\src\CodeAnalyzer\Core\UseCases\AskQuestionUseCase.ps1"

. "$PSScriptRoot\src\CodeAnalyzer\Private\Get-GitChanges.ps1"
. "$PSScriptRoot\src\CodeAnalyzer\Private\Get-ProjectContext.ps1"
. "$PSScriptRoot\src\CodeAnalyzer\Private\Save-AnalysisResults.ps1"

# === КОНФИГ ===
$configPath = "$PSScriptRoot\config.json"
if (-not (Test-Path $configPath)) { throw "Нет config.json" }
$configObj = Get-Content $configPath -Raw | ConvertFrom-Json

if ($PSVersionTable.PSVersion.Major -lt 6) {
    $config = @{}
    $configObj.PSObject.Properties | ForEach-Object { $config[$_.Name] = $_.Value }
} else {
    $config = $configObj | ConvertTo-Json | ConvertFrom-Json -AsHashtable
}

# === DI ===
$container = [DIContainer]::new()
$container.Register("ILogger", [ConsoleLogger]::new())
$container.Register("IAIProvider", [BedrockAdapter]::new($config))

$useCase = [AnalyzeDiffUseCase]::new(
    $container.Resolve("IAIProvider"),
    $container.Resolve("ILogger")
)

$logger = $container.Resolve("ILogger")

# === WhatIf ===
if ($WhatIf) {
    $logger.Info("WhatIf: $Mode | $CompareBranch → $TargetBranch")
    return
}

# === ПУТИ ===
if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $PSScriptRoot $OutputPath
}
New-Item -ItemType Directory -Path $OutputPath -Force -ErrorAction SilentlyContinue | Out-Null

# === ОСНОВНАЯ ЛОГИКА ===
$originalLocation = Get-Location
try {
    $result = switch ($Mode) {
        "diff" {
            $gitChanges = Get-GitChanges `
                -BaseBranch $CompareBranch `
                -TargetBranch $TargetBranch `
                -IncludeUncommitted:$IncludeUncommitted `
                -MaxInputChars $MaxInputChars

            if (-not $gitChanges) { $logger.Warn("Нет изменений"); break }

            $projectContext = Get-ProjectContext `
                -ProjectPassportPath $ProjectPassportPath `
                -ArchitectureRulesPath $ArchitectureRulesPath

            $useCase.Execute($gitChanges, $projectContext)
        }
        "architecture" {

            $templatePath = Join-Path $PSScriptRoot "src\CodeAnalyzer\Application\PromptTemplates\ArchitectureAuditPrompt.txt"

            $useCase = [ArchitectureAuditUseCase]::new(
                $container.Resolve("IAIProvider"),
                $logger,
                $config,
                $ProjectPath,
                $Architecture,
                $MaxInputChars,
                $templatePath    
            )
            $useCase.Execute()
        }
        "ask" {
            if (-not $Query) { throw "Укажите -Query для режима ask" }
            $useCase = [AskQuestionUseCase]::new($container.Resolve("IAIProvider"), $logger)
            $useCase.Execute($Query)
        }
        default { throw "Неизвестный режим: $Mode" }
    }

    $changedFiles = if ($Mode -eq 'diff' -and $gitChanges) { $gitChanges.ChangedFiles } else { @() }

    $prefix = switch ($Mode) {
        diff {"diff"}
        architecture {"architecture-audit"}
        ask {"ask-answer"}
        default {"unknown"}
    }

    $outputFile = Join-Path $OutputPath "$prefix_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
    Save-AnalysisResults `
        -AnalysisResult $result `
        -OutputPath $OutputPath `
        -CompareBranch "$CompareBranch → $TargetBranch" `
        -Mode $Mode `
        -ChangedFiles $changedFiles

    $logger.Info("Отчёт: $outputFile")
}
catch {
    $logger.Error("Ошибка: $($_.Exception.Message)")
    throw
}
finally {
    Set-Location $originalLocation
}
