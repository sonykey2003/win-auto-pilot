#######################################################################################
#  Version:        2.2.5
#
#  Author:         Shawn Song
#  Creation Date:  03-Oct-2019
#  Purpose: Building the list of baseline components
#  Update notes:
#   03-Oct-2019 - first iteration
#   04-Oct-2019 - force check-in the dependency module
#   14-Oct-2019 - Minor fixes
#   22-Oct-2019 - Move this module to library; Added environment switches
#   22-Oct-2019 - Minor fixes
#   24-Oct-2019 - bug fixes
#   05-Nov-2019 - added base apps
#######################################################################################

#Making sure the necessary PS Class is imported
#This line must stay on top of EVERYTHING!!
using module 'C:\Windows\Temp\Build-AppClassFunc.psm1'

#terminologies for env
$prod = "prd", "prod", "production"
$nonProd = "dev", "stg", "staging", "pre-prod"

#Common Swags for verification ways
$erroraction = ' -erroraction silentlycontinue'
$S3Url = ''
##WMI
$wmi = '{Get-WmiObject -Class Win32_Product -Filter '
$query = ""
##Find the file existence
$fpath = '{Test-Path -path '
$file = ""
#Common MSI param
$msi = ' /qn /quiet /passive /norestart'

#Prerequisites
function Get-Prerq {
    $prerq = @()
    ##vs2005x86
    $vs2005x86 = 'vs2005x86.exe'
    $query = ' "name like' + " '%Visual C++ 2005 Redistributable' " + '"'
    $prerq += [App]::new(
        $vs2005x86,
        $S3Url + $vs2005x86,
        ' /Q',
        $wmi + $query + $erroraction + '}'
    )

    ##vs2005x64
    $vs2005x64 = 'vs2005x64.exe'
    $query = ' "name like' + " '%Visual C++ 2005%64%' " + '"'
    $prerq += [App]::new(
        $vs2005x64,
        $S3Url + $vs2005x64,
        ' /Q',
        $wmi + $query + $erroraction + '}'
    )

    ##vs2013x86
    $vs2013x86 = 'vs2013x86.exe'
    $query = ' "name like' + " '%Visual C++ 2013 x86%' " + '"'
    $prerq += [App]::new(
        $vs2013x86,
        $S3Url + $vs2013x86,
        ' /Q',
        $wmi + $query + $erroraction + '}' 
    )

    ##vs2013x64
    $vs2013x64 = 'vs2013x64.exe'
    $query = ' "name like' + " '%Visual C++ 2013 x64%' " + '"'
    $prerq += [App]::new(
        $vs2013x64,
        $S3Url + $vs2013x64,
        ' /Q',
        $wmi + $query + $erroraction + '}'    
    )
   
    return $prerq
}
# Agents
function Get-Gagents($env) {
    #JumpCloud Agent
    $JCConkeyDEV = ' -k '
    $JCConkeyProd = ' -k '

    #Automox Agent
    $AMConkeyProd = ' -k '

    #define provisioning environment
    switch ($env) {
        { $prod -contains $_ } { 
            $jckey = $JCConkeyProd
            $amkey = $AMConkeyProd
        }
        Default {
            $jckey = $JCConkeyDEV
            $amkey = $AMConkeyProd
        }
    }


    $gagents = @()
    ##jc agent
    $JCparam = ' /VERYSILENT /NORESTART /SUPRESSMSGBOXES /NOCLOSEAPPLICATIONS /NORESTARTAPPLICATIONS'
    $JCexp = $JCparam + $jckey
    $gagents += [App]::new(
        'JumpCloudInstaller.exe',
        'https://s3.amazonaws.com/jumpcloud-windows-agent/production/JumpCloudInstaller.exe',
        $JCexp,
        { Get-Process jumpcloud-agent -ErrorAction SilentlyContinue }
    )

    ##Meraki SM agent
    $meraki = 'MerakiPCCAgent.msi'
    $query = ' "name like' + " '%Meraki%' " + '"'
    $gagents += [app]::new(
        $meraki,
        $S3Url + $meraki,
        $msi,
        $wmi + $query + $erroraction + '}'
    )

    ##Automox
    $AM = 'AutomoxInstaller.exe'
    $AMparam = ' /VERYSILENT /NORESTART /SUPRESSMSGBOXES /NOCLOSEAPPLICATIONS /NORESTARTAPPLICATIONS; sleep 5; Start-Service amagent'
    $AMexp = $amkey + $AMparam
    $gagents += [app]::new(
        $AM,
        $S3Url + $AM,
        $AMexp,
        { Get-Process Amagent -ErrorAction SilentlyContinue }
    )

    ##AMP
    $AMP = 'Protect_FireAMPSetup.exe'
    $query = ' "name like' + " '%Meraki%' " + '"'
    $gagents += [app]::new(
        $AMP,
        $S3Url + $AMP,
        ' /S /R',
        { (Get-Service "ciscoamp*" -erroraction silentlycontinue).Status -eq "running" }
    )
    return $gagents
}

