#######################################################################################
#  Version:        2.2.3
#
#  Author:         Shawn Song
#  Creation Date:  04-Oct-2019
#  Purpose: Windows Auto Pilot Stage 1 orchestrator
#  Update notes:
#   21-Oct-2019 - Prod release
#   22-Oct-2019 - Detached calling workato; Added env switches
#   22-Oct-2019 - Added more logging
#   30-Oct-2019 - populate env variable 
#   10-Dec-2019 - Adopting to combined modules
#   17-Dec-2019 - Minor fix
#   17-Dec-2019 - Added CE dotnet35 support
#######################################################################################
using module C:\Windows\Temp\wapModules.psm1
#set env variable
$env = "prod"
$prod = "prd","prod","production"
$nonProd = "dev","stg","staging","pre-prod"

#import the modules
$modules = Get-ChildItem -Path C:\Windows\Temp *.psm1
foreach ($m in $modules){
    try {
        Import-Module $m.FullName -ErrorAction SilentlyContinue
        #Write-LogEntry -Value "imported module $($m.fullname)" -filename $logfilename -infotype "info"
    }
    catch [System.Exception] {
        #Write-LogEntry -Value "import module $($m.fullname) failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    }         
}

#Logging
$logfilename = "WAP"
Write-LogEntry -Value '======================Start Stg2================================' -filename $logfilename

#install dotnet35 if the machine is used by CE agents
if ($env:computername -like "IT*CE*"){
    Install-WinFeatures -list "NetFX3~~~~"
    Write-LogEntry -Value "$env:computername is a CE machine, installing dotnet35" -filename $logfilename -infotype "info"
}
#prereq list installations
$applist = Get-Apps -env $env -type "prerq" 
Install-App

#install Grabagents
$applist = Get-Apps -env $env -type "gagent" 
Install-App
sleep 30

#finishing
Remove-Leftovers

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
Write-Host "handover to Workato for app deployment, hang in there!" -BackgroundColor Green
Write-LogEntry -Value "handover to Workato for app deployment, WAP done and out!" -filename $logfilename
sleep 10

#handover to workato
Invoke-Workato($env)
sleep 10 

try{
    Set-ExecutionPolicy Restricted -Force -ErrorAction SilentlyContinue
    Write-LogEntry -Value "Revert back PowerShell execution policy" -filename $logfilename -infotype "info"

}
catch [System.Exception] {
    write-warning $_.Exception.Message
    Write-LogEntry -Value "Revert back PowerShell execution policy failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    
}

