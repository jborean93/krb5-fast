#!powershell

# Copyright: (c) 2022, Jordan Borean
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options             = @{
        gpo   = @{ type = 'str'; required = $true }
        path  = @{ type = 'str'; required = $true }
        name  = @{ type = 'str'; default = '' }
        value = @{ type = 'str' }
        type  = @{ type = 'str'; choices = 'String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord'; default = 'String' }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$gpo = $module.Params.gpo
$path = $module.Params.path
$name = $module.Params.name
$value = $module.Params.value
$type = $module.Params.type

if ($existing_value = Get-GPRegistryValue -Name $gpo -Key $path -ValueName $name -ErrorAction SilentlyContinue) {
    $before_value = $existing_value.Value
    $before_type = $existing_value.Type.ToString()
    
    # it seems like strings values returned with Get-GPRegistryValue have a null
    # terminator on the end, Set-GPRegistryValue does not require this and takes
    # the string literally so we will lop it off before comparing with our value
    if ($before_type -in @("String", "ExpandString")) {
        if ($before_value.EndsWith([char]0x0000)) {
            $before_value = $before_value.Substring(0, $before_value.Length - 1)
        }
    }
}
else {
    $before_value = $null
    $before_type = $null
}

$module.Result.before_value = $before_value
$module.Result.before_type = $before_type
if (($before_value -ne $value) -or ($before_type -ne $type)) {
    if ($type -in @('DWord', 'QWord')) {
        $value = [int]$value
    }
    Set-GPRegistryValue -Name $gpo -Key $path -ValueName $name -Value $value -Type $type -WhatIf:$module.CheckMode > $null
    $module.Result.changed = $true
}

$module.ExitJson()
