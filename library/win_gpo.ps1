#!powershell

# Copyright: (c) 2022, Jordan Borean
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options             = @{
        name    = @{ type = 'str'; required = $true }
        state   = @{ type = 'str'; choices = 'absent', 'present'; default = 'present' }
        comment = @{ type = 'str' }
        domain  = @{ type = 'str' }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$commonParams = @{
    Name = $module.Params.name
}
if ($module.Params.domain) {
    $commonParams.Domain = $module.Params.domain
}

if ($gpo = Get-GPO @commonParams -ErrorAction SilentlyContinue) {
    if ($module.Params.state -eq 'absent') {
        $gpo | Remove-GPO
        $module.Result.changed = $true
    }
}
elseif ($module.Params.state -eq 'present') {
    $newParams = @{
        WhatIf = $module.CheckMode
    }
    if ($module.Params.comment) {
        $newParams.Comment = $module.Params.comment
    }
    $null = New-GPO @commonParams @newParams
    $module.Result.changed = $true
}

$module.ExitJson()