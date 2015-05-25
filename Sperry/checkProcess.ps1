#Requires -Version 3.0 -Modules PSLogger
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
        : History - 2015 Mar 20 Moved Citrix knownPaths and related PNAgent.exe controll to StartXenApp.ps1, and incorporated both checkProcess.ps1 and StartXenApp.ps1 into the recently crafted Sperry Module for PowerShell 
	
        .LINK
        https://URL

        .Outputs
        Calls Write-Log.ps1 to write a progress log to the file system, as specified in the setup block of the script
#>

$myName = $MyInvocation.MyCommand.Name; # Contains only filename.ext leaf; for full path and filename, use $PSCommandPath
[bool]$prompt  = $false;

# Setup necessary configs for PSLogger's Write-Log cmdlet
[cmdletbinding()]
$loggingPreference='Continue';

# =======================================
# Start with empty process arguments / parameters 
$CPargs   = '';
# Define hash/associative array of known paths for executable files
# IMPORTANT: key needs to match executable name for STOP and Wait modes to work
# NOTE: start arguments are added later so that the same key can be used for starting and stopping processes
[hashtable]$knownPaths = @{
    almon		= "$env:ProgramFiles\Sophos\AutoUpdate\ALMon.exe";
    bttray		= "$env:ProgramFiles\WIDCOMM\Bluetooth Software\BTTray.exe";
    cdfsvc		= "$env:CommonProgramFiles(x86)\Citrix\System32\CdfSvc.exe";
    chrome		= "$env:SystemDrive\SWTOOLS\PortableApps\GoogleChromePortable\App\Chrome-bin\chrome.exe";
    communicator = "$env:ProgramFiles\Microsoft Office Communicator\communicator.exe";
    concentr    = "${env:ProgramFiles(x86)}\Citrix\ICA Client\concentr.exe";
    dropbox 	= "$env:APPDATA\Dropbox\bin\Dropbox.exe";
    evernote    = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Evernote\Evernote.lnk";
    Firefox     = "$env:SystemDrive\SWTOOLS\\PortableApps\FirefoxPortable\FirefoxPortable.exe";
    iexplore    = "$env:ProgramFiles\Internet Explorer\iexplore.exe";
    katmouse    = "$env:ProgramFiles\KatMouse\KatMouse.exe";
    LastPass	= "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\LastPass For Applications.lnk";
    mobilepass  = "$env:SystemDrive\SWTOOLS\MobilePass\MobilePass.exe";
    msosync		= "$env:ProgramFiles\Microsoft Office\Office14\MSOSYNC.exe";
    NitroPDFReader = "${env:ProgramFiles(x86)}\Nitro\Reader 3\NitroPDFReader.exe";
    nsepa		= "$env:ProgramFiles\Citrix\Secure Access Client\nsepa.exe";
    onenote		= "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft OneNote 2010.lnk";
    onexcengine = "$env:ProgramFiles\Avaya\Avaya one-X Communicator\onexcengine.exe";
    onexcui		= "$env:ProgramFiles\Avaya\Avaya one-X Communicator\onexcui.exe";
    outlook		= "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft Outlook 2010.lnk";
    pnagent		= "${env:ProgramFiles(x86)}\Citrix\ICA Client\pnagent.exe";
    pnamain		= "${env:ProgramFiles(x86)}\Citrix\ICA Client\pnamain.exe";
    procexp		= "$env:SystemDrive\SWTOOLS\SysinternalsSuite\procexp64.exe";
    puretext	= "$env:SystemDrive\SWTOOLS\Utilities\PureText.exe";
    radeobj		= "${env:ProgramFiles(x86)}\Citrix\Streaming Client\RadeObj.exe";
    receiver    = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Citrix\Receiver.lnk"; 
    redirector  = "${env:ProgramFiles(x86)}\Citrix\ICA Client\redirector.exe";
    ssonsvr		= "${env:ProgramFiles(x86)}\Citrix\ICA Client\ssonsvr.exe";
    taskmgr		= "$env:SystemDrive\SWTOOLS\SysinternalsSuite\procexp.exe";
    wfcrun32    = "${env:ProgramFiles(x86)}\Citrix\ICA Client\wfcrun32.exe";
    wfica32		= "${env:ProgramFiles(x86)}\Citrix\ICA Client\WFICA32.exe";
    xmarkssync  = "$env:ProgramFiles\Xmarks\IE Extension\xmarkssync.exe";
}

# Predefine 'prompt-list' to control which processes invoke user approval and which ones terminate silently
$askTerminate =@('receiver','outlook','iexplore','chrome','firefox');

