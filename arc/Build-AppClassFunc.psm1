#######################################################################################
#  Version:        2.2.9
#
#  Author:         Shawn Song
#  Creation Date:  03-Oct-2019
#  Purpose: Building the class & function for baseline components installations
#  Update notes:
#   03-Oct-2019 - first iteration
#   04-Oct-2019 - adding more package scenarios
#   04-Oct-2019 - added cleanning up function
#   14-Oct-2019 - add logging & Minor fixes
#   14-Oct-2019 - Unifying logs
#   15-Oct-2019 - added log info type
#   16-Oct-2019 - minor fix
#   22-Oct-2019 - Added call workato reciepe function with env switch; Moved to library
#   22-Oct-2019 - Minor fixes
#   26-Oct-2019 - populate env variable 
#   30-Oct-2019 - de-populate env variable 
#   05-Nov-2019 - Adapting Base apps
#######################################################################################

#Defining a Class
class App {
    [string]$name
    [string]$url
    [string]$exp
    [string]$dlpath = "c:\windows\temp\$name"
    [string]$StatVeri
    App([string]$name, [string]$url, [string]$exp, [string]$StatVeri) {
        $this.name = $name
        $this.url = $url
        $this.exp = $exp
        $this.StatVeri = $StatVeri
    }
    [bool]download() {
        $dl = New-Object System.Net.WebClient
        $dl.DownloadFileAsync($this.url, $this.dlpath)
        $timeout = 0
        do {
            $timeout += 1
            sleep 5
        }
        until(($dl.IsBusy -eq $false) -or ($timeout -gt 120))
        if (($dl.IsBusy -eq $false) -and (Test-Path $this.dlpath)) {
            return $true
        }
        else {
            return $false
        }
    }
    
    [bool]StatusVerify() {
        $verification = Invoke-Expression $this.StatVeri
        if ($verification -eq $true) {
            return $true
        }
        elseif (($verification -ne $null) -and ($verification -ne $false)) {
            return $true
        }
        else {
            return $false
        }
    }
}
function Install-WinFeatures {
    param([array]$list)
    #$list = "NetFX3~~~~"
    foreach ($l in $list) {
        try {
            Add-WindowsCapability -Online -Name $l -erroraction SilentlyContinue
            Write-LogEntry -Value "windows feature $l added" -filename $logfilename
        }
        catch [System.Exception] {
            Write-LogEntry -Value "Add windows feature $l failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
        }
    }
}
#building functions for later
function Install-App($collection) {
    switch ($collection) {
        "prerq" { $AppList = $prerq }
        "gagents" { $AppList = $gagents }
        "baseapps" { $AppList = $baseApps }
        Default {$AppList = $collection}
    }
    
    foreach ($app in $AppList) {
        #download the package from S3 repo
        $dlstatus = $app.download()
        #unzip and update the download path
        if ( ($dlstatus -eq $true) -and ($app.name -match ".msi") -or ($app.name -match ".exe") ) {
            $param = $app.dlpath + $app.exp
            
        }
        elseif ($dlstatus -and $app.name -match ".zip") {
            try {
                Expand-Archive $app.dlpath -DestinationPath 'c:\windows\temp\' -ErrorAction SilentlyContinue
                Write-LogEntry -Value "unzipped $($app.name) to c:\windows\temp\" -filename $logfilename
                $param = $app.exp   
            }
            catch [System.Exception] {
                Write-LogEntry -Value "unzipping $($app.name) failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
            }            
        }
        elseif ($dlstatus -eq $false) {
            Write-Host "check your network connection download $($app.name) failed" -ForegroundColor Red
            Write-LogEntry -Value "download $($app.name) failed" -filename $logfilename -infotype "Error"
        }
        else {
            $param = $app.exp
        }

        #kick-off installation loop
        $timeout = 0
        Invoke-Expression $param -ErrorAction SilentlyContinue
        Write-LogEntry -Value "Start installing $($app.name)" -filename $logfilename
        do {
            $app.StatusVerify() | Out-Null
            $timeout += 1
            Write-host installing $app.name
            Write-LogEntry -Value "Start installing $($app.name)" -filename $logfilename
            #kick off installation cmd again after 1 min, then kick off again after 3 mins
            if (($timeout -gt 6) -and ($timeout -le 18)) {
                Invoke-Expression $param -ErrorAction SilentlyContinue
                Write-LogEntry -Value "Start installing $($app.name) 2nd time" -filename $logfilename
            }
            elseif ($timeout -gt 18) {
                Invoke-Expression $param -ErrorAction SilentlyContinue
                Write-LogEntry -Value "Start installing $($app.name) 3rd time" -filename $logfilename
            }
            sleep 10
        }
        until(($app.StatusVerify() -eq $true) -or ($timeout -gt 60))      
    }
}

#Call Workato API to trigger app deployment
function Invoke-Workato($env) {
    switch ($env) {
        {$prod -contains $_}{
            $token = ""
            $url = "https://www.workato.com/service/deploy_base_apps" #sample workato api getaway
        }
        Default {
            $token = ""
            $url = "https://www.workato.com/service/dev/deploy_base_apps" #sample workato api getaway
        }
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 #enforce TLS1.2
    $ContentType = "application/json"
    $Params = @{
        "hostname"= $env:COMPUTERNAME
    }|ConvertTo-Json
    try{
        Invoke-RestMethod  -Method Post -Uri $url -Header @{ 'API-TOKEN' = $token } -ContentType $ContentType -Body $Params
        Write-LogEntry -Value "Called app deployment" -filename $logfilename
    }
    catch [System.Exception]{
        Write-LogEntry -Value "App deployment calling failed $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    }
    Write-LogEntry -Value '======================Finishing Stg2================================' -filename $logfilename
    
}

#cleaning up function
function Remove-Leftovers () {
    try {
        Remove-Item -Path "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\startup\LogOn.bat"  -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "C:\Windows\Temp\*.*" -Exclude *.log  -Recurse -Force  -ErrorAction SilentlyContinue
        Write-LogEntry -Value "cleanning up leftovers" -filename $logfilename
    }
    catch [System.Exception] {
        write-warning $_.Exception.Message
        Write-LogEntry -Value "install $($app.name) failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }
}
