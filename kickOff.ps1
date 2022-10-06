#############################################################################
# Starts the provisioning job
#############################################################################

Set-ExecutionPolicy RemoteSigned -Force

#start kicking off
$logfilename = "provisioning"

#import the module
$moduleUrl = "https://raw.githubusercontent.com/sonykey2003/win-auto-pilot/main.psm1"
$script = [scriptblock]::Create((Invoke-RestMethod -Method get -Uri $moduleUrl))
New-Module -Name wap.main -ScriptBlock $script

#set timezone based on the geo location
$countryInfo = Get-GeoApi
set-tz -countryname $countryInfo.country_name

## https://support.jumpcloud.com/support/s/article/naming-convention-for-users1#convention

#change the hostname to new and not rebooting
$newHostname = Set-Hostname

#installing JC agent
$getConnkey_url = "https://hook.us1.make.com/b6rlunkty6aff82mc0sy89u3wpl5xkmh"  
$onboardInfo = getConnKey -url $getConnkey_url
$conn_Key = $onboardInfo.conn_key
$agentCheckUp = 3
$jcConfig = "C:\Program Files\JumpCloud\Plugins\Contrib\jcagent.conf"

installJCAgent -conn_key $conn_Key
$systemKey = (ConvertFrom-Json (Get-Content $jcConfig)).systemKey
[boolean]$sudo = $false #user will not be the local admin on the device by default. 

$jcSystemBindUser_url = "https://hook.us1.make.com/y85m9lxkhgrjlcco6ahzakasg3bt7cr7"
$jcSystemAddGroup_url = "https://hook.us1.make.com/8hakbgiqck9iojz5mn5e35em6p84q1ry"

#do user binding
jcSystemOps -url $jcSystemBindUser_url
sleep 10

#add the device to a default group
jcSystemOps -url $jcSystemAddGroup_url

Write-Host "Done!" -ForegroundColor Green

