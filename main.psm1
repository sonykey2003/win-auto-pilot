 

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
        Set-TimeZone -id ($tz | Where-Object {$_.id -like "*$countryName*"}).id -erroraction silentlycontinue
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
            "2" { $suffix = 'lt' } #laptop
            Default { $suffix = 'dt' } #desktop
        }
        return $suffix
        Write-LogEntry -Value "Machine type aquired - $suffix" -filename $logfilename

    }
    catch [System.Exception]{
        Write-LogEntry -Value "Getting machine type failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }
   
}

#using an example combination here for demo, the output hostname can be customised 
function Set-Hostname {
    Write-LogEntry -Value "Renaming machine" -filename $logfilename
    try{
        $CountryCode = (Get-GeoApi).country_code
        $SN = Get-SN -erroraction silentlycontinue
        $suffix = Get-MachineType -erroraction silentlycontinue
        $NewHostName = $CountryCode + "-" + $SN + "-" + $suffix

        Write-LogEntry -Value "new name will be take effect after the next reboot" -filename $logfilename
        rename-computer -NewName $NewHostName -erroraction silentlycontinue
        return $NewHostName
    }
    catch [System.Exception]{
        Write-LogEntry -Value "Renaming failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }   

}

#set hostname prior rebooting - implement a 20 char guardrail
function Get-SN {
    param (
        [parameter(Mandatory=$false)]
        [Int32]$snCharLimit = 10 #default character limit for SN set to 10
    )
    Write-LogEntry -Value "Getting SN" -filename $logfilename
    try {
        $SN = (get-ciminstance win32_bios).serialnumber.toUpper().replace(' ','')   
        if ($SN.Length -gt $snCharLimit){
            return $sn = $sn.Substring(0,$snCharLimit)
        }
        else {
            return $sn
        }
    }
    catch [System.Exception]{
        Write-LogEntry -Value "Getting SN failed due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }
    
    
}

#Getting the JC device enrol connect_key via a custom API call on Make.com
function getConnKey {
    param (
        [string]$email,
        [string]$url
    )    
    
    $email = read-host "please enter your JC email, you have $retry chances left" 
    $enrollmentPin = Read-Host  "please enter your enrollmentPin, you have $retry chances left" 
    $params = @{
        "email"=$email
        "enrollmentPin" = $enrollmentPin
    }
    
    try{
        $re = Invoke-RestMethod -Uri $url -Body $params -Method Get -ErrorAction SilentlyContinue
    }
    catch [System.Exception]{
        
        Write-LogEntry -Value "$($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }
    $re.conn_key = $re.conn_key | ConvertTo-SecureString -AsPlainText -Force -ErrorAction SilentlyContinue
    
    return $re

}

function installJCAgent {
    param (
        [parameter(Mandatory=$true)]   
        [string]$conn_Key,
        [Int32]$agentCheckUp=5
    )
    if ($null -eq $conn_Key){
        Write-Host "JC agent won't be installed, please contact your IT admins!" -ForegroundColor Red
        Write-LogEntry -Value "JC agent won't be installed, unable to verify the user, exiting the provisioning! " -filename $logfilename -infotype "Error"
        break
    }
    else {
        try{ 
            do {
                #actual installation block
                $jcAgentUri = "https://raw.githubusercontent.com/TheJumpCloud/support/master/scripts/windows/InstallWindowsAgent.ps1"
                cd $env:temp |`
                Invoke-Expression; Invoke-RestMethod -Method Get -URI $jcAgentUri -OutFile InstallWindowsAgent.ps1 |`
                Invoke-Expression; ./InstallWindowsAgent.ps1 -JumpCloudConnectKey $conn_key
    
                #checking
                $jcAgentSvc = Get-Service *jumpcloud* -erroraction silentlycontinue
                Write-Host "Checking if JC agent is running..."
                $agentCheckUp -= 1
                sleep 120
                
            } until (
                ($jcAgentSvc.status -eq "Running") -and (Test-Path $jcConfig) -or $agentCheckUp -eq 0
            )       
        }
        catch [System.Exception]{
            Write-Host "JC agent can't be installed, please contact your IT admins!" -ForegroundColor Red
            Write-LogEntry -Value "JC agent won't be installed, due to $($_.Exception.Message)" -filename $logfilename -infotype "Error"
        }
       
        
    }
    
        
}

function jcSystemBindUser  {
    param (
        [string]$url,
        [string]$systemKey,
        [string]$newHostname,
        [string]$user_id,
        [string]$sudo = "false",
        [string]$sudoWithoutPW = "false"
    )

    #sudo with pw option only valid when sudo = true
    if ($sudo -ne "false") {
        $sudoWithOutPW = $false
    }

    $params = @{
        "systemKey" = $systemKey
        "newHostname" = $newHostname
        "sudo" = $sudo
        "sudoWithoutPW" = $sudoWithoutPW
        "user_id" = $user_id
    }
    
    try{
        return $re = Invoke-RestMethod -Uri $url -Method Get -body $params -ErrorAction SilentlyContinue

    }
    catch [System.Exception]{
        
        Write-LogEntry -Value "$($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }    
    
}

function jcSysAddGroup {
    param (
        [string]$url,
        [string]$systemKey,
        [string]$groupName
      
    )

    $params = @{
        "systemKey" = $systemKey
        "groupName" = $groupName
    }
    #sudo with pw option only valid when sudo = true
   

    try{
        return $re = Invoke-RestMethod -Uri $url -Method Get -Body $params -ErrorAction SilentlyContinue

    }
    catch [System.Exception]{
        
        Write-LogEntry -Value "$($_.Exception.Message)" -filename $logfilename -infotype "Error"

    }    
    
}