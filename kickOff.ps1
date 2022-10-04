#######
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

#change the hostname to new
Set-Hostname

#installing JC agent
$conn_Key = (getConnKey).conn_key
$agentCheckUp = 3
$jcConfig = "C:\Program Files\JumpCloud\Plugins\Contrib\jcagent.conf"

installJCAgent -conn_key $conn_Key
$systemKey = (ConvertFrom-Json (Get-Content $jcConfig)).systemKey
