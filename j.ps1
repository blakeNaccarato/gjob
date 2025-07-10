<#.SYNOPSIS
Run Just recipes.#>
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments)][string[]]$RemainingArgs)

#* MARK: Config sourced by recipes
Set-StrictMode -Version '3.0'
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $True
$ErrorView = 'NormalView'
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.Encoding]::UTF8

#* MARK: Invokes Just, called at the bottom of this file
function Invoke-Just {
    #? Capture variables set by command line
    $Vars = @{}
    if ($RemainingArgs) {
        $Idx = 0
        for ($Idx = 0; $Idx -lt $RemainingArgs.Count; $Idx++) {
            if ($RemainingArgs[$Idx] -ne '--set') { continue }
            if (($Idx + 2) -ge $RemainingArgs.Count) { break }
            $Vars[$RemainingArgs[$Idx + 1]] = $RemainingArgs[$Idx + 2]
            $Idx += 2
        }
    }
    $Vars = $Vars | Format-Env
    #? Sync environment variables necessary for bootstrapping
    $Uvx = $Env:CI ? 'uvx' : './uvx'
    $Environ = Merge-Envs -Upper ((Get-Env 'base'), $Vars)
    $RawCI = ($Environ['ci'] ? $Environ['ci'] : $Env:CI)
    $CI = ($null -ne $RawCI) -and ($RawCI -ne 0)
    $Just = @('--from', "rust-just@$($Environ['JUST_VERSION'])", 'just')
    #? Just sync CLI vars line if calling recursively from inside a recipe
    if ($Env:JUST) { $Vars | Sync-Env }
    else {
        #? Otherwise sync the full environment
        $Environ = Merge-Envs ($Environ, (Get-Env ($CI ? 'ci' : 'contrib')))
        $Environ | Sync-Env
        if (!$CI) { Sync-Uv $Environ['UV_VERSION'] }
        #? Install YAML parser in CI if missing
        if ($CI) { & $Uvx @Just --justfile 'scripts/inst.just' 'powershell-yaml' }
        #? Parse template answers YAML data, merge into environment, and sync
        Merge-Envs -Upper ((Get-Env 'answers'), $Environ) | Sync-Env
        if ($CI) { & $Uvx @Just --justfile 'scripts/inst.just' 'powershell-yaml' }
    }
    $Env:JUST = '1'
    #? Invoke Just if arguments passed, otherwise can dot-source in recipes w/o recurse
    try { if ($RemainingArgs) { & $Uvx @Just @RemainingArgs } }
    finally { $Env:JUST = $null }
}

#* MARK: Functions used above and sourced by recipes

function Sync-Uv {
    <#.SYNOPSIS
    Sync uv version.#>
    param([Parameter(Mandatory, ValueFromPipeline)][string]$Version)
    if (Get-Command './uv' -ErrorAction 'Ignore') {
        (./uv --color 'never' self version) -match 'uv ([\d.]+)' | Out-Null
        if ($Matches[1] -eq $Version) { return }
    }
    if ($IsWindows) {
        $InstallUv = "Invoke-RestMethod https://astral.sh/uv/$Version/install.ps1 | Invoke-Expression"
        powershell -ExecutionPolicy 'ByPass' -Command $InstallUv
        return
    }
    curl -LsSf "https://astral.sh/uv/$Version/install.sh" | sh
}

function Sync-Env {
    <#.SYNOPSIS
    Sync environment variables.#>
    param([Parameter(Mandatory, ValueFromPipeline)][hashtable]$Environ)
    process {
        $Environ.GetEnumerator() | ForEach-Object {
            Set-Item "Env:$($_.Name | Set-Case -Upper)" $_.Value
        }
    }
}

function Limit-Env {
    <#.SYNOPSIS
    Limit environment to specific variables.#>
    param(
        [Parameter(Mandatory)][hashtable]$Environ,
        [Parameter(Mandatory)][string[]]$Vars,
        [switch]$Lower,
        [switch]$Upper
    )
    $Limited = [ordered]@{}
    $Environ.GetEnumerator() | ForEach-Object {
        if ($Vars -contains $_.Name) {
            $Limited[($_.Name | Set-Case -Lower:$Lower -Upper:$Upper)] = $_.Value
        }
    }
    return Format-Env $Limited
}

function Merge-Envs {
    <#.SYNOPSIS
    Merge environment variables.#>
    param(
        [Parameter(Mandatory, ValueFromPipeline)][hashtable[]]$Envs,
        [switch]$Lower,
        [switch]$Upper
    )
    $Merged = [ordered]@{}
    $Envs | ForEach-Object { $_.GetEnumerator() } | ForEach-Object {
        $Merged[($_.Name | Set-Case -Lower:$Lower -Upper:$Upper)] = $_.Value
    }
    return Format-Env $Merged
}

function Get-Env {
    <#.SYNOPSIS
    Get environment variables.#>
    param(
        [Parameter(Mandatory, ValueFromPipeline)][string]$Name,
        [switch]$Lower,
        [switch]$Upper
    )
    process {
        $Envs = (Get-Content 'env.json' | ConvertFrom-Json)
        if (($Path = $Envs.$Name) -is [string]) {
            if ($Path.EndsWith('.json')) {
                $RawEnviron = Get-Content $Path | ConvertFrom-Json
            }
            elseif ($Path.EndsWith('.yaml') -or $Path.EndsWith('.yml')) {
                $RawEnviron = Get-Content $Path | ConvertFrom-Yaml
            }
            else { throw "Could not parse environment '$Name' at '$Path'" }
        }
        else { $RawEnviron = $Envs.$Name.PsObject.Properties }
        $Environ = [ordered]@{}
        $RawEnviron.GetEnumerator() | Sort-Object 'Name' | ForEach-Object {
            $Name = (($_.Name -match '^_.+$') ? "template$($_.Name)" : $_.Name)
            $Name = $Name | Set-Case -Lower:$Lower -Upper:$Upper
            $Value = [string]$_.Value
            if (('false', '0') -contains $Value.ToLower()) { $Value = $null }
            if ($Value.ToLower() -eq 'true') { $Value = 'true' }
            if ($Value -match '^Env:.+$') {
                $Value = ($EnvVar = Get-EnvVar $Value) ? $EnvVar : ''
            }
            if ($Value -ne '') { $Environ[$Name] = $Value }
        }
        return Format-Env $Environ
    }
}

function Format-Env {
    <#.SYNOPSIS
    Sort environment variables by name.#>
    param([Parameter(Mandatory, ValueFromPipeline)][hashtable]$Environ)
    $Sorted = [ordered]@{}
    $Environ.GetEnumerator() | Sort-Object 'Name' | ForEach-Object {
        $Sorted[$_.Name] = $_.Value
    }
    return $Sorted
}

function Get-EnvVar {
    <#.SYNOPSIS
    Get value of environment variable.#>
    param([Parameter(Mandatory, ValueFromPipeline)][string]$Name)
    process {
        $Var = Get-Item $Name -ErrorAction 'Ignore'
        if (!$Var) { return }
        return $Var | Select-Object -ExpandProperty 'Value'
    }
}

function Set-Case {
    <#.SYNOPSIS
    Set case of a string to upper or lower.#>
    param(
        [Parameter(Mandatory, ValueFromPipeline)][string]$Name,
        [switch]$Upper,
        [switch]$Lower
    )
    process {
        if ($Upper) { return $Name.ToUpper() }
        elseif ($Lower) { return $Name.ToLower() }
        return $Name
    }
}

#* MARK: Invoke Just
Invoke-Just
