#!powershell

# Copyright: (c) 2022, Jordan Borean
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options             = @{
        name     = @{ type = 'str'; required = $true }
        state    = @{ type = 'str'; choices = 'absent', 'present'; default = 'present' }
        enforced = @{ type = 'bool' }
        enabled  = @{ type = 'bool' }
        target   = @{ type = 'str' }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$state = $module.Params.state
$enforced = $module.Params.enforced
$enabled = $module.Params.enabled
$target = $module.Params.target

if (-not $target) {
    $target = (Get-ADRootDSE).defaultNamingContext
}

$link = (Get-GPInheritance -Target $target).GpoLinks | Where-Object { $_.DisplayName -eq $name }
if ($state -eq "present") {
    if (-not $link) {
        $link = New-GPLink -Name $name -Target $target -WhatIf:$module.CheckMode
        $module.Result.changed = $true
    }

    if ($null -ne $enabled -and $link.Enabled -ne $enabled) {
        $enabledValue = if ($enabled) { "Yes" } else { "No" }
        $link = $link | Set-GPLink -LinkEnabled $enabledValue -WhatIf:$module.CheckMode
        $module.Result.changed = $true
    }
    if ($null -ne $enforced -and $link.Enforced -ne $enforced) {
        $enforcedValue = if ($enforced) { "Yes" } else { "No" }
        $link = $link | Set-GPLink -Enforced $enforcedValue -WhatIf:$module.CheckMode
        $module.Result.changed = $true
    }
}
else {
    if ($link) {
        $link | Remove-GPLink -WhatIf:$module.CheckMode
        $module.Result.changed = $true
    }
}

$module.ExitJson()