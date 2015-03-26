<#
.SYNOPSIS
	checkProcess.ps1 is designed to simplify process management for frequently used executables / applications.
    It can be used to find and check that a process is running, including waiting / pausing while that process is still running (e.g. waiting for a setup to complete before proceeding), or stop any running process.
    If the path to a process is defined within the script's $knownPaths table, it can also be used to specifically control the arguments and startup behavior of those programs.
	
.DESCRIPTION
	checkProcess.ps1 is can be used to find and check that any process is running, including waiting / pausing while that process is still running (e.g. waiting for a setup to complete before proceeding), or stop a running process.
    If the path to a process is defined within the script's $knownPaths hash-table, it can also be used to specifically control the arguments and startup behavior of those programs.

.PARAMETER 	processName
	Name of process to check for, start up, or stop

.PARAMETER Start
    Run the script in Start mode, which includes looking up the processName parameter in the $knownPaths table, and then invoking accordingly

.PARAMETER Stop
    Run the script in Stop mode, which starts a seek and destroy mission for the specified processName on the local OS

.EXAMPLE
   checkProcess.ps1 -processName notepad -start

.Notes
    LANG	: PowerShell
    NAME	: checkProcess.ps1
    AUTHOR	: Bryan Dady
    DATE	: 11/25/09
    COMMENT	: Shared script for controlling a common set of processes for various modes
            : History - 2014 Jun 25 Added / updated Citrix knownPaths
	
.LINK
	https://URL

.Outputs
	Calls Write-Log.ps1 to write a progress log to the file system, as specified in the setup block of the script
#>
#Requires -Version 3.0 -Modules PSLogger

$myName = $MyInvocation.MyCommand.Name; # Contains only filename.ext leaf; for full path and filename, use $PSCommandPath
push-location $PSScriptRoot; # for PS2 compatibility, use & $myPath = split-path $MyInvocation.MyCommand.Path; push-location $myPath
[bool]$prompt  = $false;

# Setup necessary configs for PSLogger's Write-Log cmdlet
[cmdletbinding()]
$loggingPreference='Continue';
$loggingPath = "$env:userprofile\Documents\WindowsPowerShell\log"
$logFileDateString = get-date -UFormat '%Y%m%d';

# Use regular expression make a .log file that matches this scripts name; makes logging portable
$MyInvocation.MyCommand.Name -match "(.*)\.\w{2,3}?$" *>$NULL; $myLogName = $Matches.1;
$loggingFilePreference = Join-Path -Path $loggingPath -ChildPath "$myLogName-$logFileDateString.log"

# Detect -debug mode:
# https://kevsor1.wordpress.com/2011/11/03/powershell-v2-detecting-verbose-debug-and-other-bound-parameters/
# RFE : also update other modules (esp. PSLogger) and scripts with same logging functionality
if ($PSBoundParameters['Debug'].IsPresent) {
	[bool]$testMode = $true; 
    $loggingFilePreference = Join-Path -Path $loggingPath -ChildPath "$myLogName-test-$logFileDateString.log"
}

