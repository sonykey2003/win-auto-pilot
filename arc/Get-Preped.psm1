#######################################################################################
#  Version:        2.2.4
#
#  Author:         Shawn Song
#  Creation Date:  07-Aug-2019
#  Purpose: Dependency function for auto pilot stage 1 to set the hostname and timezone
#  Update notes:
#   07-Aug-2019 - putting existing functions together
#   08-Aug-2019 - added logging   
#   14-Oct-2019 - Minor fix  
#   14-Oct-2019 - Unifying logs
#   15-Oct-2019 - added log info type
#   16-Oct-2019 - revampped get-geoapi logics
#   24-Oct-2019 - fixing typo
#######################################################################################

#Defining the list of Country codes
$countrylist = "", "SG", "MY", "ID", "VN", "PH", "CN", "TH", "US", "MM", "IN", "KH", "KR", "TW"
$msg = "Select your country code:"
$dept = "", "Normal staff", "CE", "BPO", "Kudo"
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
    $Button.Add_Click({Get-DropDown})
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

    foreach ($option in $GeoApis){
        try{
            $cc += Invoke-RestMethod -Method Get -Uri $option -ErrorAction SilentlyContinue
            Write-LogEntry -Value "Getting country code from $option API" -filename $logfilename
        }
        catch [System.Exception]{
            Write-LogEntry -Value "$option APi is not avalaible due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    
        }

        #building output country code based on API return
        if ($cc.cc -ne $null) {
            $returncc =  $cc.cc
            Write-LogEntry -Value "Country code aquired from $option" -filename $logfilename
            break
        }
        elseif ($cc.country -ne $null) {
            $returncc =  $cc.country
            Write-LogEntry -Value "Country code aquired from $option" -filename $logfilename
            break
        }
        
    }

    #or manual input if none of the APIs are avalaible
    if ($returncc -eq $null){
        do{
            $returncc = Select-Group -list $countrylist -msg $msg
            Write-LogEntry -Value "Both APIs are down, prompt for manual selection" -filename $logfilename
        }while ($returncc -like "")
    }

    return $returncc 
}

function Get-TimeZone {
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
    catch [System.Exception]{
        Write-LogEntry -Value "Timezone failed to aquire due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }
    
}
function Get-GeoInfo {
    Write-LogEntry -Value "Building Geo mapping" -filename $logfilename
    try{
        $cc = Get-GeoApi -erroraction silentlycontinue
        $geoinfo = { } | select cc, tz
        $geoinfo.cc = $cc
        $geoinfo.tz = Get-TimeZone -cc $geoinfo.cc -erroraction silentlycontinue
        
        return $geoinfo
        Write-LogEntry -Value "Geo mapping aquired" -filename $logfilename
    }
    catch [System.Exception]{
        Write-LogEntry -Value "Geo mapping failed to aquire due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }
}

function Get-SN {
    Write-LogEntry -Value "Getting SN" -filename $logfilename
    try{
        $Man = (Get-WmiObject  -class Win32_Computersystem ).Manufacturer
        switch -Wildcard ($man) {
            "Dell*" { $SN = (get-ciminstance win32_bios).serialnumber.toUpper() }
            Default { $SN = "NONSTD" }
        }   
        return $SN
        Write-LogEntry -Value "SN aquired" -filename $logfilename
    }
    catch [System.Exception]{
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
    catch [System.Exception]{
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
            "Normal staff" { $output = "" }
            "Kudo" {$output = "KD"}
            "CE" {$output = "CE"}
            "BPO" {$output = "BPO"}            
        }
        return $output
        Write-LogEntry -Value "Machine usage aquried" -filename $logfilename
    
}

#Set timezone
function Set-TimeZone {
    Write-LogEntry -Value "Setting timezone" -filename $logfilename
    try {
        $tz = (Get-GeoInfo).tz
        set-timezone -name $tz -erroraction silentlycontinue
        Write-Host setting timezone to $tz
        Write-LogEntry -Value "Timezone set" -filename $logfilename
    }
    catch [System.Exception]{
        Write-LogEntry -Value "Set timezone failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    }
   
}

#switching to Enterprise edition if not
function Set-WinEdition { 
    Write-LogEntry -Value "Setting Windows version to Enerprise" -filename $logfilename

    try{

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
    catch [System.Exception]{
    
    }
}
#Building hostname follows convention: IT><countrycode><SerialNumber><Laptop or desktop>
function Set-Hostname {
    Write-LogEntry -Value "Renaming machine" -filename $logfilename
    try{
        $CountryCode = (Get-GeoInfo).cc
        $SN = Get-SN -erroraction silentlycontinue
        $suffix = Get-MachineType -erroraction silentlycontinue
        $usage = $null
        if ($suffix -eq '-D'){
            $usage = Get-MachineDept -erroraction silentlycontinue
        }
        $NewHostName = 'IT' + $CountryCode + $usage + $SN + $suffix

        Write-LogEntry -Value "Restarting the machine for stage 2" -filename $logfilename
        rename-computer -NewName $NewHostName -Restart -force -erroraction silentlycontinue
    }
    catch [System.Exception]{
        Write-LogEntry -Value "Renaming failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }   

}
