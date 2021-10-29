#######################################################################################
#  Version:        2.2.5
#
#  Author:         Shawn Song
#  Creation Date:  08-Aug-2019
#  Purpose: Windows Auto Pilot Stage 1 orchestrator
#  Update notes:
#   08-Aug-2019 - putting existing functions together
#   04-Oct-2019 - adding stg 2, and minor fixes 
#   14-Oct-2019 - Unifying logs 
#   22-Oct-2019 - Added library links
#   22-Oct-2019 - Added more logging
#   09-Dec-2019 - Added module
#   10-Dec-2019 - Adopting to combined modules
#######################################################################################

#Necessary modules
Set-ExecutionPolicy RemoteSigned -Force
$repoUrl = 'https://s3.amazonaws.com/Sysprep/Windows/WAP/dev/'
$liburl = 'https://s3.amazonaws.com/Sysprep/Windows/WAP/lib/'

$source = @(
    [pscustomobject]@{ 
        url = $liburl+'wapModules.psm1'
        name = 'wapModules.psm1'
    }
    [pscustomobject]@{ 
        url = $repoUrl+'stg2.ps1'
        name = 'stg2.ps1'
    }

)

#Fetch the modules
foreach ($s in $source){
    try {
        $path = [environment]::GetEnvironmentVariable("temp","machine") + '\' + $s.name
        [System.Net.WebClient]::new().DownloadFile($s.url, $path)
        #Write-LogEntry -Value "downloaded module $($m.fullname)" -filename $logfilename -infotype "info"
    }
    catch [System.Exception] {
        #Write-LogEntry -Value "download module $($m.fullname) failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    }
    
}

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

#Start Logging
$logfilename = "WAP"
Write-LogEntry -Value '======================Start Stg1================================' -filename $logfilename

#stage2
$user = $env:USERNAME
$BatBody = @"
@echo off

start powershell -noprofile -command "&{ start-process powershell -ArgumentList '-windowstyle normal -executionpolicy remotesigned -file C:\Windows\Temp\stg2.ps1' -verb RunAs}"

"@

#Add files in users /local and /Startup folder
New-Item -Path "C:\Users\$user\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" -Name "LogOn.bat" -ItemType "file" -Value $BatBody | Out-Null

#Doing the real work now
Remove-Bloatware
Remove-Onedrive
sleep 5
Set-TimeZone
Set-WinEdition
sleep 5
Write-LogEntry -Value '======================Finishing Stg1================================' -filename $logfilename
Set-Hostname