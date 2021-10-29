#######################################################################################
#  Version:        2.1.0
#
#  Author:         Shawn Song
#  Creation Date:  07-Aug-2019
#  Purpose: General Log module
#  Update notes: 
#   07-Aug-2019 - split and independent
#   15-Oct-2019 - added log info type
#######################################################################################
function Write-LogEntry {
    param(
        [parameter(Mandatory=$true, HelpMessage="Value added to the RemovedApps.log file.")]
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