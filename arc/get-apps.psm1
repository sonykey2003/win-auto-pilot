#######################################################################################
#  Version:        1.0.0
#  Author:         Shawn Song
#  Creation Date:  09-Dec-2019
#  Purpose: Simplified listing apps via workato api
#  Update notes:
#   09-Dec-2019 First iteration
#######################################################################################

#Workato API
$prod = "prd", "prod", "production"
$logfilename = "WAP"
function Get-Apps ($env,$type) {
    switch ($env) {
        {$prod -contains $_}{
            $token = ""
            $url = ""
        }
        Default {
            $token = ""
            $url = "https://apim.workato.com/listapp-dev" 
        }
    }
    #pre set variables
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 #enforce TLS1.2
    $ContentType = "application/json"
    $Params = @{
        "type"= $type
    }
    $header = @{
        'API-TOKEN' = $token
    }
    try{
        $apps = Invoke-RestMethod -Method GET -Uri $url -Header $header -ContentType $ContentType -Body $Params -Verbose
        Write-LogEntry -Value "building app list" -filename $logfilename
    }
    catch [System.Exception]{
        Write-LogEntry -Value "failed building app list $($_.Exception.Message)" -filename $logfilename -infotype "Error"
    }
    Write-LogEntry -Value '======================Finishing listApps================================' -filename $logfilename
    return $apps.apps
}