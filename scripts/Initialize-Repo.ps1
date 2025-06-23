<#.SYNOPSIS
Initialize repository.#>

#? Source common shell config
. ./scripts/pre.ps1

#? Initialize repo
git init

#? Modify GitHub repo later on only if there were not already commits in this repo
try { git rev-parse HEAD }
catch [System.Management.Automation.NativeCommandExitException] { $Fresh = $True }

git submodule add --force --name 'typings' 'https://github.com/softboiler/python-type-stubs.git' 'typings'
./j.ps1 con
git add --all
try { git commit --no-verify -m 'Prepare template using blakeNaccarato/copier-python' }
catch [System.Management.Automation.NativeCommandExitException] {}

#? Create GitHub repo and modify details if there were not already commits in this repo
if ($Fresh) {
    gh repo create --public --source '.'
    (Get-Content -Raw '.copier-answers.yml') -Match '(?m)^project_description:\s(.+\n(?:\s{4}.+)*)'
    $Description = $Matches[1] -Replace "`n", ' ' -Replace ' {4}', ''
    gh repo edit --description $Description
    gh repo edit --homepage 'https://blakeNaccarato.github.io/gjob/'
}

#? Push changes
git push
