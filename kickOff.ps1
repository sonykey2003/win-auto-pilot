#############################################################################
# Starts the provisioning job
#############################################################################

Set-ExecutionPolicy RemoteSigned -Force

# Kicking off
$logfilename = "provisioning"

# Import the module
$moduleUrl = "https://raw.githubusercontent.com/sonykey2003/win-auto-pilot/master/main.psm1"
$script = [scriptblock]::Create((Invoke-RestMethod -Method get -Uri $moduleUrl))
New-Module -Name wap.main -ScriptBlock $script | Out-Null

# Set timezone based on the geo location
$countryInfo = Get-GeoApi
set-tz -countryname $countryInfo.country_name

# Change the hostname to new and not rebooting
$newHostname = Set-Hostname

# Installing JC agent
## Getting the connet key
$getConnkey_url = "https://hook.us1.make.com/b6rlunkty6aff82mc0sy89u3wpl5xkmh" #change it to your webhook url

#retry 5 times if there is wrong inputs
$retry = 5
do {
    if ($retry -lt 5){
        Write-Host "Trying again...please input the correct info!" -ForegroundColor DarkYellow
    }
    $onboardInfo = getConnKey -url $getConnkey_url 

} while (
    ($null -ne $onboardInfo.conn_key) -and ($retry -gt 0)
)

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($onboardInfo.conn_key)
$conn_Key = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$jcConfig = "C:\Program Files\JumpCloud\Plugins\Contrib\jcagent.conf" 
 
## installation
installJCAgent -conn_key $conn_Key 
$systemKey = (ConvertFrom-Json (Get-Content $jcConfig)).systemKey
[string]$sudo = "false" #user will not be the local admin on the device by default. 
[string]$sudoWithoutPW = "false" #sudo with pw option only valid when sudo = true

# JC user & system operations
$jcSystemBindUser_url = "https://hook.us1.make.com/y85m9lxkhgrjlcco6ahzakasg3bt7cr7" #change it to your webhook url
$jcSystemAddGroup_url = "https://hook.us1.make.com/8hakbgiqck9iojz5mn5e35em6p84q1ry" #change it to your webhook url

## Do user binding
jcSystemBindUser -url $jcSystemBindUser_url `
 -systemKey $systemKey `
 -newHostname $newHostname `
 -user_id $onboardInfo.user_id `
 -sudo $sudo -sudoWithoutPW $sudoWithoutPW
sleep 10

## Add the device to a default group
$groupName = "All Windows"
jcSysAddGroup -url $jcSystemAddGroup_url -systemKey $systemKey -groupName $groupName

# Prep for reboot
$Banner = @"
 

________  ___       ___               ________  ________  ________   _______   ___       
|\   __  \|\  \     |\  \             |\   ___ \|\   __  \|\   ___  \|\  ___ \ |\  \      
\ \  \|\  \ \  \    \ \  \            \ \  \_|\ \ \  \|\  \ \  \\ \  \ \   __/|\ \  \     
 \ \   __  \ \  \    \ \  \            \ \  \ \\ \ \  \\\  \ \  \\ \  \ \  \_|/_\ \  \    
  \ \  \ \  \ \  \____\ \  \____        \ \  \_\\ \ \  \\\  \ \  \\ \  \ \  \_|\ \ \__\   
   \ \__\ \__\ \_______\ \_______\       \ \_______\ \_______\ \__\\ \__\ \_______\|__|   
    \|__|\|__|\|_______|\|_______|        \|_______|\|_______|\|__| \|__|\|_______|   ___ 
                                                                                     |\__\
                                                                                     \|__|
                                                                                          
                                                                       

"@
Write-Host $Banner -ForegroundColor Green

sleep 10

Restart-Computer -force