# =======================================
# Start with empty process arguments / parameters 
$CPargs   = '';
# Define hash/associative array of known paths for executable files
# IMPORTANT: key needs to match executable name for STOP and wait modes to work
# NOTE: start arguments are added later so that the same key can be used for starting and stopping processes
$knownPaths = @{
    almon		= "$env:ProgramFiles\Sophos\AutoUpdate\ALMon.exe";
    bttray		= "$env:ProgramFiles\WIDCOMM\Bluetooth Software\BTTray.exe";
    cdfsvc		= "$env:CommonProgramFiles(x86)\Citrix\System32\CdfSvc.exe";
    chrome		= "$env:SystemDrive:\SWTOOLS\PortableApps\GoogleChromePortable\App\Chrome-bin\chrome.exe";
    communicator = "$env:ProgramFiles\Microsoft Office Communicator\communicator.exe";
    concentr    = "${env:ProgramFiles(x86)}\Citrix\ICA Client\concentr.exe";
    dropbox 	= "$env:APPDATA\Dropbox\bin\Dropbox.exe";
    evernote    = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Evernote\Evernote.lnk";
    iexplore    = "$env:ProgramFiles\Internet Explorer\iexplore.exe";
    katmouse    = "$env:ProgramFiles\KatMouse\KatMouse.exe";
    LastPass	= "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\LastPass For Applications.lnk";
    msosync		= "$env:ProgramFiles\Microsoft Office\Office14\MSOSYNC.exe";
    NitroPDFReader = "${env:ProgramFiles(x86)}\Nitro\Reader 3\NitroPDFReader.exe";
    nsepa		= "$env:ProgramFiles\Citrix\Secure Access Client\nsepa.exe";
    onenote		= "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft OneNote 2010.lnk";
    onexcengine = "$env:ProgramFiles\Avaya\Avaya one-X Communicator\onexcengine.exe";
    onexcui		= "$env:ProgramFiles\Avaya\Avaya one-X Communicator\onexcui.exe";
    outlook		= "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft Outlook 2010.lnk";
    pnagent		= "${env:ProgramFiles(x86)}\Citrix\ICA Client\pnagent.exe";
    pnamain		= "${env:ProgramFiles(x86)}\Citrix\ICA Client\pnamain.exe";
    procexp		= "$env:SystemDrive:\SWTOOLS\SysinternalsSuite\procexp64.exe";
    puretext	= "$env:SystemDrive:\SWTOOLS\Utilities\PureText.exe";
    radeobj		= "${env:ProgramFiles(x86)}\Citrix\Streaming Client\RadeObj.exe";
    receiver    = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Citrix\Receiver.lnk"; 
    redirector  = "${env:ProgramFiles(x86)}\Citrix\ICA Client\redirector.exe";
    shmobile    = "$env:ProgramFiles\Riverbed\Steelhead Mobile\shmobile.exe";
    ssonsvr		= "${env:ProgramFiles(x86)}\Citrix\ICA Client\ssonsvr.exe";
    taskmgr		= "$env:SystemDrive:\SWTOOLS\SysinternalsSuite\procexp.exe";
    wfcrun32    = "${env:ProgramFiles(x86)}\Citrix\ICA Client\wfcrun32.exe";
    wfica32		= "${env:ProgramFiles(x86)}\Citrix\ICA Client\WFICA32.exe";
    xmarkssync  = "$env:ProgramFiles\Xmarks\IE Extension\xmarkssync.exe";
}

# Predefine 'prompt-list' to control which processes invoke user approval and which ones terminate silently
$askTerminate =@('receiver','outlook','iexplore','chrome','firefox');

# Predefine XenApp Qlaunch arguments for running Citrix [pnagent] applications
$XenApps = @{
	assyst		= 'GBCI02XA:Assyst';
	communicator = 'GBCI02XA:Office Communicator';
	ocs 		= 'GBCI02XA:Office Communicator';
	excel		= 'GBCI02XA:Microsoft Excel 2010'
	h_drive 	= 'GBCI02XA:H Drive';
	IE			= 'GBCI02XA:Internet Explorer';
	IE_11		= 'GBCI02XA:Internet Explorer 11';
	itsc		= 'GBCI02XA:IT Service Center';
	mstsc		= 'GBCI02XA:RDP Client';
	onenote 	= 'GBCI02XA:Microsoft OneNote 2010'
	outlook 	= 'GBCI02XA:Microsoft Outlook 2010';
	rdp			= 'GBCI02XA:RDP Client';
	s_drive 	= 'GBCI02XA:S Drive';
	word		= 'GBCI02XA:Microsoft Word 2010'
	visio		= 'GBCI02XA:Microsoft Visio 2013'
}

# Pre-defined procedures
# =======================================

