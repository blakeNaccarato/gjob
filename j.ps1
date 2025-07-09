<#.SYNOPSIS
Run Just recipes.#>
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments)][string[]]$RemainingArgs)

#! Common config sourced by all Just recipes
Set-StrictMode -Version '3.0'
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $True
$ErrorView = 'NormalView'
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.Encoding]::UTF8

#! Common functions used below and sourced by all Just recipes
function Sync-Uv {
    <#.SYNOPSIS
    Sync uv version.#>
    if (Get-Command './uv' -ErrorAction 'Ignore') {
        (./uv --color 'never' self version) -match 'uv ([\d.]+)' | Out-Null
        if ($Matches[1] -eq $Env:UV_VERSION) { return }
    }
    if (Get-Command 'uvx' -ErrorAction 'Ignore') {
        uvx --from "rust-just@$Env:JUST_VERSION" just inst uv
        return
    }
    if ($IsWindows) {
        $InstallUv = "Invoke-RestMethod https://astral.sh/uv/$Env:UV_VERSION/install.ps1 | Invoke-Expression"
        powershell -ExecutionPolicy 'ByPass' -Command $InstallUv
        return
    }
    curl -LsSf "https://astral.sh/uv/$Env:UV_VERSION/install.sh" | sh
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
    return Sort-Env $Limited
}
function Merge-Envs {
    <#.SYNOPSIS
    Merge environment variables.#>
    param([Parameter(Mandatory)][string[]]$Envs)
    $Merged = [ordered]@{}
    $Envs | Get-Env | ForEach-Object { $_.GetEnumerator() } | ForEach-Object {
        $Merged[$_.Name] = $_.Value
    }
    return Sort-Env $Merged
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
            if ($Value -match '^Env:.+$') { $Value = ($EnvVar = Get-EnvVar $Value) ? $EnvVar : '' }
            if ($Value -ne '') { $Environ[$Name] = $Value }
        }
        return Sort-Env $Environ
    }
}
function Sort-Env {
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

#! Populate supplied variables
$Vars = @{}
if ($RemainingArgs) {
    $Idx = 0
    for ($Idx = 0; $Idx -lt $RemainingArgs.Count; $Idx++) {
        if (
            ($RemainingArgs[$Idx] -eq '--set') -and
            (($Idx + 2) -lt $RemainingArgs.Count)
        ) {
            $Vars[$RemainingArgs[$Idx + 1]] = $RemainingArgs[$Idx + 2]
            $Idx += 2
            continue
        }
        else { break }
    }
    if (
        ($Idx -lt $RemainingArgs.Count) -and
        ($RemainingArgs[($Idx - 1)..($RemainingArgs.Count - 1)] -contains '--set')
    ) {
        throw "All variable setting done with `--set key val` must occur first"
    }
}

#! Sync basic environment variables and bootstrap uv
$Uvx = $Env:CI ? 'uvx' : './uvx'
Get-Env 'base' | Sync-Env
$Just = @('--from', "rust-just@$Env:JUST_VERSION", 'just')
$CI = ($Vars['ci'] ? $Vars['ci'] : $Env:CI)
if (!$Env:JUST -and (($null -ne $CI) -and ($CI -ne 0))) {
    & $Uvx @Just --justfile 'scripts/inst.just' 'powershell-yaml'
}
else { Sync-Uv }
Merge-Envs ('answers', 'base') | Sync-Env

#! Populate missing variables
$MissingVars = @()
$Env:JUST_VARIABLES.Split(', ') | ForEach-Object {
    if (($Value = $Vars[$_])) {
        Set-Item "Env:$($_.ToUpper())" $Value
    }
    else {
        $EnvVar = Get-EnvVar "Env:$($_.ToUpper())"
        $MissingVars += ('--set', $_, ($EnvVar ? $EnvVar : ''''''))
    }
}

#! Invoke Just if arguments were passed. Can dot-source (e.g. in recipes) with no args
$UvxArgs = $Just + $MissingVars + $RemainingArgs
if (($RemainingArgs) -or (!$Env:JUST)) {
    $Env:JUST = '1'
    & $Uvx $UvxArgs
}
