@echo off
goto check_Permissions
:check_Permissions
    echo Administrative permissions required. Detecting permissions...
    net session >nul 2>&1
    SET stgUrl=https://s3.amazonaws.com/Sysprep/Windows/WAP/prd/stg1.ps1
    SET stgPath=c:\windows\temp\stg1.ps1
    if %errorLevel% == 0 (
        echo Success: Administrative permissions confirmed.
        echo downloading...
        start Powershell.exe -executionpolicy remotesigned -windowstyle hidden -command "& {(New-Object System.Net.WebClient).DownloadFile('%stgurl%','%stgpath%')}"
    ) else (
            echo Failure: Current permissions inadequate. Try again and run this bat as admin.
            pause
            exit
    )

goto test_downloading
:test_downloading
    ping 127.0.0.1 -n 5 >nul
    if exist %stgPath% (
        echo Script downloaded
        echo kickoff autopiloting, buckle up
        start Powershell.exe -executionpolicy remotesigned -windowstyle normal -File  "%stgpath%" /min
        (goto) 2>nul & del "%~f0"
    ) else (
        echo Failure: Script is not downloaded, check the network connection and try again
        pause
        exit

    )