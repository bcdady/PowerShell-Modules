<#
.SYNOPSIS
	The Sperry 'autopilot' module includes functions to automate getting into and out of work mode.

.DESCRIPTION
	Customizes the user's operating environment and launches specified applications, to operate in a workplace persona 
	
    The module includes functions such as profile-sync, Check-Process, and references to Write-Log.	

.PARAMETER Scope
    'DriveMap' mode causes Startup to run in streamlined mode to only map defined drive mappings.

    'firewall' mode causes Startup to run in streamlined mode to only start the Sophos firewall services, after checking that they're running. May prompt for elevated privileges.

    'XenApp' mode causes Startup to run in streamlined mode to only start Citrix XenApp services. May prompt for elevated privileges.

.EXAMPLE

.NOTES
    NAME      : sperry.ps1
    LANGUAGE  : Windows PowerShell
    AUTHOR    : Bryan Dady
    DATE      : 06/19/07
    COMMENT   : Launch/manage custom 'startup' programs via Windows PowerShell; based on user selection from CSI.hta
                See also complementary Shutdown.ps1
#>
#========================================
#Requires -Version 3.0 -Modules PSLogger
Set-StrictMode -Version Latest; # enforces coding rules in expressions, scripts, and script blocks based on latest available rules

[cmdletbinding()]

# Define / instantiate some basic references for later use
[bool]$proceed = $true; # Default behavior is to proceed through all options
[bool]$testMode = $false; 
$myName = $MyInvocation.MyCommand.Name;
$myPath = split-path $MyInvocation.MyCommand.Path;

$monthNames = (new-object system.globalization.datetimeformatinfo).MonthNames; # instantiate array of names of months
[string]$monthShortCode = $monthNames[((Get-Date).Month-1)]; $monthShortCode = $monthShortCode.substring(0,3); # Get the 3 letter shortname of the current month by looking up get-date results in $monthNames (zero-based) array

# setup some varibles that manage how the Write-Log Function, from the PSLogger module, behave
$loggingPreference='Continue';
$loggingPath = "$env:userprofile\Documents\WindowsPowerShell\log"
$logFileDateString = get-date -UFormat '%Y%m%d';

# Use regular expression -match to extract this script's name (no extension); makes logging more portable
$myName -match "(.*)\.\w{1,10}?$" *>$NULL; $myLogName = $Matches.1;
$loggingFilePreference="$loggingPath\$myLogName-$monthShortCode.log";

# Detect -debug mode:
# https://kevsor1.wordpress.com/2011/11/03/powershell-v2-detecting-verbose-debug-and-other-bound-parameters/
# RFE : also update other modules (esp. PSLogger) and scripts with same logging functionality
if ($PSBoundParameters.ContainsKey('Debug')) { 
     # ['Debug'].IsPresent) {
	[bool]$testMode = $true; 
    $loggingFilePreference = Join-Path -Path $loggingPath -ChildPath "$myLogName-test-$monthShortCode.log"
}

#dot source the Module's scripts
# Get-ChildItem C:\Users\BDady\Documents\WindowsPowerShell\Modules\Sperry\*.ps1 | ForEach-Object {Write-Output "dot-source $($PSItem.FullName)"; Start-Sleep -Milliseconds 500} #  . $($PSItem.FullName)}
# . $psScriptRoot\StartXenApp.ps1
<#. $psScriptRoot\checkProcess.ps1
. $psScriptRoot\ClearCookies.ps1
. $psScriptRoot\PrinterFunctions.ps1
. $psScriptRoot\ProfileSync.ps1
. $psScriptRoot\SophosFW.ps1
. $psScriptRoot\StartXenApp.ps1
#>

# Functions and Subroutines #
#========================================
# Test-AdminPerms - check if current script context is in admin level runtime
function Test-AdminPerms {
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] 'Administrator')
}

# Define Set-DriveMaps function
function Set-DriveMaps {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [alias('mode','scope')]
        [Switch]
        $AllDrives
    )
    
    Show-Progress 'Start'; # Log start timestamp

    # $AllDrives = 1 (true) means map all drives; 0 (false) means only map H: and S:
    write-log 'Mapping Network Drives'
	if (Test-AdminPerms) { write-log 'Mapping drives with a different account, may result in them NOT appearing properly in Explorer' -verbose; }

    # Define all drive letter = UNC path pairs here; we can control which-ones-to-map later
    $uncPaths = @{	
		'H' = "\\gbci02sanct3\homes$\gbci\$env:USERNAME";
		'I' = "\\gbci02sanct3\homes$\gbci\$env:USERNAME"+'2';
		'R' = '\\gbci02sanct1\apps';
		'S' = '\\gbci02sanct3\gbci\shared\it';
		'X' = '\\gbci02sanct3\GBCI\Shared';
		'V' = '\\glacierbancorp.local\SysVol\glacierbancorp.local\scripts';
	}

    if ($AllDrives) {
	# loop through all defined drive mappings
	$uncPaths.Keys | ForEach-Object {
		if (!(Test-Path ${_}:)) {
			write-log "New-PSDrive ${_}: "$uncPaths.${_};
			New-PSDrive -Persist -Name ${_} -Root $uncPaths.${_} -PSProvider FileSystem -scope Global -ErrorAction:SilentlyContinue;
        }
		Start-Sleep -m 500;
        }
    } else {
    	if (!(Test-Path H:)) {
		    write-log "New-PSDrive H: $($uncPaths.H)" -Debug;
		    New-PSDrive -Persist -Name H -Root "$($uncPaths.H)" -PSProvider FileSystem -scope Global; # -ErrorAction:SilentlyContinue;
        }

    	if (!(Test-Path S:)) {
		    write-log "New-PSDrive S: $($uncPaths.S)" -Debug;
		    New-PSDrive -Persist -Name S -Root "$($uncPaths.S)" -PSProvider FileSystem -scope Global; # -ErrorAction:SilentlyContinue;
        }
    }
    Show-Progress 'Stop'; # Log end timestamp
}

