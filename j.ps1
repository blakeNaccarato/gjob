<#.SYNOPSIS
Run recipes.#>
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments)][string[]]$RemainingArgs)

#? Source common shell config
. './scripts/pre.ps1'
#? Set environment variables and uv
if ($Env:CI) {
    $Uvx = 'uvx'
    Set-PsRepository 'PSGallery' -InstallationPolicy 'Trusted'
    Install-Module -Name 'powershell-yaml' -RequiredVersion 0.4.12
    if (!(Test-Path 'data/local.just')) { New-Item 'data/local.just' | Out-Null }
    Sync-Env (Merge-Envs $global:CiEnvs) | Out-Null
}
else {
    $Uvx = './uvx'
    Sync-Env (Merge-Envs $global:ContribEnvs) | Out-Null
    Sync-Uv
}
#? Pass arguments to Just
if ($RemainingArgs) { & $Uvx --from "rust-just@$Env:JUST_VERSION" just @RemainingArgs }
else { & $Uvx --from "rust-just@$Env:JUST_VERSION" just list }
