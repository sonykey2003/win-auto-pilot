#############################################################################
# Starts the provisioning job
#############################################################################

Set-ExecutionPolicy RemoteSigned -Force

#start kicking off
$logfilename = "provisioning"

#import the module
$moduleUrl = "https://raw.githubusercontent.com/sonykey2003/win-auto-pilot/master/main.psm1"
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

jcSystemBindUser -url $jcSystemBindUser_url -systemKey $systemKey -newHostname $newHostname -user_id $onboardInfo.user_id
sleep 10

#add the device to a default group
$groupName = "All Windows"
jcSysAddGroup -url $jcSystemAddGroup_url -systemKey $systemKey -groupName $groupName

Write-Host "Done!" -ForegroundColor Green

