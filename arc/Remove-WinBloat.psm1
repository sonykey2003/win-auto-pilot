<#
    .SYNOPSIS
    Remove built-in apps (modern apps) from Windows 10.
    .DESCRIPTION
    This script will remove all built-in apps with a provisioning package that's not specified in the 'white-list' in this script.
    It supports MDT and ConfigMgr usage, but only for online scenarios, meaning it can't be executed during the WinPE phase.
    For a more detailed list of applications available in each version of Windows 10, refer to the documentation here:
    https://docs.microsoft.com/en-us/windows/application-management/apps-in-windows-10
    .NOTES
    Created:     2019-03-10    
#>
#######################################################################################
#  Version:        2.3.4
#
#  Author:         Shawn Song
#  Creation Date:  07-Aug-2019
#  Purpose: Dependency function for auto pilot stage 1 to set the hostname and timezone
#  Update notes:
#    1.0.0 - (2019-03-10) Initial script updated with help section and a fix for randomly freezing
#    1.1.0 - (2019-05-03) Added support for Windows 10 version 1903 (19H1)
#    1.2.0 - added timestamps for log entries
#    1.3.0 - added remove onedrive function
#    1.3.1 - functionalized remove built-in packages
#    1.3.2 - took out IE
#   14-Oct-2019 - Unifying logs
#   15-Oct-2019 - added log info type
#  Credit to:
#  https://github.com/SCConfigMgr/ConfigMgr/blob/master/Operating%20System%20Deployment/Invoke-RemoveBuiltinApps.ps1
#######################################################################################

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
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [parameter(Mandatory=$false)]
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
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [parameter(Mandatory=$true)]
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
            $OnDemandFeatures = Get-WindowsCapability -Online -ErrorAction Stop | Where-Object { $_.Name -notmatch $WhiteListOnDemand -and $_.State -like "Installed"} | Select-Object -ExpandProperty Name
        }
        else {
            $OnDemandFeatures = Get-WindowsCapability -Online -LimitAccess -ErrorAction Stop | Where-Object { $_.Name -notmatch $WhiteListOnDemand -and $_.State -like "Installed"} | Select-Object -ExpandProperty Name
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

