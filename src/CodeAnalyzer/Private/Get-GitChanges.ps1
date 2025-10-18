function Get-GitChanges {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseBranch, 
        
        [switch]$IncludeUncommitted,
        
        [Parameter(Mandatory)]
        [int]$MaxInputChars
    )

    Write-Host "`n🔍 ПОЛУЧЕНИЕ ИЗМЕНЕНИЙ ИЗ GIT" -ForegroundColor Yellow

    function Write-Info([string]$msg){ Write-Host $msg -ForegroundColor Gray }
    function Write-Success([string]$msg){ Write-Host $msg -ForegroundColor Green }
    function Write-Warn([string]$msg){ Write-Host $msg -ForegroundColor Yellow }
    function Write-Err([string]$msg){ Write-Host $msg -ForegroundColor Red }
    
    function Truncate-String {
        param([string]$Text, [int]$MaxLen)
        if ([string]::IsNullOrEmpty($Text)) { return $Text }
        if ($Text.Length -le $MaxLen) { return $Text }
        return ($Text.Substring(0, $MaxLen) + "`n[TRUNCATED: original length=$($Text.Length)]")
    }

    $gitRoot = & git rev-parse --show-toplevel 2>$null
    if (-not $gitRoot) {
        Write-Err "   ❌ Не git-репозиторий или git не установлен"
        return $null
    }
    Write-Info  ("   Git репозиторий: " + (Split-Path $gitRoot -Leaf))

    # Проверим, существует ли базовая ветка локально/удалённо
    $hasBase = (& git rev-parse --verify "$BaseBranch" 2>$null)
    if (-not $hasBase) {
        Write-Warn "   Базовая ветка '$BaseBranch' не найдена локально. Пробую fetch..."
        & git fetch origin $BaseBranch 2>$null | Out-Null
        $hasBase = (& git rev-parse --verify "$BaseBranch" 2>$null)
        if (-not $hasBase) {
            Write-Err "   ❌ Ветка '$BaseBranch' не найдена ни локально, ни после fetch"
            return $null
        }
    }

    # Изменённые файлы и diff (без внешних diff-инструментов)
    $changedFiles = (& git diff --name-only --no-ext-diff "$BaseBranch...HEAD" 2>$null)
    $changedFiles = @($changedFiles) # нормализуем в массив
    $diffOutput   = (& git diff --no-ext-diff "$BaseBranch...HEAD" 2>$null)

    if ($IncludeUncommitted) {
        $stagedFiles   = (& git diff --cached --name-only --no-ext-diff 2>$null)
        $unstagedFiles = (& git diff --name-only HEAD --no-ext-diff 2>$null)
        $changedFiles  = @($changedFiles + $stagedFiles + $unstagedFiles) | Sort-Object -Unique

        $stagedDiff   = (& git diff --cached --no-ext-diff 2>$null)
        $unstagedDiff = (& git diff --no-ext-diff 2>$null)
        if ($stagedDiff)   { $diffOutput += "`n`n--- STAGED CHANGES ---`n$stagedDiff" }
        if ($unstagedDiff) { $diffOutput += "`n`n--- UNSTAGED CHANGES ---`n$unstagedDiff" }
    }

    if ([string]::IsNullOrWhiteSpace($diffOutput)) {
        Write-Warn "   Нет изменений между $BaseBranch и текущей веткой"
        return $null
    }

    Write-Success ("   ✅ Изменений: " + $changedFiles.Count + " файлов")
    Write-Info    ("   Размер diff: " + $diffOutput.Length + " символов")
    foreach ($file in $changedFiles) { Write-Info ("      📄 " + $file) }

    # Вернём и «урезанную» версию по лимиту, и полную длину для справки
    $truncated = Truncate-String -Text $diffOutput -MaxLen $MaxInputChars

    return @{
        DiffContent   = $truncated
        ChangedFiles  = $changedFiles
        DiffSize      = $diffOutput.Length
        Truncated     = ($truncated.Length -lt $diffOutput.Length)
    }
}