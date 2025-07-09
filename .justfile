#* Settings
set dotenv-load
set unstable

#* Imports
import 'scripts/common.just'

#* Modules
#? ✨ Project-specific
mod proj 'scripts/proj.just'
#? 🌐 Install
mod inst 'scripts/inst.just'

#* Shells
set shell :=\
  ['pwsh', '-NonInteractive', '-NoProfile', '-CommandWithArgs']
set script-interpreter :=\
  ['pwsh', '-NonInteractive', '-NoProfile']

#* Python packages
dev :=\
  uvr + sp + quote(env("PROJECT_NAME") + '-dev')
pipeline :=\
  uvr + sp + quote(env("PROJECT_NAME") + '-pipeline')

#* ♾️ Self

# 📃 [DEFAULT] List recipes
[group('♾️  Self')]
list:
  {{j}} --list
alias l := list

hello:
  Get-Item Env:

[group('♾️  Self')]
just *args:
  {{j}} {{args}}

#* ⛰️ Environments

# 🏃 Run shell commands with uv synced...
[group('⛰️ Environments')]
run *args: uv-sync
  @{{ if args==empty { quote(YELLOW+'No command given'+NORMAL) } else {empty} }}
  -{{ if args!=empty { j + ';' + sp + args } else {empty} }}
alias r := run

