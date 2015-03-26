<#
.SYNOPSIS
    SophosFW.ps1 belongs to the Sperry 'autopilot' module, which includes functions to automate getting into and out of work mode.
.DESCRIPTION
	Customizes the user's operating environment and launches specified applications, to operate in a workplace persona 
	
    The module includes functions such as profile-sync, Check-Process, and references to Write-Log.	
.EXAMPLE
PS C:\> Get-SophosFW
Enumerate current state of Sophos Firewall (as an aggregate of all related Windows services)
.EXAMPLE
PS C:\> Set-SophosFW -ServiceAction Start
Starts all related Windows services, so that Sophos firewall is active
.NOTES
NAME        :  SophosFW.ps1
VERSION     :  2.0   
LAST UPDATED:  3/25/2015
AUTHOR      :  Bryan Dady
.LINK
Sperry.psm1 
.INPUTS
None
.OUTPUTS
None
#>
#Requires -Version 3.0 -Modules Sperry

function Get-SophosFW {
    # Checks status of Sophos firewall services
    [cmdletbinding()]
    [OutputType([boolean])]
    Param(
        [Parameter(Mandatory=$true, Position=0, HelpMessage='Specify desired service state. Accepts Running or Stopped.')]
        [String[]]
        [alias('Status','State')]
        [ValidateSet('Running', 'Stopped')]
        $ServiceStatus,

        [boolean]$SophosFW
    )

    Show-Progress 'Start'; # Log start timestamp
	# 1st: Let's check if the firewall services are running 
	Write-Log 'Checking count of Sophos* services running ...' -debug;
	$svcStatus = @(Get-Service Sophos* | where-object {$_.Status -eq 'Running'});
	Write-Log $svcStatus.Count -debug;
    switch ($ServiceStatus) {
        'Running' {
            # if we want all the services running, but fewer than all 7 are running, then our answer is false
		    if ($svcStatus.Count -le 6) {
                $SophosFW = $false;
		    } else {
                # otherwise, we can answer True
                $SophosFW = $true;
            }
        }
        'Stopped' {
		    if ($svcStatus.Count -ge 1) {
            # if we want all the services Stopped, but 1 or more are running, then our answer is false
                $SophosFW = $false;
		    } else {
                # otherwise, we can answer True
                $SophosFW = $false;
		    }
        }
    }        

    Show-Progress 'Stop'; # Log end timestamp
    return $SophosFW;
}

function Set-SophosFW {
# Controls Sophos firewall services, state
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='Specify service state change action. Accepts Start or Stop.')]
        [String[]]
        [alias('Action','State')]
        [ValidateSet('Start', 'Stop')]
        $ServiceAction
    )
	Show-Progress 'Start'; # Log start timestamp
    if (Test-AdminPerms) {
		# If we already have elevated permissions, then act on the Sophos services
        switch ($ServiceAction) {
            'Start' {
            	write-log 'Confirmed elevated privileges; resuming Sophos services' -verbose;
		        Get-Service Sophos* | start-Service;
		        Get-Service Swi* | start-Service -ErrorAction:SilentlyContinue;
            }
            'Stop' {
            	write-log 'Confirmed elevated privileges; halting Sophos services' -verbose;
		        Get-Service Sophos* | stop-Service;
		        Get-Service Swi* | stop-Service -ErrorAction:SilentlyContinue;
            }
        }        
	} else {
		# Before we attempt to elevate permissions, check current services state 
        switch ($ServiceAction) {
            'Start' {
		        if (Get-SophosFW('Running')) {
			        write-log 'Sophos firewall services already running' -verbose;
		        } else {
			        write-log 'Need to elevate privileges for proper completion ... requesting admin credentials.';
			        start-process powershell.exe 'Set-SophosFW Start' -verb RunAs -Wait;
			        write-log 'Elevated privileges session completed ... firewall services should all be running now.';
		        }
            }
            'Stop' {
		        if (Get-SophosFW('Stopped')) {
			        write-log 'Sophos firewall services already stopped' -verbose;
		        } else {
			        write-log 'Need to elevate privileges for proper completion ... requesting admin credentials.';
			        start-process powershell.exe 'Set-SophosFW Stop' -verb RunAs -Wait;
			        write-log 'Elevated privileges session completed ... firewall services should all be stopped now.';
		        }
            }
        }        
	}
    Show-Progress 'Stop'; # Log end timestamp
}
