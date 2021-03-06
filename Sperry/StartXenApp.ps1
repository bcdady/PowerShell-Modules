﻿#Requires -Version 3.0 -Modules PSLogger

# Predefine XenApp Qlaunch arguments for running Citrix [pnagent] applications
# By Predefining at the script scope, we can evaluate parameters using ValidateScript against this hashtable
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

function Start-XenApp {
<#
.SYNOPSIS
    Extension of Sperry module, to simplify invoking Citrix Receiver PNAgent.exe
.DESCRIPTION
    Sets pnagent path string, assigns frequently used arguments to function parameters, including aliases to known /Qlaunch arguments
.PARAMETER Qlaunch
    The Qlaunch parameter references a shortcut name, to be referenced against the known XenApp apps to launch, and then passes to pnagent to be launched by Citrix
.PARAMETER Reconnect
    Requests that PNAgent attempt to reconnect to any existing Citrix XenApp session for the current user
.PARAMETER Terminatewait
    Attempts to close all applications in the current user's Citrix XenApp session, and logoff from that session
.PARAMETER ListAvailable
    Enumerates available XenApp shortcuts that can be passed to -QLaunch

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
    VERSION     :  1.3 
    LAST UPDATED:  4/9/2015
    AUTHOR      :  Bryan Dady
#>
    [CmdletBinding(DefaultParameterSetName='Launch')]
#    [OutputType([int])]
    Param (
        # PNArgs specifies whether PNAgent.exe should attempt to reconnect an existing session, Qlanch a new app, or other supported behavior
        [Parameter(Mandatory=$false, 
                   ValueFromPipeline=$false,
                   ValueFromPipelineByPropertyName=$false, 
                   ValueFromRemainingArguments=$false, 
                   Position=0,
                   ParameterSetName='Mode')]
        [ValidateScript({$PSItem -in $XenApps.Keys})]
        [Alias('args','XenApp','launch','start','open')]
        [String] 
        $Qlaunch = '-ListAvailable',

        [Parameter(Mandatory=$false, 
                   Position=3,
                   ParameterSetName='Launch')]
        [ValidateNotNullOrEmpty()]
        [Alias('connect')]
        [switch] 
        $Reconnect,

        [Parameter(Mandatory=$false, 
                   Position=1,
                   ParameterSetName='Mode')]
        [ValidateNotNullOrEmpty()]
        [Alias('end', 'close', 'halt', 'exit', 'stop')]
        [switch] 
        $Terminatewait,

        [Parameter(Mandatory=$false, 
            Position=2,
            ParameterSetName='Mode')]
        [ValidateNotNullOrEmpty()]
        [Alias('list', 'show', 'enumerate')]
        [switch] 
        $ListAvailable

    )

	# Set pnagent path string
    $pnagent="${env:ProgramFiles(x86)}\Citrix\ICA Client\pnagent.exe";

    Show-Progress -msgAction Start -msgSource $PSCmdlet.MyInvocation.MyCommand.Name

    if ($PSBoundParameters.ContainsKey('Qlaunch')) { 

    	if ($XenApps.Keys -contains $Qlaunch) {
		    $arguments = '/CitrixShortcut: (1)',"/QLaunch ""$($XenApps.$Qlaunch)""";
	    }
	    # /Terminate Closes out PNAgent and any open sessions
	    # /terminatewait  Closes out PNAgent and any open sessions; Logs off
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
		    Write-Log -Message "Start pnagent.exe $arguments)" -Function $PSCmdlet.MyInvocation.MyCommand.Name; # $pnagent
		    start-process $pnagent -ArgumentList $arguments;
	    } else {
	        Write-Log -Message "Unrecognized XenApp shortcut: $XenApp`nPlease try again with one of the following:" -Function $PSCmdlet.MyInvocation.MyCommand.Name;
	        $XenApps.Keys;
	        break;
        }
    } elseif ($PSBoundParameters.ContainsKey('Reconnect')) { 
        Write-Log -Message 'Start pnagent.exe /reconnect' -Function $PSCmdlet.MyInvocation.MyCommand.Name;
		start-process $pnagent -ArgumentList '/reconnect';
    } elseif ($PSBoundParameters.ContainsKey('Terminatewait')) { 
        Write-Log -Message 'Start pnagent.exe /terminatewait' -Function $PSCmdlet.MyInvocation.MyCommand.Name;
		start-process $pnagent -ArgumentList '/terminatewait';
    } elseif ($PSBoundParameters.ContainsKey('ListAvailable')) { 
        Write-Log -Message '`nEnumerating all available `$XenApps Keys' -Function $PSCmdlet.MyInvocation.MyCommand.Name;
		$XenApps | Sort-Object -Property Name | format-table -AutoSize
    }

    Show-Progress -msgAction Stop -msgSource $PSCmdlet.MyInvocation.MyCommand.Name
}
