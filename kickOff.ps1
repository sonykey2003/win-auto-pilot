#######
Set-ExecutionPolicy RemoteSigned -Force

#start kicking off
$logfilename = "provisioning"

#import the module
$modules = Get-ChildItem -Path C:\Windows\Temp *.psm1
foreach ($m in $modules){
    try {
        Import-Module $m.FullName -ErrorAction SilentlyContinue
    }
    catch [System.Exception] {
        Write-Output $_
    }         
}
#set timezone based on the geo location
$countryInfo = Get-GeoApi
set-tz -countryname $countryInfo.country_name

## https://support.jumpcloud.com/support/s/article/naming-convention-for-users1#convention

#change the hostname to new
## sync the new hostname with jc on Hostname & displayname fields
## then reboot after everything is done