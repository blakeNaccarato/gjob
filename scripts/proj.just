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

#* ✨ gjob

# 📫 Convert MBOX to JSON
[group('✨ gjob')]
convert-mbox-to-json input output:
  Invoke-RestMethod {{remote_mbox_to_json_converter}} | \
    Set-Content {{mbox_to_json_converter}}
  {{j}} py-script {{mbox_to_json_converter}} \
    --input {{quote(input)}} --output {{quote(output)}}
mbox_to_json_converter :=\
  'data/mbox_to_json_converter.py'
remote_mbox_to_json_converter :=\
  'https://raw.githubusercontent.com/huolter/mbox2json/146f371765d2056b3a96219792f60646d3cfdc84/mbox_to_json_converter.py'
_data := \
  'data'
