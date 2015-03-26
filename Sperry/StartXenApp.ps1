#Requires -Version 3.0 -Modules PSLogger

<#
.SYNOPSIS
Extension of Sperry module, to simplify invoking Citrix Receiver PNAgent.exe
.DESCRIPTION
Sets pnagent path string, assigns frequently used arguments to function parameters, including aliases to known /Qlaunch arguments
.PARAMETER Qlaunch
The /Qlaunch argument passes through to pnagent to be invoked by Citrix XenApp, and opens the specified application
.PARAMETER Reconnect
Requests that PNAgent attempt to reconnect to any existing Citrix XenApp session for the current user
.PARAMETER Terminatewait
Attempts to close all applications in the current user's Citrix XenApp session, and logoff from that session
.PARAMETER ListAvailable
Enumerates available XenApp shortcuts that can be passed to /QLaunch

.EXAMPLE
PS C:\> Start-XenApp -Qlaunch rdp
 Remote Desktop (or mstsc.exe) client, using the rdp alias, which is defined in the $XenApps hashtable
.EXAMPLE
PS C:\> Start-XenApp -open excel
Open Excel, using the -open alias for the -Qlaunch parameter
.EXAMPLE
PS C:\> Start-XenApp -ListAvailable
Enumerate available XenApp shortcuts to launch
.NOTES
    NAME        :  Start-XenApp
    VERSION     :  1.1   
    LAST UPDATED:  3/25/2015
    AUTHOR      :  Bryan Dady
#>
function Start-XenApp {
    [CmdletBinding()]
    [OutputType([int])]
    Param (
        # PNArgs specifies whether PNAgent.exe should attempt to reconnect an existing session, Qlanch a new app, or other supported behavior
        [Parameter(Mandatory=$false, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0,
                   ParameterSetName='Mode')]
        [Alias('args','XenApp','launch','start','open')]
        [String] 
        $Qlaunch,

        [Parameter(Mandatory=$false, 
                   Position=0,
                   ParameterSetName='Mode')]
        [ValidateNotNullOrEmpty()]
        [Alias('connect')]
        [switch] 
        $Reconnect,

        [Parameter(Mandatory=$false, 
                   Position=0,
                   ParameterSetName='Mode')]
        [ValidateNotNullOrEmpty()]
        [Alias('end', 'close', 'halt', 'exit', 'stop')]
        [switch] 
        $Terminatewait,

        [Parameter(Mandatory=$false, 
            Position=0,
            ParameterSetName='Mode')]
        [ValidateNotNullOrEmpty()]
        [Alias('list', 'show', 'enumerate')]
        [switch] 
        $ListAvailable

    )

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

	# Target       : pnagent.exe
	# Arguments    : /CitrixShortcut: (1) /QLaunch "GBCI02XA:Microsoft Outlook 2010"
	# Set pnagent path string, using knownPaths value defined above
    $pnagent="${env:ProgramFiles(x86)}\Citrix\ICA Client\pnagent.exe";

    if ($PSBoundParameters.ContainsKey('Qlaunch')) { 

    	if ($XenApps.Keys -contains $Qlaunch) {
		    $qlaunch = $XenApps.$Qlaunch;
		    $arguments = '/CitrixShortcut: (1)',"/QLaunch ""$qlaunch""";
	    }
	    # /Terminate Closes out PNAgent and any open sessions
	    # /terminatewait  Closes out PNAgent and any open sessions
	    # /Configurl  /param:URL  (useful if you haven't set up the client as part of the install)
	    # /displaychangeserver
	    # /displayoptions
	    # /logoff
	    # /refresh
	    # /disconnect
	    # /reconnect
	    # /reconnectwithparam
	    # /qlaunch  (syntax example pnagent.exe /Qlaunch "Farm1:Calc")

	    # As long as we have non-0 arguments, run it using Start-Process and arguments list
	    if ($arguments -ne $NULL) {
		    write-log "Start pnagent.exe $arguments" -Debug; # $pnagent
		    start-process $pnagent -ArgumentList $arguments;
	    } else {
	        write-log "Unrecognized XenApp shortcut: $XenApp`nPlease try again with one of the following:";
	        $XenApps.Keys;
	        break;
        }
    } elseif ($PSBoundParameters.ContainsKey('Reconnect')) { 
        write-log 'Start pnagent.exe /reconnect';
		start-process $pnagent -ArgumentList '/reconnect';
    } elseif ($PSBoundParameters.ContainsKey('Terminatewait')) { 
        write-log 'Start pnagent.exe /terminatewait';
		start-process $pnagent -ArgumentList '/terminatewait';
    } elseif ($PSBoundParameters.ContainsKey('ListAvailable')) { 
        write-log '`nEnumerating all available `$XenApps Keys' -Verbose;
		$XenApps | Sort-Object -Property Name | format-table -AutoSize
    }

}