# Functions
# =======================================
# checkProcess([Process Name], [Start|Stop])
function Set-ProcessState {
    [cmdletbinding()]
    Param (
        [parameter(Position=0)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ProcessName,

        [parameter(Position=1)]
        [ValidateSet('Start', 'Stop', 'Test')]
        [String[]]
        $Action,

        [Parameter(Position=2)]
        [ValidateNotNullOrEmpty()]
        [Alias('list', 'show', 'enumerate')]
        [switch] 
        $ListAvailable

    ) 

    if ($PSBoundParameters.ContainsKey('ListAvailable')) { 
        Write-Log -Message "`nEnumerating all available `$XenApps Keys" -Function ProcessState -Verbose;
        $knownPaths | Sort-Object -Property Name | format-table -AutoSize
    } else {
        $process = Get-Process $ProcessName -ErrorAction:SilentlyContinue;
    }
Set-PSDebug -Trace 2
    switch ($action) {
        'Start' { if (!($?)) {
                # unsuccessful getting $process aka NOT running
                if ($knownPaths.Keys -contains $ProcessName) {
                    # specify unique launch/start parameters
                    switch ($ProcessName) {
                        'receiver'		{$CPargs = '/startup';}
                        'concentr'		{$CPargs = '/startup';}
                        'evernote'		{$CPargs = '/minimized';}
                        'xmarkssync'	{$CPargs = '-q';}
                        'taskmgr'		{$CPargs = '/t'; }
                    }
                    # launch process from known path, with specified argument(s)
                    if (($CPargs | measure-object -Character).Characters -gt 1) {
                        Write-Log -Message "Starting $ProcessName < $knownPaths["$ProcessName"] > -ArgumentList $CPargs" -Function ProcessState;
                        Start-Process -FilePath $knownPaths["$ProcessName"] -ArgumentList $CPargs -WindowStyle Minimized
                    } else {
                        # no ArgumentList
                        Write-Log -Message "Starting $ProcessName < $knownPaths["$ProcessName"] >" -Function ProcessState
                        Start-Process -FilePath $knownPaths["$ProcessName"] -WindowStyle Minimized
                    }
                } else {
                    Write-Log -Message "Path to launch '$ProcessName' is undefined" -Function ProcessState  -verbose;
                }
            }	
        }
        'Stop' { if ($?) {
                # $process is running
                if ($askTerminate -contains $ProcessName) {
                    # processName is running, prompt to close
                    write-log "$ProcessName is running."
                    $confirm = Read-Host "`n # ACTION REQUIRED # `nClose $ProcessName, then type ok and click [Enter] to proceed.`n"
                    while (!($prompt )) {
                        if($confirm -ilike 'ok') { $prompt = $true }
                        else {
                            Write-Log -Message "Invalid response '$confirm'" -Function ProcessState  -verbose;
                            $confirm = Read-Host "`n # ACTION REQUIRED # `nType ok and click [Enter] once $ProcessName is terminated."
                        }
                    }
                    start-sleep 1; # wait one second to allow time for $process to stop
                    # Check if the process was stopped after we asked
                    $process = Get-Process $ProcessName -ErrorAction:SilentlyContinue
                    while ($process) {
                        # Application/process is still running, prompt to terminate
                        Write-Log -Message "$ProcessName is still running." -Function ProcessState  -verbose;
                        $response = Read-Host "Would you like to force terminate? `n[Y] Yes  [N] No  (default is 'null'):"
                        if($response -ilike 'Y') {
                            # Special handling for Citrix PNAgent
                            if (($ProcessName -eq 'receiver') -or ($ProcessName -eq 'pnamain')) {
                                # If we try to stop Citrix Receiver; we first try to terminate these related processes / services in a graceful order
                                Write-Log -Message 'Stopping Citrix Receiver (and related processes, services)' -Function ProcessState  -verbose;
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
                            # if not Citrix Special handling is needed, then we stop the process
                            $process | foreach {stop-process terminate($process).id};
                        } elseif($response -ilike 'N') {
                            # manually override termination
                            break;
                        } else {
                            Write-Log -Message "Invalid response '$response'." -Function ProcessState  - verbose;
                        }
                        # confirm process is terminated
                        $process = Get-Process $ProcessName -ErrorAction:SilentlyContinue | out-null
                    }
                } else {
                    # kill the process
                    $process | foreach {stop-process terminate($process).id};
                }
            }
        }
        'Test' {
            # default mode is a wait mode
            # Write-Warning "$myName: waiting for $ProcessName"
            # Check if $ProcessName is running
            Write-Log -Message "Checking if $ProcessName is running" -Function ProcessState
            start-sleep -Milliseconds 500;
            $process = Get-Process $ProcessName -ErrorAction:SilentlyContinue # | out-null
            while ($process) {
                # it appears to be running; let's wait for it
                $counter = 0; # we always start from zero
                $waitTime = 5 # Define how many seconds we want to wait per loop
                while ($counter -lt $waitTime) {
                    write-progress -activity "Waiting for $ProcessName" -status 'ctrl-c to break the loop' -percentcomplete ($counter/$waitTime*100)
                    Start-Sleep -Seconds 2;
                    $counter++;
                }
                Write-Log -Message "   still waiting for $ProcessName" -Function ProcessState  -verbose;
                # check again
                $process = Get-Process $ProcessName -ErrorAction:SilentlyContinue; #| out-null
            }
            write-progress -activity "Waiting for $ProcessName" -status '.' -Completed #-percentcomplete (100)
        }
        # default {}
    }
Set-PSDebug -Off
    
}

function Test-ProcessState {
    # Setup Advanced Function Parameters
    [cmdletbinding()]
    Param (
        [parameter(Position=0)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ProcessName,

        [Parameter(Position=2)]
        [ValidateNotNullOrEmpty()]
        [Alias('list', 'show', 'enumerate')]
        [switch] 
        $ListAvailable

    ) 

    if ($PSBoundParameters.ContainsKey('ListAvailable')) { 
        Write-Log -Message "`nEvaluating predefined process paths" -Function ProcessState -Verbose;
        foreach ($app in $knownPaths.Keys) {
            write-Debug -Message "$app = $($knownPaths.$app)";
            if (Test-Path -Path $knownPaths.$app -PathType Leaf) {
                Write-output -InputObject "Confirmed $app target at path $($knownPaths.$app)";
            } else {
                Write-Warning -Message "Unable to confirm $app target at path $($knownPaths.$app)";
            }
        }
        # $knownPaths | Sort-Object -Property Name | format-table -AutoSize
    } else {
        # Check if $ProcessName is running
        Write-Log -Message "Checking if $ProcessName is running" -Function ProcessState
        start-sleep -Milliseconds 500;
        $process = Get-Process $ProcessName -ErrorAction:SilentlyContinue # | out-null
        if ($process) {
            # it appears to be running
            return $true;
        } else {
            return $false;
        }
    }
}