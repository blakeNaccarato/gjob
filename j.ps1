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
    param([Parameter(Mandatory, ValueFromPipeline)][hashtable]$Env)
    process {
        $Env.GetEnumerator() | ForEach-Object {
            Set-Item "Env:$($_.Name)" ($_.Value ? $_.Value : $null)
        }
    }
}
function Merge-Envs {
    <#.SYNOPSIS
    Merge environment variables.#>
    param([Parameter(Mandatory, ValueFromPipeline)][string[]]$Envs)
    process {
        $Merged = [ordered]@{}
        @( $Envs | ForEach-Object { (Get-Env $_).GetEnumerator() } ) | Sort-Object 'Name' |
            ForEach-Object { $Merged[$_.Name] = $_.Value }
        return $Merged
    }
}
function Get-Env {
    <#.SYNOPSIS
    Get environment variables.#>
    param([Parameter(Mandatory, ValueFromPipeline)][string]$Name)
    process {
        $Envs = (Get-Content 'env.json' | ConvertFrom-Json)
        if (($Path = $Envs.$Name) -is [string]) {
            if ($Path.EndsWith('.json')) { $RawEnv = Get-Content $Path | ConvertFrom-Json }
            elseif ($Path.EndsWith('.yaml') -or $Path.EndsWith('.yml')) {
                $RawEnv = Get-Content $Path | ConvertFrom-Yaml
            }
            else { throw "Could not parse environment '$Name' at '$Path'" }
        }
        else { $RawEnv = $Envs.$Name.PsObject.Properties }
        $DevEnv = [ordered]@{}
        $RawEnv.GetEnumerator() | Sort-Object 'Name' | ForEach-Object {
            $Name = (($_.Name -match '^_.+$') ? "template$($_.Name)" : $_.Name).ToUpper()
            if ( $_.Value -match '^Env:.+$' ) {
                if ( $EnvValue = Get-Item $_.Value -ErrorAction 'Ignore' ) {
                    $DevEnv[$Name] = $EnvValue
                }
            }
            else { $DevEnv[$Name] = $_.Value }
        }
        return $DevEnv
    }
}

#! Environments
$BaseEnvOnly = Get-Env 'base'
$BaseEnvs = ('answers', 'base')

#! Sync basic environment variables and bootstrap uv
Sync-Env $BaseEnvOnly | Out-Null
$Uvx = $Env:CI ? 'uvx' : './uvx'
$Just = @('--from', "rust-just@$Env:JUST_VERSION", 'just')
$Install = $RemainingArgs -and ($RemainingArgs[0] -eq 'inst')
if ($Env:CI) {
    & $Uvx @Just --justfile 'scripts/inst.just' 'powershell-yaml'
    if (!$Install) {
        $CiEnv = Merge-Envs ($BaseEnvs + 'ci')
        Sync-Env $CiEnv | Out-Null
    }
}
else {
    if (!$Install) {
        $ContribEnv = Merge-Envs ($BaseEnvs + 'contrib')
        Sync-Env $ContribEnv | Out-Null
    }
    Sync-Uv
}

#! Invoke Just if arguments were passed. Can dot-source (e.g. in recipes) with no args
if ($RemainingArgs) { & $Uvx @Just @RemainingArgs }