# Define Remove-DriveMaps function
function Remove-DriveMaps {
    Show-Progress 'Start'; # Log start timestamp
    write-log 'Removing mapped network drives';
	get-psdrive -PSProvider FileSystem | ForEach-Object {
		if (${_}.DisplayRoot -like '\\*') {
#			$driveData = 'Remove-psdrive ',${_}.Name,': ',${_}.DisplayRoot; #  -verbose"; # debugging
#			 $logLine =  $driveData -join ' ';
#			write-log $logLine;
			write-output "`t$(${_}.Name): $(${_}.DisplayRoot)"
#			remove-psdrive ${_};
		}
	}
    Show-Progress 'Stop'; # Log end timestamp
}



function Connect-WiFi {
    <#
        .SYNOPSIS
        Connect to a named wi-fi network
        .DESCRIPTION
        Checks that Sophos Firewall is stopped, idenfities available wireless network adapters and then connects them to a named network (SSID) using the netsh.exe wlan connect command syntax
        .EXAMPLE
        Connect-WiFi 'Starbucks'
        Attempts to connect the wireless network adapter(s) to SSID 'Starbucks

        .EXAMPLE
        Connect-wifi
        Attempts to connect the wireless network adapter to the default SSID
        The function contains a default SSID variable, for convenience
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [String[]]
        $SSID = 'Halcyon'
    )

    Show-Progress 'Start'; # Log start timestamp
    Begin {
        if (Get-SophosFW('Running')) { Set-SophosFW -ServiceAction Stop}
    }
    Process {
        $wireless_adapters = @(Get-CimInstance Win32_NetworkAdapter -Filter "PhysicalAdapter=True AND Name LIKE '%ireless%'" | Select-Object -Property Name,NetConnectionID,NetConnectionStatus)
        ForEach-Object -InputObject $wireless_adapters {
            if ($PSitem.NetConnectionStatus -ne 2){
                Invoke-Command -ScriptBlock {netsh.exe wlan connect "$SSID"} > $null
            }
        }
    }

    End {
        return $SSID, $?
    }
    Show-Progress 'Stop'; # Log end timestamp
<#
http://www.powertheshell.com/reference/wmireference/root/cimv2/Win32_NetworkAdapter/

Get-CimInstance Win32_NetworkAdapter -Filter "PhysicalAdapter=True AND Name LIKE '%Wireless%'" | Select-Object -Property Name,NetConnectionID,NetConnectionStatus | Format-List

$NetConnectionStatus_ReturnValue = 
@{
     0='Disconnected'
     1='Connecting'
     2='Connected'
     3='Disconnecting'
     4='Hardware Not Present'
     5='Hardware Disabled'
     6='Hardware Malfunction'
     7='Media Disconnected'
     8='Authenticating'
     9='Authentication Succeeded'
    10='Authentication Failed'
    11='Invalid Address'
    12='Credentials Required'
    ..='Other'
#>

}


