#* Settings
set unstable
set working-directory :=\
  '..'

#* Imports
import 'common.just'

#* Modules
#? 🏠 Local
mod local '../data/local.just'

#* Shells
set shell :=\
  ['pwsh', '-NonInteractive', '-NoProfile', '-CommandWithArgs']
set script-interpreter :=\
  ['pwsh', '-NonInteractive', '-NoProfile']

# ✨ Project preamble
[script]
preamble:
  New-Item 'data/local.just' -ErrorAction 'Ignore' | Out-Null
