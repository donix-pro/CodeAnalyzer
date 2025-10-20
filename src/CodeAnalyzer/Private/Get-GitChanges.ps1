function Get-GitChanges {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseBranch, 
        
        [Parameter(Mandatory)]
        [string]$TargetBranch,
        
        [switch]$IncludeUncommitted,
        
        [Parameter(Mandatory)]
        [int]$MaxInputChars
    )

    function Write-Info([string]$msg){ Write-Host $msg -ForegroundColor Gray }
    function Write-Success([string]$msg){ Write-Host $msg -ForegroundColor Green }
    function Write-Warn([string]$msg){ Write-Host $msg -ForegroundColor Yellow }
    function Write-Err([string]$msg){ Write-Host $msg -ForegroundColor Red }
    
    Write-Host "`n🔍 ПОЛУЧЕНИЕ ИЗМЕНЕНИЙ ИЗ GIT" -ForegroundColor Yellow

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

    # Проверим целевую ветку
    $hasTarget = (& git rev-parse --verify "$TargetBranch" 2>$null)
    if (-not $hasTarget) {
        Write-Warn "   Целевая ветка '$TargetBranch' не найдена локально. Пробую fetch..."
        & git fetch origin $TargetBranch 2>$null | Out-Null
        $hasTarget = (& git rev-parse --verify "$TargetBranch" 2>$null)
        if (-not $hasTarget) {
            Write-Err "   ❌ Ветка '$TargetBranch' не найдена ни локально, ни после fetch"
            return $null
        }
    }

    # ИЗМЕНЯЕМ КОМАНДЫ GIT DIFF:
    $changedFiles = (& git diff --name-only --no-ext-diff "$BaseBranch...$TargetBranch" 2>$null)
    $changedFiles = @($changedFiles) # нормализуем в массив
    $diffOutput   = (& git diff --no-ext-diff "$BaseBranch...$TargetBranch" 2>$null)

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
        Write-Warn "   Нет изменений между $BaseBranch и $TargetBranch"
        return $null
    }

    Write-Success ("   ✅ Изменений: " + $changedFiles.Count + " файлов")
    Write-Info    ("   Размер diff: " + $diffOutput.Length + " символов")
    Write-Info    ("   Сравнение: $BaseBranch...$TargetBranch")  # ← ДОБАВЛЯЕМ
    foreach ($file in $changedFiles) { Write-Info ("      📄 " + $file) }

    if ($diffOutput.Length -gt $MaxInputChars) {
        $truncated = $diffOutput.Substring(0, $MaxInputChars) + "`n[TRUNCATED: original length=$($diffOutput.Length)]"
    } else {
        $truncated = $diffOutput
    }

    return @{
        DiffContent   = $truncated
        ChangedFiles  = $changedFiles
        DiffSize      = $diffOutput.Length
        Truncated     = ($truncated.Length -lt $diffOutput.Length)
    }
}