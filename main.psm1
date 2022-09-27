#Local logging function
function Write-LogEntry {
    param(
        [parameter(Mandatory=$true, HelpMessage="The actual transcript to be added to the log file.")]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [parameter(Mandatory=$true, HelpMessage="Name of the log file that the entry will written to.")]
        [ValidateNotNullOrEmpty()]
        [string]$FileName,

        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$infotype = "info"
    )
    # Determine log file location
    $LogFilePath = [environment]::GetEnvironmentVariable("temp","machine") + '\' + $FileName + '.log'

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

#get geo location info and tranform to a string
function Get-GeoApi {    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 #enforce TLS1.3
    $countryInfo = ""| select country_name,country_code
    $geoApiOption1 = "https://ipapi.co/json"
    $geoApiOption2 = "https://api.myip.com"
    

    try{
        $response = Invoke-RestMethod -Method Get -Uri $geoApiOption1 -ErrorAction SilentlyContinue
        $countryInfo.country_name += $response.country_name
        $countryInfo.country_code += $response.country_code

        Write-LogEntry -Value "Getting country code from $geoApiOption1 API - $($countryInfo.country_name)" -filename $logfilename
    }
    catch [System.Exception]{
        Write-LogEntry -Value "$geoApiOption1 APi is not avalaible due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }

    #building output country code based on API return
    if ($null -eq $countryInfo ) {
        try{
            $response = Invoke-RestMethod -Method Get -Uri $geoApiOption2 -ErrorAction SilentlyContinue
            $countryInfo.country_name += $response.country
            $countryInfo.country_code += $response.cc
            Write-LogEntry -Value "Getting country code from $geoApiOption2 API - $($countryInfo.country)" -filename $logfilename
        }
        catch [System.Exception]{
            Write-LogEntry -Value "$geoApiOption2 APi is not avalaible due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
            Write-LogEntry -Value "Both APIs are down, leaving for blank for now" -filename $logfilename
        }
    }

    return $countryInfo
 
}

function Set-TZ {
    param (
        [parameter(Mandatory=$true)]
        [string]$countryName
    )
    $tz = Get-TimeZone -ListAvailable
    try {
        Set-TimeZone -id ($tz | Where-Object {$_.id -like $countryName}).id -erroraction silentlycontinue
    }
    catch {
        Write-LogEntry -Value "Set timezone failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    }
}

function Get-MachineType {
    Write-LogEntry -Value "Getting machine type" -filename $logfilename
    try {
        $type = (Get-WmiObject -Class Win32_ComputerSystem -Property PCSystemType).PCSystemType
        switch ($type) {
            "2" { $suffix = 'laptop' }
            Default { $suffix = 'desktop' }
        }
        return $suffix
        Write-LogEntry -Value "Machine type aquired - $suffix" -filename $logfilename

    }
    catch [System.Exception]{
        Write-LogEntry -Value "Getting machine type failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }
   
}

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

#set hostname prior rebooting - implement a 20 char guardrail
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

#getting serial number from the machine for renaming purpose
function Get-SN  {
    param (
        [parameter(Mandatory=$false)]
        [Int32]$snCharLimit = 10 #default character limit for SN set to 10
    )
    #$SN = (get-ciminstance win32_bios).serialnumber.toUpper().replace(' ','')
    $SN = "PARALLELS-50B04C2548824CE29BD2E0C041CB00DF"
    
    if ($SN.Length -gt $snCharLimit){
        return $sn = $sn.Substring(0,$snCharLimit)
    }
    
}