function Get-BaseApps ($list) {
    $baseApps = @()
    $returnBaseApps = @()
    #Google backup&sync
    $gsync = 'gsyncenterprise.msi'
    $query = ' "name like' + " '%Backup and Sync From Google%' " + '"'
    $baseApps += [App]::new(
        $gsync,
        $S3Url + $gsync,
        $msi,
        $wmi + $query + $erroraction + '}'    
    )

    #Google chrome
    $chrome = 'GoogleChrome.msi'
    $query = ' "name like' + " '%Google Chrome%' " + '"'
    $baseApps += [App]::new(
        $chrome,
        $S3Url + $chrome,
        $msi,
        $wmi + $query + $erroraction + '}'    
    )

    #Slack
    $Slack = 'SlackSetup.msi'
    $query = ' "name like' + " '%Slack%' " + '"'
    $baseApps += [App]::new(
        $Slack,
        $S3Url + $Slack,
        $msi,
        $wmi + $query + $erroraction + '}'    
    )

    #7zip
    $7zip = '7zip.msi'
    $query = ' "name like' + " '%7zip%' " + '"'
    $baseApps += [App]::new(
        $7zip,
        $S3Url + $7zip,
        $msi,
        $wmi + $query + $erroraction + '}'    
    )

    #WorkplaceChat
    $WorkplaceChat = 'WorkplaceChat.msi'
    $file = "WorkplaceChat.exe"
    $fpath = "C:\Program Files (x86)\WorkplaceChatInstaller\"
    $baseApps += [App]::new(
        $WorkplaceChat,
        $S3Url + $WorkplaceChat,
        $msi,
        $fpath + $file + $erroraction + '}'
    )

    #xCally
    $xCally = 'xCally.msi'
    $query = ' "name like' + " '%xCally%' " + '"'
    $baseApps += [App]::new(
        $xCally,
        $S3Url + $xCally,
        $msi,
        $wmi + $query + $erroraction + '}'    
    )
    
    #Skype
    $Skype = "SkypeSetup.exe"
    $file = "Skype.exe"
    $fpath = "C:\Program Files (x86)\Microsoft\Skype for Desktop\"
    $baseApps += [App]::new(
        $Skype,
        $S3Url + $Skype,
        ' /VERYSILENT /NORESTART /SUPPRESSMSGBOXES',
        $fpath + $file + $erroraction + '}'
    )

     #Zoom
     $Zoom = 'ZoomInstallerFull.msi'
     $query = ' "name like' + " '%Zoom%' " + '"'
     $baseApps += [App]::new(
         $Zoom,
         $S3Url + $Zoom,
         ' /quiet /qn /norestart ZSILENTSTART="true" /log install.log ZSSOHOST="" ZConfig="nogoogle=1;nofacebook=1;login_domain=xxx.com;AddFWException=1;kCmdParam_InstallOption=8" ZoomAutoUpdate="false"',
         $wmi + $query + $erroraction + '}'    
     )

    if ($null -eq $list){
        $returnBaseApps = $baseApps
    }
    else {
        foreach ($app in $list){
            $returnBaseApps += $baseApps | ? {$_.name -eq $app}
        }
    }
     
    return $returnBaseApps
}