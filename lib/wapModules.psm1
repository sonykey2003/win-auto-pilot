#Super basic functions & class
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

function Get-Apps {
    param(
        [Parameter(Mandatory = $true)]
        #[String[]]
        $env,
        [Parameter(Mandatory = $false)]
        #[String[]]
        $type,
        [Parameter(Mandatory = $false)]
        #[array[]]
        $name
    )

    switch ($env) {
        "prod" {
            $token = ""
            $url = "https://apim.workato.com/listapp-prod"
        }
        Default {
            $token = ""
            $url = "https://apim.workato.com/listapp-dev" 
        }
    }
    #pre set variables
    $applist = @()
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 #enforce TLS1.2
    $ContentType = "application/json"
    if ($null -eq $type) { 
        $Params = @{
            "names" = $name
        }
    }
    elseif (($null -eq $name) -and ($null -ne $type)) {
        $Params = @{
            "type" = $type
        }
    }
    $header = @{
        'API-TOKEN' = $token
    }
    try {
        $apps = Invoke-RestMethod -Method GET -Uri $url -Header $header -ContentType $ContentType -Body $Params 
        Write-LogEntry -Value "building app list" -filename $logfilename
    }
    catch [System.Exception] {
        Write-LogEntry -Value "failed building app list $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    }

    #creatting ps object based on Class App
    foreach ($app in $apps.apps) {
        $applist += [App]::new(
            $app.name,
            $app.url,
            $app.exp,
            $app.StatVeri
        )
    }

    Write-LogEntry -Value '======================Finishing listApps================================' -filename $logfilename
    return $applist
}

function Write-LogEntry {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Value added to the RemovedApps.log file.")]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [parameter(Mandatory = $true, HelpMessage = "Name of the log file that the entry will written to.")]
        [ValidateNotNullOrEmpty()]
        [string]$FileName,

        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$infotype = "info"
    )
    # Determine log file location
    $LogFilePath = [environment]::GetEnvironmentVariable("temp", "machine") + '\' + $FileName + '.log'

    #Add timestamps for each log entry
    $timestamp = (Get-Date).ToUniversalTime().Tostring("yyyy-MM-dd HH:mm:ss:ms")
    $logentry = $timestamp + '  ' + $infotype + ': ' + $Value
    # Add value to log file
    try {
        Out-File -InputObject $logentry -Append -NoClobber -Encoding Default -FilePath $LogFilePath -ErrorAction Stop
    }
    catch [System.Exception] {
        Write-Warning -Message "Unable to append log entry to $filename.log file"
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
function Install-App {
    # Passing the array of apps to install
    foreach ($app in $AppList) {
        #download the package from S3 repo
        $dlstatus = $app.download()

        if ($dlstatus) {
            
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
            else {
                $param = $app.exp
            }
            
            #kick-off installation loop
            $timeout = 0
            if (!$app.StatusVerify()) {
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
        else {
            Write-Host "check your network connection download $($app.name) failed" -ForegroundColor Red
            Write-LogEntry -Value "download $($app.name) failed" -filename $logfilename -infotype "Error"
        }
         
    }
}

#Call Workato API to trigger app deployment
function Invoke-Workato($env) {
    switch ($env) {
        { $prod -contains $_ } {
            $token = ""
            $url = "https://www.workato.com/service/deploy_base_apps"
        }
        Default {
            $token = ""
            $url = "https://www.workato.com/service/dev/deploy_base_apps" 
        }
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 #enforce TLS1.2
    $ContentType = "application/json"
    $Params = @{
        "hostname" = $env:COMPUTERNAME
    } | ConvertTo-Json
    try {
        Invoke-RestMethod  -Method Post -Uri $url -Header @{ 'API-TOKEN' = $token } -ContentType $ContentType -Body $Params
        Write-LogEntry -Value "Called app deployment" -filename $logfilename
    }
    catch [System.Exception] {
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

#Remove-WinBloat.psm1
#Credit to:
#  https://github.com/SCConfigMgr/ConfigMgr/blob/master/Operating%20System%20Deployment/Invoke-RemoveBuiltinApps.ps1
# White list of Features On Demand V2 packages
$WhiteListOnDemand = "NetFX3|Tools.Graphics.DirectX|Tools.DeveloperMode.Core|Language|ContactSupport|OneCoreUAP|Media.WindowsMediaPlayer|Hello.Face"

# White list of appx packages to keep installed
$WhiteListedApps = New-Object -TypeName System.Collections.ArrayList
$WhiteListedApps.AddRange(@(
        "Microsoft.DesktopAppInstaller",
        "Microsoft.MSPaint",
        "Microsoft.Windows.Photos",
        "Microsoft.StorePurchaseApp",
        "Microsoft.MicrosoftStickyNotes",
        "Microsoft.WindowsAlarms",
        "Microsoft.WindowsCalculator", 
        "Microsoft.WindowsSoundRecorder"
    ))

# Windows 10 version 1809
$WhiteListedApps.AddRange(@(
        "Microsoft.ScreenSketch",
        "Microsoft.HEIFImageExtension",
        "Microsoft.VP9VideoExtensions",
        "Microsoft.WebMediaExtensions",
        "Microsoft.WebpImageExtension"
    ))

# Windows 10 version 1903
# No new apps


# Functions
function Test-RegistryValue {
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    # If item property value exists return True, else catch the failure and return False
    try {
        if ($PSBoundParameters["Name"]) {
            $Existence = Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Name -ErrorAction Stop
        }
        else {
            $Existence = Get-ItemProperty -Path $Path -ErrorAction Stop
        }
        
        if ($Existence -ne $null) {
            return $true
        }
    }
    catch [System.Exception] {
        return $false
    }
}    

function Set-RegistryValue {
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("DWORD", "String")]
        [string]$Type
    )
    try {
        $RegistryValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($RegistryValue -ne $null) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -ErrorAction Stop
        }
        else {
            New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force -ErrorAction Stop | Out-Null
        }
    }
    catch [System.Exception] {
        Write-Warning -Message "Failed to create or update registry value '$($Name)' in '$($Path)'. Error message: $($_.Exception.Message)" -infotype "Error"
    }
}

function Remove-Bloatware {   
    # Initial logging
    Write-LogEntry -Value "===Starting built-in AppxPackage, AppxProvisioningPackage and Feature on Demand V2 removal process===" -filename $logfilename

    # Disable automatic store updates and disable InstallService
    try {
        # Disable auto-download of store apps
        Write-LogEntry -Value "Adding registry value to disable automatic store updates" -filename $logfilename
        $RegistryWindowsStorePath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"
        if (-not(Test-Path -Path $RegistryWindowsStorePath)) {
            New-Item -Path $RegistryWindowsStorePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        Set-RegistryValue -Path $RegistryWindowsStorePath -Name "AutoDownload" -Value "2" -Type "DWORD" -ErrorAction Stop

        # Disable the InstallService service
        Write-LogEntry -Value "Attempting to stop the InstallService service for automatic store updates" -filename $logfilename
        Stop-Service -Name "InstallService" -Force -ErrorAction Stop
        Write-LogEntry -Value "Attempting to set the InstallService startup behavior to Disabled" -filename $logfilename
        Set-Service -Name "InstallService" -StartupType "Disabled" -ErrorAction Stop
    }
    catch [System.Exception] {
        Write-LogEntry -Value "Failed to disable automatic store updates: $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    }

    # Determine provisioned apps
    $AppArrayList = Get-AppxProvisionedPackage -Online | Select-Object -ExpandProperty DisplayName

    # Loop through the list of appx packages
    foreach ($App in $AppArrayList) {
        Write-LogEntry -Value "Processing appx package: $($App)" -filename $logfilename

        # If application name not in appx package white list, remove AppxPackage and AppxProvisioningPackage
        if (($App -in $WhiteListedApps)) {
            Write-LogEntry -Value "Skipping excluded application package: $($App)" -filename $logfilename
        }
        else {
            # Gather package names
            $AppPackageFullName = Get-AppxPackage -Name $App | Select-Object -ExpandProperty PackageFullName -First 1
            $AppProvisioningPackageName = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $App } | Select-Object -ExpandProperty PackageName -First 1

            # Attempt to remove AppxPackage
            if ($AppPackageFullName -ne $null) {
                try {
                    Write-LogEntry -Value "Removing AppxPackage: $($AppPackageFullName)" -filename $logfilename
                    Remove-AppxPackage -Package $AppPackageFullName -ErrorAction Stop | Out-Null
                }
                catch [System.Exception] {
                    Write-LogEntry -Value "Removing AppxPackage '$($AppPackageFullName)' failed: $($_.Exception.Message)" -filename $logfilename -infotype "Error"
                }
            }
            else {
                Write-LogEntry -Value "Unable to locate AppxPackage: $($AppPackageFullName)" -filename $logfilename
            }

            # Attempt to remove AppxProvisioningPackage
            if ($AppProvisioningPackageName -ne $null) {
                try {
                    Write-LogEntry -Value "Removing AppxProvisioningPackage: $($AppProvisioningPackageName)" -filename $logfilename
                    Remove-AppxProvisionedPackage -PackageName $AppProvisioningPackageName -Online -ErrorAction Stop | Out-Null
                }
                catch [System.Exception] {
                    Write-LogEntry -Value "Removing AppxProvisioningPackage '$($AppProvisioningPackageName)' failed: $($_.Exception.Message)" -filename $logfilename -infotype "Error"
                }
            }
            else { 
                Write-LogEntry -Value "Unable to locate AppxProvisioningPackage: $($AppProvisioningPackageName)" -filename $logfilename
            }
        }
    }

    # Enable store automatic updates
    try {
        $RegistryWindowsStorePath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"
        if (Test-RegistryValue -Path $RegistryWindowsStorePath -Name "AutoDownload") {
            Write-LogEntry -Value "Attempting to remove automatic store update registry values" -filename $logfilename
            Remove-ItemProperty -Path $RegistryWindowsStorePath -Name "AutoDownload" -Force -ErrorAction Stop
        }
        Write-LogEntry -Value "Attempting to set the InstallService startup behavior to Manual" -filename $logfilename
        Set-Service -Name "InstallService" -StartupType "Manual" -ErrorAction Stop
    }
    catch [System.Exception] {
        Write-LogEntry -Value "Failed to enable automatic store updates: $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    }

    Write-LogEntry -Value "Starting Features on Demand V2 removal process" -filename $logfilename

    # Get Features On Demand that should be removed
    try {
        $OSBuildNumber = Get-WmiObject -Class "Win32_OperatingSystem" | Select-Object -ExpandProperty BuildNumber

        # Handle cmdlet limitations for older OS builds
        if ($OSBuildNumber -le "16299") {
            $OnDemandFeatures = Get-WindowsCapability -Online -ErrorAction Stop | Where-Object { $_.Name -notmatch $WhiteListOnDemand -and $_.State -like "Installed" } | Select-Object -ExpandProperty Name
        }
        else {
            $OnDemandFeatures = Get-WindowsCapability -Online -LimitAccess -ErrorAction Stop | Where-Object { $_.Name -notmatch $WhiteListOnDemand -and $_.State -like "Installed" } | Select-Object -ExpandProperty Name
        }

        foreach ($Feature in $OnDemandFeatures) {
            try {
                Write-LogEntry -Value "Removing Feature on Demand V2 package: $($Feature)" -filename $logfilename

                # Handle cmdlet limitations for older OS builds
                if ($OSBuildNumber -le "16299") {
                    Get-WindowsCapability -Online -ErrorAction Stop | Where-Object { $_.Name -like $Feature } | Remove-WindowsCapability -Online -ErrorAction Stop | Out-Null
                }
                else {
                    Get-WindowsCapability -Online -LimitAccess -ErrorAction Stop | Where-Object { $_.Name -like $Feature } | Remove-WindowsCapability -Online -ErrorAction Stop | Out-Null
                }
            }
            catch [System.Exception] {
                Write-LogEntry -Value "Removing Feature on Demand V2 package failed: $($_.Exception.Message)" -filename $logfilename -infotype "Error"
            }
        }    
    }
    catch [System.Exception] {
        Write-LogEntry -Value "Attempting to list Feature on Demand V2 packages failed: $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    }

    # Complete 
    Write-LogEntry -Value "===Completed built-in AppxPackage, AppxProvisioningPackage and Feature on Demand V2 removal process===" -filename $logfilename
}

function Remove-Onedrive () {
    try {
        Write-LogEntry -Value '======================Start purging OneDrive================================' -filename $logfilename
        Get-Process onedrive -ErrorAction SilentlyContinue | Stop-Process -Force -Confirm:$false
        Write-LogEntry -Value "Stopping onedrive process" -filename $logfilename

        Write-LogEntry -Value "Killing explorer.exe" -filename $logfilename
        taskkill.exe /F /IM "explorer.exe" | Out-Null

        $64bitpath = "$env:SystemRoot\syswow64\OneDriveSetup.exe"
        $32bitpath = "$env:SystemRoot\System32\OneDriveSetup.exe"
        $param = ' /uninstall /quiet'
        if (Test-Path $64bitpath) {
            Invoke-Expression ($64bitpath + $param)
        }
        else {
            Invoke-Expression ($32bitpath + $param) 
        }

        #removing leftovers
        Write-LogEntry -Value "Removing remaining of OneDrive" -filename $logfilename

        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:localappdata\Microsoft\OneDrive" | Out-Null
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:programdata\Microsoft OneDrive" | Out-Null
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:systemdrive\OneDriveTemp" | Out-Null
        mkdir -force "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\OneDrive" | Out-Null
        Set-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1 | Out-Null


        Write-LogEntry -Value "Remove Onedrive from explorer sidebar" -filename $logfilename
        New-PSDrive -PSProvider "Registry" -Root "HKEY_CLASSES_ROOT" -Name "HKCR" | Out-Null
        mkdir -Force "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" | Out-Null
        Set-ItemProperty "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" "System.IsPinnedToNameSpaceTree" 0 | Out-Null
        mkdir -Force "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" | Out-Null
        Set-ItemProperty "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" "System.IsPinnedToNameSpaceTree" 0 | Out-Null
        Remove-PSDrive "HKCR" | Out-Null

        Write-LogEntry -Value "Removing run hook for new users" -filename $logfilename
        reg load "hku\Default" "C:\Users\Default\NTUSER.DAT" | Out-Null
        reg delete "HKEY_USERS\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f | Out-Null
        reg unload "hku\Default" | Out-Null

        Write-LogEntry -Value "Removing startmenu entry" -filename $logfilename
        Remove-Item -Force -ErrorAction SilentlyContinue "$env:userprofile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk" | Out-Null

        Write-LogEntry -Value "Removing scheduled task" -filename $logfilename
        Get-ScheduledTask -TaskPath '\' -TaskName 'OneDrive*' -ea SilentlyContinue | Unregister-ScheduledTask -Confirm:$false | Out-Null

        Write-LogEntry -Value "Restarting explorer"  -filename $logfilename
        explorer.exe

        Write-LogEntry -Value "Waiting for explorer to complete loading" -filename $logfilename
        Start-Sleep 10
        Write-LogEntry -Value '======================End purging OneDrive================================'  -filename $logfilename

    }
    catch [System.Exception] {
        Write-LogEntry -Value "Removing OneDrive failed: $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    }
}

#Get-Preped.psm1 mostly for stg1
#Defining the list of Country codes
$countrylist = "", "SG", "MY", "ID", "VN", "PH", "CN", "TH", "US", "MM", "IN", "KH", "KR", "TW"
$msg = "Select your country code:"
$dept = "", "Normal Grabber", "CE", "BPO", "Kudo"
$msgDept = "Select the usage of this machine:"
# This Function Returns the Selected Value and Closes the Form
function Get-DropDown {
    if ($DropDown.SelectedItem -eq $null) {
        $DropDown.SelectedItem = $DropDown.Items[0]
        $script:Choice = $DropDown.SelectedItem.ToString()
        $Form.Close()
    }
    else {
        $script:Choice = $DropDown.SelectedItem.ToString()
        $Form.Close()
    }
}

function Select-Group {
    param([array]$list, [string]$msg)
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

    $Form = New-Object System.Windows.Forms.Form
    $Form.width = 300
    $Form.height = 150
    $Form.Text = "DropDown"

    $DropDown = new-object System.Windows.Forms.ComboBox
    $DropDown.Location = new-object System.Drawing.Size(100, 10)
    $DropDown.Size = new-object System.Drawing.Size(130, 30)

    foreach ($Item in $list) {
        [void] $DropDown.Items.Add($Item)
    }

    $Form.Controls.Add($DropDown)

    $DropDownLabel = new-object System.Windows.Forms.Label
    $DropDownLabel.Location = new-object System.Drawing.Size(10, 10) 
    $DropDownLabel.size = new-object System.Drawing.Size(100, 40) 
    $DropDownLabel.Text = $msg
    $Form.Controls.Add($DropDownLabel)

    $Button = new-object System.Windows.Forms.Button
    $Button.Location = new-object System.Drawing.Size(100, 50)
    $Button.Size = new-object System.Drawing.Size(100, 20)
    $Button.Text = "Select an Item"
    $Button.Add_Click( { Get-DropDown })
    $form.Controls.Add($Button)
    $form.ControlBox = $false

    $Form.Add_Shown( { $Form.Activate() })
    [void] $Form.ShowDialog()

    return $script:choice
}

function Get-GeoApi {    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 #enforce TLS1.2
    $GeoApis = @()
    $cc = @()
    $returncc = $null
    $GeoApis += "https://api.myip.com"
    $GeoApis += "https://ipapi.co/json"

    foreach ($option in $GeoApis) {
        try {
            $cc += Invoke-RestMethod -Method Get -Uri $option -ErrorAction SilentlyContinue
            Write-LogEntry -Value "Getting country code from $option API" -filename $logfilename
        }
        catch [System.Exception] {
            Write-LogEntry -Value "$option APi is not avalaible due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    
        }

        #building output country code based on API return
        if ($cc.cc -ne $null) {
            $returncc = $cc.cc
            Write-LogEntry -Value "Country code aquired from $option" -filename $logfilename
            break
        }
        elseif ($cc.country -ne $null) {
            $returncc = $cc.country
            Write-LogEntry -Value "Country code aquired from $option" -filename $logfilename
            break
        }
        
    }

    #or manual input if none of the APIs are avalaible
    if ($returncc -eq $null) {
        do {
            $returncc = Select-Group -list $countrylist -msg $msg
            Write-LogEntry -Value "Both APIs are down, prompt for manual selection" -filename $logfilename
        }while ($returncc -like "")
    }

    return $returncc 
}

function Get-GrabTimeZone {
    param($cc)
    Write-LogEntry -Value "Getting timezone based on country code" -filename $logfilename

    try {
        switch ($cc) {
            'SG' { $tz = 'Malay Peninsula Standard Time' }
            'MY' { $tz = 'Malay Peninsula Standard Time' }
            'ID' { $tz = 'SE Asia Standard Time' }
            'VN' { $tz = 'SE Asia Standard Time' }
            'PH' { $tz = 'Malay Peninsula Standard Time' }
            'CN' { $tz = 'China Standard Time' } 
            'TH' { $tz = 'SE Asia Standard Time' }
            'US' { $tz = 'Mountain Standard Time' }
            'MM' { $tz = 'Myanmar Standard Time' }
            'IN' { $tz = 'India Standard Time' }
            'KH' { $tz = 'SE Asia Standard Time' }
            'KR' { $tz = 'Korea Standard Time' }
            'TW' { $tz = 'Taipei Standard Time' }
        }
        return $tz
        Write-LogEntry -Value "Timezone aquired based on country code" -filename $logfilename
        
    }
    catch [System.Exception] {
        Write-LogEntry -Value "Timezone failed to aquire due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }
    
}

function Get-GeoInfo {
    Write-LogEntry -Value "Building Geo mapping" -filename $logfilename
    try {
        $cc = Get-GeoApi -erroraction silentlycontinue
        $geoinfo = { } | select cc, tz
        $geoinfo.cc = $cc
        $geoinfo.tz = Get-GrabTimeZone -cc $geoinfo.cc -erroraction silentlycontinue
        
        return $geoinfo
        Write-LogEntry -Value "Geo mapping aquired" -filename $logfilename
    }
    catch [System.Exception] {
        Write-LogEntry -Value "Geo mapping failed to aquire due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }
}

function Get-SN {
    Write-LogEntry -Value "Getting SN" -filename $logfilename
    try {
        $Man = (Get-WmiObject  -class Win32_Computersystem ).Manufacturer
        switch -Wildcard ($man) {
            "Dell*" { $SN = (get-ciminstance win32_bios).serialnumber.toUpper() }
            Default { $SN = "NONSTD" }
        }   
        return $SN
        Write-LogEntry -Value "SN aquired" -filename $logfilename
    }
    catch [System.Exception] {
        Write-LogEntry -Value "Getting SN failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }
}

function Get-MachineType {
    Write-LogEntry -Value "Getting machine type" -filename $logfilename
    try {
        $type = (Get-WmiObject -Class Win32_ComputerSystem -Property PCSystemType).PCSystemType
        switch ($type) {
            "2" { $suffix = '-L' }
            Default { $suffix = '-D' }
        }
        return $suffix
        Write-LogEntry -Value "Machine type aquired" -filename $logfilename

    }
    catch [System.Exception] {
        Write-LogEntry -Value "Getting machine type failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }
   
}

function Get-MachineDept {
    Write-LogEntry -Value "Prompt for manual selection of machine usage" -filename $logfilename
    $usage = Select-Group -list $dept -msg $msgDept
    while ($usage -like "") {
        $usage = Select-Group -list $dept -msg $msgDept
        Write-LogEntry -Value "Prompt for manual selection of machine usage - waiting input" -filename $logfilename
    }
    switch ($usage) {
        "Normal Grabber" { $output = "" }
        "Kudo" { $output = "KD" }
        "CE" { $output = "CE" }
        "BPO" { $output = "BPO" }            
    }
    return $output
    Write-LogEntry -Value "Machine usage aquried" -filename $logfilename
    
}

#Set timezone
function Set-GrabTimeZone {
    Write-LogEntry -Value "Setting timezone" -filename $logfilename
    try {
        $tz = (Get-GeoInfo).tz
        set-timezone -name $tz -erroraction silentlycontinue
        Write-Host setting timezone to $tz
        Write-LogEntry -Value "Timezone set" -filename $logfilename
    }
    catch [System.Exception] {
        Write-LogEntry -Value "Set timezone failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    }
   
}

#switching to Enterprise edition if not
function Set-WinEdition { 
    Write-LogEntry -Value "Setting Windows version to Enerprise" -filename $logfilename

    try {

        $win10Ver = (Get-WindowsEdition -online).edition
        if ($win10Ver -ne "Enterprise") {
            Write-Host current edition is $win10Ver, upgrading to Enterprise
            $win10key = ""
            $timeout = 0
            do {
                changepk.exe /ProductKey $win10key
                $timeout += 1
                Write-LogEntry -Value "Setting Windows version to Enerprise - Retrying $timeout" -filename $logfilename
                sleep 5
            }
            until(((Get-WindowsEdition -online).edition -eq "Enterprise") -or ($timeout -gt 20))  
            if ($timeout -gt 20) {
                Write-Host "Edition switching failed, contact IT.Systems team!" -BackgroundColor Red -ForegroundColor White
                Write-LogEntry -Value "Edition switching failed" -filename $logfilename -infotype "Error"
            }
            Write-Host "Edition switched from $win10ver to Enterprise"
            Write-LogEntry -Value "Edition switched to enterprise" -filename $logfilename

        }
        else {
            Write-Host "Edition for $env:COMPUTERNAME is $win10ver" -ForegroundColor Green
            Write-LogEntry -Value "Edition remains enterprise" -filename $logfilename
        }
    }
    catch [System.Exception] {
    
    }
}
#Building hostname follows convention: IT><countrycode><SerialNumber><Laptop or desktop>
function Set-Hostname {
    Write-LogEntry -Value "Renaming machine" -filename $logfilename
    try {
        $CountryCode = (Get-GeoInfo).cc
        $SN = Get-SN -erroraction silentlycontinue
        $suffix = Get-MachineType -erroraction silentlycontinue
        $usage = $null
        if ($suffix -eq '-D') {
            $usage = Get-MachineDept -erroraction silentlycontinue
        }
        $NewHostName = 'IT' + $CountryCode + $usage + $SN + $suffix

        Write-LogEntry -Value "Restarting the machine for stage 2" -filename $logfilename
        rename-computer -NewName $NewHostName -Restart -force -erroraction silentlycontinue
    }
    catch [System.Exception] {
        Write-LogEntry -Value "Renaming failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }   

}

function Apply-CIS {
    try {
        [System.Net.WebClient]::new().DownloadFile('https://s3.amazonaws.com/CIS/Windows_CIS.zip','c:\windows\temp\Windows_CIS.zip')
        Expand-Archive -Path 'c:\windows\temp\Windows_CIS.zip' -DestinationPath 'c:\windows\temp' -Force
        Remove-Item -Path "C:\Windows\Temp\Windows_CIS.zip"  -Recurse -Force  -ErrorAction SilentlyContinue
        Get-ChildItem -Path "C:\Windows\Temp\Windows_CIS\*" -Include *.admx -Recurse | Copy-Item -Destination "C:\Windows\PolicyDefinitions\"
        Get-ChildItem -Path "C:\Windows\Temp\Windows_CIS\*" -Include *.adml -Recurse | Copy-Item -Destination "C:\Windows\PolicyDefinitions\en-US\"
        C:\Windows\Temp\Windows_CIS\LGPO.exe /m C:\Windows\Temp\Windows_CIS\m_registry.pol
        C:\Windows\Temp\Windows_CIS\LGPO.exe /u C:\Windows\Temp\Windows_CIS\u_registry.pol
        secedit.exe /configure /db secedit.sdb /cfg C:\Windows\Temp\Windows_CIS\secedit.inf
        Powershell.exe -File "C:\Windows\Temp\Windows_CIS\setting_class.ps1"
        Remove-Item -Path "C:\Windows\Temp\Windows_CIS\" -Recurse -Force  -ErrorAction SilentlyContinue
        gpupdate /force
    }
    catch [System.Exception] {
        Write-LogEntry -Value "CIS failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    } 
}

