Set-StrictMode -Version '3.0'
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $True
$ErrorView = 'NormalView'
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.Encoding]::UTF8

$global:BaseEnvs = ('base')
$Envs = ('answers', 'base')
$global:ContribEnvs = $Envs + 'contrib'
$global:CiEnvs = $Envs + 'ci'
$global:PcEnvs = $Envs + 'pre-commit'

function Sync-Uv {
    <#.SYNOPSIS
    Sync uv version.#>
    if (Get-Command './uv' -ErrorAction 'Ignore') {
        (./uv --color never self version) -match 'uv ([\d.]+)' | Out-Null
        if ($Matches[1] -eq $Env:UV_VERSION) { return }
        $Matches = $null
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

function Get-Env {
    <#.SYNOPSIS
    Get environment variables.#>
    param([Parameter(Mandatory)][string]$Name)
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

function Merge-Envs {
    <#.SYNOPSIS
    Merge environment variables.#>
    param([Parameter(Mandatory)][string[]]$Envs)
    $Merged = [ordered]@{}
    @( $Envs | ForEach-Object { (Get-Env $_).GetEnumerator() } ) | Sort-Object 'Name' |
        ForEach-Object { $Merged[$_.Name] = $_.Value }
    return $Merged
}

function Sync-Env {
    <#.SYNOPSIS
    Sync environment variables.#>
    param([Parameter(Mandatory)][hashtable]$Env)
    $Env.GetEnumerator() | ForEach-Object {
        Set-Item "Env:$($_.Name)" ($_.Value ? $_.Value : $null)
    }
}

function Sync-ContribEnv {
    <#.SYNOPSIS
    Write environment variables to VSCode contributor environment.#>
    $DevEnvSettingsJson = ''
    $DevEnvWorkflowYaml = ''
    (Merge-Envs $Envs).GetEnumerator() | ForEach-Object {
        $DevEnvSettingsJson += "`n    `"$($_.Name)`": `"$($_.Value)`","
        $DevEnvWorkflowYaml += "`n      $($_.Name.ToLower()): { value: `"$($_.Value)`" }"
    }
    $DevEnvSettingsJson = "{$($DevEnvSettingsJson.TrimEnd(','))`n  }"
    $Settings = '.vscode/settings.json'
    $SettingsContent = Get-Content $Settings -Raw
    foreach ($Plat in ('linux', 'osx', 'windows')) {
        $Pat = "(?m)`"terminal\.integrated\.env\.$Plat`"\s*:\s*\{[^}]*\}"
        $Repl = "`"terminal.integrated.env.$Plat`": $DevEnvSettingsJson"
        $SettingsContent = $SettingsContent -replace $Pat, $Repl
    }
    Set-Content $Settings $SettingsContent -NoNewline
    $Workflow = '.github/workflows/env.yml'
    $WorkflowPat = '(?m)^\s{4}outputs:(?:\s\{\}|(?:\n^\s{6}.+$)+)'
    $WorkflowRepl = "    outputs:$DevEnvWorkflowYaml"
    $WorkflowContent = (Get-Content $Workflow -Raw) -replace $WorkflowPat, $WorkflowRepl
    Set-Content $Workflow $WorkflowContent -NoNewline
    $Env:DEV_ENV = 'contrib'
    $ContribEnv = Merge-Envs ($ContribEnvs)
    Sync-Env $ContribEnv
    return $ContribEnv
}

function Sync-CiEnv {
    <#.SYNOPSIS
    Sync CI environment path and environment variables.#>
    $Env:DEV_ENV = 'ci'
    $CiEnv = Merge-Envs $CiEnvs
    Sync-Env $CiEnv
    #? Add `.venv` tools to CI path. Needed for some GitHub Actions like pyright
    if (!(Test-Path $Env:DEV_CI_PATH_FILE)) { New-Item $Env:DEV_CI_PATH_FILE | Out-Null }
    if ( !(Get-Content $Env:DEV_CI_PATH_FILE | Select-String -Pattern '.venv') ) {
        $Workdir = $PWD -replace '\\', '/'
        Add-Content $Env:DEV_CI_PATH_FILE ("$Workdir/.venv/bin", "$Workdir/.venv/scripts")
    }
    #? Write environment variables to CI environment file
    $CiEnvText = ''
    $CiEnv['CI_ENV_SET'] = '1'
    $CiEnv.GetEnumerator() | ForEach-Object { $CiEnvText += "$($_.Name)=$($_.Value)`n" }
    if (!(Test-Path $Env:DEV_CI_ENV_FILE)) { New-Item $Env:DEV_CI_ENV_FILE | Out-Null }
    if (!(Get-Content $Env:DEV_CI_ENV_FILE | Select-String -Pattern 'CI_ENV_SET')) {
        $CiEnvText | Add-Content -NoNewline $Env:DEV_CI_ENV_FILE
    }
    return $CiEnv
}

function Sync-PcEnv {
    <#.SYNOPSIS
    Sync CI environment path and environment variables.#>
    Sync-ContribEnv | Out-Null
    $Env:DEV_ENV = 'pre-commit'
    $PcEnv = Merge-Envs $PcEnvs
    Sync-Env $PcEnv
    return $PcEnv
}