# checkProcess([Process Name], [Start|Stop])
function Set-ProcessState {
	# Setup Advanced Function Parameters
	[cmdletbinding()]
	Param (
		[parameter(Position=0,Mandatory=$true)]
		[ValidateLength(1,100)]
		[String[]]
		$processName,
		[parameter(Position=1)]
		[ValidateSet('Start', 'Stop', 'Test')]
		[String[]]
		$mode
	  ) 
	#$PSBoundParameters
	$process = Get-Process $processName -ErrorAction:SilentlyContinue;
	switch ($mode) {
	    'Start' { if (!($?)) {
		# unsuccessful getting $process aka NOT running
		if ($knownPaths.Keys -contains $processName) {
			# specify unique launch/start parameters
			switch ($processName) {
				'receiver'		{$CPargs = '/startup';}
				'concentr'		{$CPargs = '/startup';}
				# "communicator" {$CPargs = '/fromrunkey';}
				'evernote'		{$CPargs = '/minimized';}
				'xmarkssync'	{$CPargs = '-q';}
				'taskmgr'		{ $CPargs = '/t'; }
			}
			# launch process from known path
			$param_length = ($CPargs | measure-object -Character);
			if ($param_length.Characters -gt 1) {
				write-log "Starting $processName -ArgumentList $CPargs";
				Start-Process $knownPaths.$processName -ArgumentList $CPargs;
			} else {
				# DEBUG write-host "Launching '$processName' from "$knownPaths.$processName -foregroundcolor "yellow";
				write-log "Starting $processName : $($knownPaths.$processName)" -verbose;
				Start-Process $($knownPaths.$processName);
			}
		} else {
			write-log "Path to launch '$processName' is undefined" -verbose;
		}
		}	
	}
        'Stop' { if ($?) {
		# $process is running
		if ($askTerminate -contains $processName) {
			# processName is running, prompt to close
			write-log "$processName is running."
			$confirm = Read-Host "`n # ACTION REQUIRED # `nClose $processName, then type ok and click [Enter] to proceed.`n"
		while (!($prompt )) {
			if($confirm -ilike 'ok') { $prompt = $true }
			else {
				Write-log "Invalid response '$confirm'" -verbose;
				$confirm = Read-Host "`n # ACTION REQUIRED # `nType ok and click [Enter] once $processName is terminated."
			}
		}
		start-sleep 1; # wait one second to allow time for $process to stop
		# Check if the process was stopped after we asked
		$process = Get-Process $processName -ErrorAction:SilentlyContinue
		while ($process) {
            # Application/process is still running, prompt to terminate
            Write-log "$processName is still running." -verbose;
            $response = Read-Host "Would you like to force terminate? `n[Y] Yes  [N] No  (default is 'null'):"
            if($response -ilike 'Y') {
				# Special handling for Citrix PNAgent
				if (($processName -eq 'receiver') -or ($processName -eq 'pnamain')) {
					# If we try to stop Citrix Receiver; we first try to terminate these related processes / services in a graceful order
					write-log 'Stopping Citrix Receiver (and related processes, services)' -verbose;
					start-process $knownPaths.pnagent -ArgumentList '/terminatewait' -RedirectStandardOutput .\pnagent-termwait.log -RedirectStandardError .\pnagent-twerr.log;
					start-process $knownPaths.concentr -ArgumentList '/terminate' -RedirectStandardOutput .\pnagent-term.log -RedirectStandardError .\pnagent-termerr.log;
					Stop-Service -Name cdfsvc -force; # Citrix Diagnostic Facility COM Server
					Stop-Service -Name RadeSvc -force -ErrorAction:Continue; # Citrix Streaming Client Service
					Stop-Service -Name RadeHlprSvc -force -ErrorAction:Continue; # Citrix Streaming Helper Service
					Set-ProcessState radeobj Stop # Citrix Offline Plug-in Session COM Server; child of pnamain.exe
					Set-ProcessState redirector Stop; # Citrix 
					Set-ProcessState prefpanel Stop; # Citrix 
					Set-ProcessState nsepa Stop # Citrix Access Gateway EPA Server
					Set-ProcessState concentr Stop; # Citrix 
					Set-ProcessState wfcrun32 Stop; # Citrix Connection Manager; child of ssonsvr.exe
					Set-ProcessState wfica32 Stop; # Citrix  
				#	Set-ProcessState pnamain Stop; # Citrix 
					Set-ProcessState receiver Stop; # Citrix
				}
				terminate($process)
			} elseif($response -ilike 'N') {
			# manually override termination
			break
		} else {
			Write-log "Invalid response '$response'." - verbose;
		}
		# confirm process is terminated
		$process = Get-Process $processName -ErrorAction:SilentlyContinue | out-null
		}
                } else {
                    # kill the process
                    terminate($process)
                }
            }
        }
        default {
            # default mode is a wait mode
            # Write-Warning "$myName: waiting for $processName"
            # Check if $processName is running
            write-log "Checking if $processName is running";
            start-sleep -Milliseconds 500;
            $process = Get-Process $processName -ErrorAction:SilentlyContinue # | out-null
            while ($process) {
                # it appears to be running; let's wait for it
                $counter = 0; # we always start from zero
                $waitTime = 5 # Define how many seconds we want to wait per loop
                while ($counter -lt $waitTime) {
                    write-progress -activity "Waiting for $processName" -status 'ctrl-c to break the loop' -percentcomplete ($counter/$waitTime*100)
                    Start-Sleep -Seconds 2;
                    $counter++;
                }
                write-log "   still waiting for $processName" -verbose;
                # check again
                $process = Get-Process $processName -ErrorAction:SilentlyContinue; #| out-null
            }
            write-progress -activity "Waiting for $processName" -status '.' -Completed #-percentcomplete (100)
        }
    }
}

function terminate($process) {
    # Check what we got; it could be a single process object or a collection of them
<#	if (($process.count) -gt 1) {
	 | Measure-Object | Select Count) -ne 0) {
#>
        # We found more than one running process to kill
        $process | foreach {stop-process $_.id}
<#    } else {
        # otherwise, just kill the one process
        stop-process $process.id
        Start-Sleep -s 1 # wait just a sec to make sure it's gone
    }
#>
}

