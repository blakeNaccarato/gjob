#* Settings
set unstable
set working-directory :=\
  '..'

#* Imports
import 'common.just'

#* Shells
set shell :=\
  ['pwsh', '-NonInteractive', '-NoProfile', '-CommandWithArgs']
set script-interpreter :=\
  ['pwsh', '-NonInteractive', '-NoProfile']

#* Reusable shell preambles
pre :=\
  pwsh_pre + ';'
script_pre :=\
  pwsh_pre
_just :=\
  './j.ps1'

# 📃 [DEFAULT] List `gjob` recipes
[group('✨ gjob')]
list:
  {{pre}} {{_just}} --justfile {{quote('scripts/gjob.just')}} --list