# 👥 Run recipes as a contributor...
[script, group('⛰️ Environments')]
con *args: uv-sync
  {{'#?'+BLUE+sp+'Source common shell config'+NORMAL}}
  {{script_pre}}
  {{'#?'+BLUE+sp+'Initialize repo and set up remote if repo is fresh'+NORMAL}}
  $DevEnvSettingsJson = ''
  $Environ = Merge-Envs -Upper {{base_envs}}
  $Environ.GetEnumerator() | ForEach-Object {
    $DevEnvSettingsJson += "`n    `"$($_.Name)`": `"$($_.Value)`","
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
  $LimitedEnviron = [ordered]@{}
  (Limit-Env -Lower $Environ $Environ['ci_variables'].Split(', ')).GetEnumerator() |
    ForEach-Object { $LimitedEnviron[$_.Name] = @{ value = $_.Value } }
  $Workflow = '.github/workflows/env.yml'
  $WorkflowData = Get-Content $Workflow | ConvertFrom-Yaml -Ordered
  Set-Content $Workflow @'
  # Environment variables
  #! Please only update by modifying `env.json` then running `./j.ps1 con` to sync
  '@
  $WorkflowData.on.workflow_call.outputs = $LimitedEnviron
  $WorkflowData | ConvertTo-Yaml | Add-Content $Workflow -NoNewline
  try { {{uvr}} pre-commit run 'trailing-whitespace' --files $Workflow | Out-Null } catch {}
  try { {{uvr}} pre-commit run 'mixed-line-ending' --all-files | Out-Null } catch {}
  $Env:DEV_ENV = 'contrib'
  Get-Env $Env:DEV_ENV | Sync-Env
  {{ if env("PRE_COMMIT", empty)=='1' { j + sp + 'con-git-submodules' } else {empty} }}
  {{ if env("VSCODE_FOLDER_OPEN_TASK_RUNNING", empty)=='1' { \
    j + sp + 'con-git-submodules' + sp + 'con-pre-commit-hooks' \
  } else {empty} }}
  {{ if args!=empty { j + sp + args } else {empty} }}
alias c := con

# 🤖 Run recipes in CI...
[script, group('⛰️ Environments')]
ci *args: uv-sync
  {{'#?'+BLUE+sp+'Source common shell config'+NORMAL}}
  {{script_pre}}
  {{'#?'+BLUE+sp+'Initialize repo and set up remote if repo is fresh'+NORMAL}}
  $Env:DEV_ENV = 'ci'
  $CiEnv = Merge-Envs ({{base_envs}} + $Env:DEV_ENV)
  Sync-Env $CiEnv
  #? Add `.venv` tools to CI path. Needed for some GitHub Actions like pyright
  if (!(Test-Path $Env:DEV_CI_PATH_FILE)) { New-Item $Env:DEV_CI_PATH_FILE | Out-Null }
  if ( !(Get-Content $Env:DEV_CI_PATH_FILE | Select-String -Pattern '.venv') ) {
    $Workdir = $PWD -replace '\\', '/'
    Add-Content $Env:DEV_CI_PATH_FILE ("$Workdir/.venv/bin", "$Workdir/.venv/scripts")
  }
  #? Write environment vars to CI environment file
  $CiEnvText = ''
  $CiEnv['CI_ENV_SET'] = '1'
  $CiEnv.GetEnumerator() | ForEach-Object { $CiEnvText += "$($_.Name)=$($_.Value)`n" }
  if (!(Test-Path $Env:DEV_CI_ENV_FILE)) { New-Item $Env:DEV_CI_ENV_FILE | Out-Null }
  if (!(Get-Content $Env:DEV_CI_ENV_FILE | Select-String -Pattern 'CI_ENV_SET')) {
      $CiEnvText | Add-Content -NoNewline $Env:DEV_CI_ENV_FILE
  }
  {{dev}} elevate-pyright-warnings $Env:DEV_PYRIGHTCONFIG_FILE
  {{ if args!=empty { j + sp + args } else {empty} }}

# 📦 Run recipes in devcontainer
[script, group('⛰️ Environments')]
@devcontainer *args:
  {{'#?'+BLUE+sp+'Source common shell config'+NORMAL}}
  {{script_pre}}
  {{'#?'+BLUE+sp+'Devcontainers need submodules explicitly marked as safe directories'+NORMAL}}
  $Repo = Get-ChildItem '/workspaces'
  $Packages = Get-ChildItem "$Repo/packages"
  $SafeDirs = @($Repo) + $Packages
  foreach ($Dir in $SafeDirs) {
    if (!($SafeDirs -contains $Dir)) { git config --global --add safe.directory $Dir }
  }
  {{ if args==empty { 'return' } else { '#?'+BLUE+sp+'Run recipe'+NORMAL } }}
  {{ if args==empty {empty} else { j + sp + args } }}
alias dc := devcontainer

base_envs :=\
 "('answers', 'base')"

#* 🟣 uv

#? uv invocations
uv_options :=\
  '--all-packages' + sp + '--python' + sp + quote(python_version)
uvr :=\
  uv + sp + 'run' + sp + uv_options
uvs :=\
  uv + sp + 'sync' + sp + uv_options

# 🟣 uv ...
[group('🟣 uv')]
uv *args:
  {{pre}} {{uv}} {{args}}

# 🏃 uv run ...
[group('🟣 uv')]
uv-run *args:
  {{pre}} {{uvr}} {{args}}
alias uvr := uv-run

# 🏃 uvx ...
[group('🟣 uv')]
uvx *args:
  {{pre}} {{uv}} {{args}}

# 🔃 uv sync ...
[group('🟣 uv')]
uv-sync *args:
  {{pre}} {{uvs}} {{args}}
alias uvs := uv-sync
alias sync := uv-sync

#* 🐍 Python

# 🐍 python ...
[group('🐍 Python')]
py *args:
  {{pre}} {{uvr}} 'python' {{args}}

# 📦 uv run --module ...
[group('🐍 Python')]
py-module module *args:
  {{pre}} {{uvr}} '--module' {{quote(module)}} {{args}}
alias pym := py-module

# 🏃 uv run python -c '...'
[group('🐍 Python')]
py-command cmd:
  {{pre}} {{uvr}} 'python' '-c' {{quote(cmd)}}
alias pyc := py-command

# 📄 uv run --script ...
[group('🐍 Python')]
py-script script *args:
  {{pre}} {{uvr}} '--script' {{quote(script)}} {{args}}
alias pys := py-script

# 📺 uv run --gui-script ...
[windows, group('🐍 Python')]
py-gui script *args:
  {{pre}} {{uvr}} '--gui-script' {{quote(script)}} {{args}}
alias pyg := py-gui
# ❌ uv run --gui-script ...
[linux, macos, group('❌ Python (N/A for this OS)')]
py-gui:
  @{{quote(GREEN+'GUI scripts'+sp+na+NORMAL)}}

#* ⚙️ Tools

# 🧪 pytest ...
[group('⚙️  Tools')]
tool-pytest *args:
  {{pre}} {{uvr}} pytest {{args}}
alias pytest := tool-pytest

# 📖 preview docs
[group('⚙️  Tools')]
tool-docs-preview:
  {{pre}} {{uvr}} sphinx-autobuild --show-traceback docs _site \
    {{ prepend( '--ignore', "'**/temp' '**/data' '**/apidocs' '**/*schema.json'" ) }}
alias docs := tool-docs-preview

# 📖 build docs
[group('⚙️  Tools')]
tool-docs-build:
  {{pre}} {{uvr}} sphinx-build -EaT 'docs' '_site'

# 🔵 pre-commit run ...
[group('⚙️  Tools')]
tool-pre-commit *args:
  {{pre}} {{uvr}} pre-commit run --verbose {{args}}
alias pre-commit := tool-pre-commit

# 🔵 pre-commit run --all-files ...
[group('⚙️  Tools')]
tool-pre-commit-all *args:
  {{j}} pre-commit --all-files {{args}}
alias pre-commit-all := tool-pre-commit-all

# ✔️  Check that the working tree is clean
[group('⚙️  Tools')]
tool-check-clean:
  {{pre}} if (git status --porcelain) { \
    throw 'Files changed when syncing contributor environment. Please commit and push changes with `./j.ps1 con`.' \
  }

# ✔️  fawltydeps ...
[group('⚙️  Tools')]
tool-fawltydeps *args:
  {{pre}} {{uvr}} fawltydeps {{args}}
alias fawltydeps := tool-fawltydeps

# ✔️  pyright
[group('⚙️  Tools')]
tool-pyright:
  {{pre}} {{uvr}} pyright
alias pyright := tool-pyright

# ✔️  ruff check ... '.'
[group('⚙️  Tools')]
tool-ruff *args:
  {{pre}} {{uvr}} ruff check {{args}} .
alias ruff := tool-ruff

#* 📦 Packaging

# 🛞  Build wheel, compile binary, and sign...
[group('📦 Packaging')]
pkg-build *args:
  {{pre}} {{uvr}} {{env("PROJECT_NAME")}} {{args}}
alias build := pkg-build

# 📜 Build changelog for new version
[group('📦 Packaging')]
pkg-build-changelog version:
  {{pre}} {{templ-sync}} --data 'env("PROJECT_VERSION")={{version}}'
  {{pre}} {{uvr}} towncrier build --yes --version '{{version}}'
  {{pre}} {{post_template_task}}
  -{{pre}} try { git stage 'changelog/*.md' } catch {}
  @{{quote(YELLOW+'Changelog draft built. Please finalize it, then run `./j.ps1 pkg-release`.'+NORMAL)}}

# ✨ Release the current version
[group('📦 Packaging')]
pkg-release:
  {{pre}} git add --all
  {{pre}} git commit -m '{{env("PROJECT_VERSION")}}'
  {{pre}} git tag --force --sign -m {{env("PROJECT_VERSION")}} {{env("PROJECT_VERSION")}}
  {{pre}} git push
alias release := pkg-release

#* 👥 Contributor environment setup

# 👥 Update Git submodules
[group('👥 Contributor environment setup')]
con-git-submodules:
  {{pre}} Get-ChildItem '.git/modules' -Filter 'config.lock' -Recurse -Depth 1 | \
      Remove-Item
  {{pre}} git submodule update --init --merge

# 👥 Install pre-commit hooks
[group('👥 Contributor environment setup')]
con-pre-commit-hooks:
  {{pre}} if ( \
    ({{quote(hooks)}} -Split {{quote(sp)}} | \
      ForEach-Object { ".git/hooks/$_" } | \
      Test-Path \
    ) -Contains $False \
  ) { \
    {{uvr}} pre-commit install --install-hooks | Out-Null; \
    {{quote(GREEN + 'Pre-commit hooks installed.' + NORMAL)}} \
  }
hooks :=\
  'pre-commit'

# 👥 Normalize line endings
[group('👥 Contributor environment setup')]
con-norm-line-endings:
  -{{pre}} try { {{uvr}} pre-commit run 'mixed-line-ending' --all-files | Out-Null } catch {}

# 👥 Run dev task...
[group('👥 Contributor environment setup')]
con-dev *args:
  {{pre}} {{dev}} {{args}}
alias dev := con-dev
alias d := con-dev

# 👥 Run pipeline stage...
[group('👥 Contributor environment setup')]
con-pipeline *args:
  {{pre}} {{pipeline}} {{args}}
alias pipeline := con-pipeline

# 👥 Update changelog...
[group('👥 Contributor environment setup')]
con-update-changelog change_type:
 {{pre}} {{dev}} add-change {{change_type}}

# 👥 Update changelog with the latest commit's message
[group('👥 Contributor environment setup')]
con-update-changelog-latest-commit:
  {{pre}} {{uvr}} towncrier create \
    "+$((Get-Date).ToUniversalTime().ToString('o').Replace(':','-')).change.md" \
    --content ( \
      "$(git log -1 --format='%s') ([$(git rev-parse --short HEAD)]" \
      + '(' \
        + 'https://github.com/{{env("PROJECT_OWNER_GITHUB_USERNAME")}}/{{env("GITHUB_REPO_NAME")}}' \
        + "/commit/$(git rev-parse HEAD))" \
      + ')' \
      + "`n" \
    )

#* 📤 CI Output

# 🏷️  Set CI output to latest release
[group('📤 CI Output')]
ci-out-latest-release:
  {{pre}} Set-Content {{env("DEV_CI_OUTPUT_FILE")}} "latest_release=$( \
    ($Latest = gh release list --limit 1 --json tagName | \
      ConvertFrom-Json | Select-Object -ExpandProperty 'tagName' \
    ) ? $Latest : '-1' \
  )"

#* 🧩 Templating

# ⬆️  Update from template
[group('🧩 Templating')]
templ-update:
  {{pre}} {{update_template}} --defaults
  {{pre}} {{post_template_task}}

# ⬆️  Update from template (prompt)
[group('🧩 Templating')]
templ-update-prompt:
  {{pre}} {{update_template}}
  {{pre}} {{post_template_task}}

# 🔃 Sync with current template
[group('🧩 Templating')]
templ-sync:
  {{pre}} {{templ-sync}}
  {{pre}} {{post_template_task}}
templ-sync :=\
  sync_template + sp + '--defaults'

# 🔃 Sync with current template (prompt)
[group('🧩 Templating')]
templ-sync-prompt:
  {{pre}} {{sync_template}}
  {{pre}} {{post_template_task}}

# ➡️  Recopy current template
[group('🧩 Templating')]
templ-recopy:
  {{pre}} {{recopy_template}} --defaults
  {{pre}} {{post_template_task}}

# ➡️  Recopy current template (prompt)
[group('🧩 Templating')]
templ-recopy-prompt:
  {{pre}} {{recopy_template}}
  {{pre}} {{post_template_task}}

update_template :=\
  copier_update + sp + latest_template
sync_template :=\
  copier_update + sp + current_template
recopy_template :=\
  copier_recopy + sp + current_template
post_template_task :=\
  'git add --all; git reset;' + sp + j + sp + 'con'
latest_template :=\
  quote('--vcs-ref=HEAD')
current_template :=\
  quote('--vcs-ref=' + env("TEMPLATE_COMMIT"))
copier_recopy :=\
  copier + sp + 'recopy'
copier_update :=\
  copier + sp + 'update'
copier :=\
  uvx + sp + quote('copier@' + env("COPIER_VERSION"))

#* 🛠️ Repository setup

# 🥾 Initialize repository
[script, group('🛠️ Repository setup')]
@repo-init:
  {{'#?'+BLUE+sp+'Source common shell config'+NORMAL}}
  {{script_pre}}
  {{'#?'+BLUE+sp+'Initialize repo and set up remote if repo is fresh'+NORMAL}}
  git init
  try { git rev-parse HEAD } catch {
    gh repo create --public --source '.'
    (Get-Content -Raw '.copier-answers.yml') -Match '(?m)^project_description:\s(.+\n(?:\s{4}.+)*)'
    if ($Matches) {
    }
    gh repo edit --description ($Matches[1] -Replace "`n", ' ' -Replace ' {4}', '')
    $Matches = $null
    gh repo edit --homepage 'https://{{env("PROJECT_OWNER_GITHUB_USERNAME")}}.github.io/{{env("GITHUB_REPO_NAME")}}/'
  }
  {{'#?'+BLUE+sp+'Set up repo and push'+NORMAL}}
  git submodule add --force --name 'typings' 'https://github.com/softboiler/python-type-stubs.git' 'typings'
  {{j}} con
  git add --all
  try { git commit --no-verify -m 'Prepare template using softboiler/copier-pipeline' }
  catch {}
  git push

#* 💻 Machine setup

# 👤 Set Git username and email
[group('💻 Machine setup')]
setup-git username email:
  {{pre}} git config --global user.name {{quote(username)}}
  {{pre}} git config --global user.email {{quote(email)}}

# 👤 Configure Git as recommended
[group('💻 Machine setup')]
setup-git-recs:
  {{pre}} git config --global fetch.prune true
  {{pre}} git config --global pull.rebase true
  {{pre}} git config --global push.autoSetupRemote true
  {{pre}} git config --global push.followTags true

# 🔑 Log in to GitHub API
[group('💻 Machine setup')]
setup-gh:
  {{pre}} gh auth login

# 🔓 Allow running local PowerShell scripts
[windows, group('💻 Machine setup')]
setup-scripts:
  {{pre}} Set-ExecutionPolicy -Scope 'CurrentUser' 'RemoteSigned'
# ❌ Allow running local PowerShell scripts
[linux, macos, group('❌ Machine setup (N/A for this OS)')]
setup-scripts:
  @{{quote(GREEN+'Allowing local PowerShell scripts to run'+sp+na+NORMAL)}}