function Start-CitrixReceiver {
    Show-Progress 'Start'; # Log start timestamp
	if (Test-AdminPerms) {
		Start-Service -Name RSCorSvc -ErrorAction:SilentlyContinue;
		Start-Service -Name RadeSvc -ErrorAction:SilentlyContinue; # Citrix Streaming Service
		Start-Service -Name RSCorSvc -ErrorAction:SilentlyContinue; # Citrix System Monitoring Agent
		# write-log "Stopping Citrix agents, and then restarting receiver 'clean'." -verbose;
		# invoke-expression -command "$PSScriptRoot\checkProcess.ps1 receiver Stop # Stop Citrix"; so it can be restarted clean
#		invoke-expression -command "$PSScriptRoot\checkProcess.ps1 receiver Start"; # re-start Citrix
#		invoke-expression -command "$PSScriptRoot\checkProcess.ps1 concentr Start"; # re-start Citrix
#		Start-Sleep -s 3;
#		invoke-expression -command "$PSScriptRoot\checkProcess.ps1 ssonsvr Start"; # Citrix single sign-on
#		invoke-expression -command "$PSScriptRoot\checkProcess.ps1 pnagent Start"; # Citrix agent
#		invoke-expression -command "$PSScriptRoot\checkProcess.ps1 nsepa Stop"; # Citrix Access Gateway EPA Server
	} else {
		write-log 'Need to elevate privileges for proper completion ... requesting admin credentials.' -verbose;
		# DEBUG : write-log "start-process powershell ""$PSCommandPath firewall"" -verb RunAs -Wait -ErrorAction:SilentlyContinue" -verbose;
		start-process powershell.exe "-noprofile $PSCommandPath Start-CitrixReceiver" -verb RunAs -Wait -ErrorAction:SilentlyContinue;
	}
	# Confirm Citrix XenApp shortcuts are available, and then launch
	if (test-path "$env:USERPROFILE\Desktop\Outlook Web Access.lnk") {
		& "$env:USERPROFILE\Desktop\Office Communicator.lnk";  Start-Sleep -s 30;
		& "$env:USERPROFILE\Desktop\IT Service Center.lnk"; Start-Sleep -s 1;
		& "$env:USERPROFILE\Desktop\RDP Client.lnk"; Start-Sleep -s 1;
		& "$env:USERPROFILE\Desktop\Microsoft OneNote 2010.lnk"; Start-Sleep -s 1;
		& "$env:USERPROFILE\Desktop\Microsoft Outlook 2010.lnk"; Start-Sleep -s 1;
		& "$env:USERPROFILE\Desktop\H Drive.lnk";
	} else {
		write-log 'Unable to locate XenApp shortcuts. Please check network connectivity to workplace resources and try again.' -verbose;
	}
    Show-Progress 'Stop'; # Log end timestamp
}

<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>


function Set-UAC {
    Show-Progress 'Start'; # Log start timestamp
    # Check current UAC level via registry
    # We want ConsentPromptBehaviorAdmin = 5
    # thanks to http://forum.sysinternals.com/display-uac-status_topic18490_page3.html
    if (((get-itemproperty -path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -name 'ConsentPromptBehaviorAdmin').ConsentPromptBehaviorAdmin) -ne 5)
    { # prompt for UAC update
	    & $env:SystemDrive\Windows\System32\UserAccountControlSettings.exe;
    }
    Start-Sleep -s 5;
    Show-Progress 'Stop'; # Log end timestamp
}

function Set-Workplace {
    param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$true,
            HelpMessage='Specify workplace zone, or context. Accepts Work or Home.')]
        [String[]]
        [alias('mode','scope')]
        [ValidateSet('Office', 'Remote')]
        $zone
    )
    Show-Progress 'Start';
    switch ($zone) {
        'Office' {
    	    Set-SophosFW -ServiceAction Start;
            Set-DriveMaps;
            Start-CitrixReceiver;
            # Sync files
	        write-log 'Running Profile-Sync' -verbose;
<#     ** replace with direct access to the function via inclusion of the ps1 file in this Sperry module
            # test path of Profile Sync script, and if/when found, run it
            $expresionPath = "$env:USERPROFILE\Documents\WindowsPowerShell\Scripts";
            if (Test-Path "$expresionPath\Profile-Sync.ps1") {
                invoke-expression -command "$expresionPath\Profile-Sync.ps1";
            }
	        write-log 'Done with Profile-Sync';
#>
            # Check default printer name, and re-set if necesarry
            if ((Get-DefaultPrinter).Name -ne 'GBCI91_IT252') {
                Set-DefaultPrinter GBCI91_IT252
            }
        }
        'Remote' {
    	    Set-SophosFW -ServiceAction Stop;
            Remove-DriveMaps;
            Clear-IECookies 'cag';
            Connect-WiFi;
            #	write-log 'Running Evernote';
            #	start-process powershell.exe "$PSScriptRoot\checkProcess.ps1 evernote Start";
        }
        Default {}
    }

    # Start other stuff; nice to haves
    invoke-expression -command "$env:SystemDrive\SWTOOLS\Start.exe"; # Start PortableApps menu

	# for SysInternals ProcExp, check if it's already running, because re-launching it, doesn't stay minimized
	if (Get-Process procexp -ErrorAction:SilentlyContinue) {
		# Write-Host " FYI: Process Explorer is already running.";
	} else {
		start-process powershell.exe "-noprofile $PSScriptRoot\checkProcess.ps1 taskmgr Start"; # -verb open -windowstyle Minimized;
	}

#	write-log 'Running puretext';
#	start-process powershell.exe "$PSScriptRoot\checkProcess.ps1 puretext Start";
#	start-process powershell.exe "$PSScriptRoot\checkProcess.ps1 chrome Start";
	
<#	# Reminders: 
	# Open all desktop PDF files
	write-log 'Opening all Desktop Documents';
	Get-ChildItem $env:USERPROFILE\Desktop\*.pdf | foreach { & $_ }
	# Open all desktop Word doc files
	Get-ChildItem $env:USERPROFILE\Desktop\*.doc* | foreach { & $_ }
#>
    Show-Progress 'Stop'; # Log end timestamp
    # write-log "Ending $PSCommandPath" # ErrorLevel: $error[0]"
}

Export-ModuleMember -function Connect-WiFi, Remove-DriveMaps, Set-DriveMaps, Set-Workplace, Start-CitrixReceiver -alias *
