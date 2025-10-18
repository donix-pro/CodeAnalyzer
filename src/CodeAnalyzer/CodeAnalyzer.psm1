#Requires -Version 5.1
#Requires -Module AWSPowerShell.NetCore

# Module variables
$script:ModuleRoot = $PSScriptRoot
$script:ModuleName = "CodeAnalyzer"

# Import private functions
$privateFunctions = Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
foreach ($file in $privateFunctions) {
    Write-Verbose "Importing private function: $($file.Name)"
    . $file.FullName
}

# Import public functions  
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
foreach ($file in $publicFunctions) {
    Write-Verbose "Importing public function: $($file.Name)"
    . $file.FullName
}

# Export public functions (пока пусто - добавим позже)
# Export-ModuleMember -Function $publicFunctions.BaseName

Write-Host "✅ Модуль $ModuleName загружен (Private: $($privateFunctions.Count), Public: $($publicFunctions.Count))" -ForegroundColor Green