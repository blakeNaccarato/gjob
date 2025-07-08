#* Variables
ci :=\
  env('CI', false)
python_version :=\
  env('PYTHON_VERSION')

#* Derived vars
_ci :=\
  if ci!=empty { true } else { false }
_python_version :=\
  python_version

#* Variable passing
vars :=\
  if override==true { \
    quote('ci=' + ci) \
    + sp + quote('python_version=' + _python_version) \
  } else { empty }
override :=\
  if ci==env('CI', false) { empty } else { true } \
  || if python_version==env('PYTHON_VERSION') { empty } else { true } \
  || false

#* Binaries
_uv :=\
  if _ci==true { 'uv' } else { './uv' }
_uvx :=\
  if _ci==true { 'uvx' } else { './uvx' }

#* Shell preamble
pre :=\
  script_pre + ';'
script_pre :=\
  '.' + sp + _j
j :=\
  _j + if override==true { sp + vars } else { empty }
_j :=\
  './j.ps1'

#* File extensions
sh_ext :=\
  if os_family()=='windows' { '.ps1' } else { '.sh' }
bin_ext :=\
  if os_family()=='windows' { '.exe' } else { empty }
cmd_ext :=\
  if os_family()=='windows' { '.cmd' } else { empty }

#* Explicit empty string used whenever `''` is intentional.
#? Empty strings are important for Just conditionals and coalescing operators like `||`
empty :=\
  ''

#* Single space
sp :=\
  ' '

#* Double quote. Use `quote(...)` instead for single-quotes
dquote :=\
  '"'

#* Messages
_na :=\
  'not applicable for this OS.'

#* Used to represent a null result where Just would otherwise mishandle a ''
null :=\
  RED+'$null'+NORMAL

#* Certain functions return true/false
true :=\
  'true'
false :=\
  'false'
