#######################################################################################
#  Version:        2.0.0
#
#  Author:         Shawn Song
#  Creation Date:  05-Nov-2019
#  Purpose: Base apps installation orchestrator V2
#  Update notes:
#   05-Nov-2019 - first iteration
#   26-Dec-2019 - new framework for baseapp
#######################################################################################
#install BaseApps
Set-ExecutionPolicy RemoteSigned -force
$logfilename = "BaseApp"
$url = ''
$module = 'wapModules.psm1'
$path = 'c:\windows\temp\'
[System.Net.WebClient]::new().DownloadFile($url+$module,$path+'wapModules.ps1')
. $path'wapModules.ps1'
$applist = Get-Apps -env prod -type baseapp
Install-App
Remove-Item -Path "C:\Windows\Temp\*.*" -Exclude *.log  -Recurse -Force  -ErrorAction SilentlyContinue
Set-ExecutionPolicy Restricted -force