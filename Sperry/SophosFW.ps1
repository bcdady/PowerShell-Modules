<#
.SYNOPSIS
    SophosFW.ps1 belongs to the Sperry 'autopilot' module, which includes functions to automate getting into and out of work mode.
.DESCRIPTION
	Interacts with Windows Services specific to Sophos endpoint security, specifically software firewall
    This is intended as a prototype for how to user PowerShell in a script, as a supporting component of a Module
.EXAMPLE
    PS C:\> Get-SophosFW
    Enumerate current state of Sophos Firewall (as an aggregate of all related Windows services)
.EXAMPLE
    PS C:\> Set-SophosFW -ServiceAction Start
    Starts all related Windows services, so that Sophos firewall is active
.NOTES
    NAME        :  SophosFW.ps1
    VERSION     :  2.2   
    LAST UPDATED:  4/16/2015
    AUTHOR      :  Bryan Dady
.LINK
    Sperry.psm1 
.INPUTS
    None
.OUTPUTS
    Write-Log
#>
#Requires -Version 3.0 -Modules Sperry
function Get-SophosFW {
    # Checks status of Sophos firewall services
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=0, HelpMessage='Specify desired service state. Accepts Running or Stopped.')]
        [String]
        [alias('Status','State')]
        [ValidateSet('Running', 'Stopped')]
        $ServiceStatus
    )
    [bool]$SophosFW = $null; # reset variable

    Show-Progress -Mode 'Start' -Action SophosFW; # Log start timestamp
	# 1st: Let's check if the firewall services are running 
	Write-Log -Message 'Checking count of Sophos* services running ...' -Function SophosFW;
	$svcStatus = @(Get-Service Sophos* | where-object {$_.Status -eq 'Running'});
	Write-Log -Message "Service Count: $($svcStatus.Count)" -Function SophosFW;

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
                $SophosFW = $true;
		    }
        }
    }
    Write-Log -Message "Get-SophosFW $ServiceStatus = $SophosFW " -Function SophosFW;

    Show-Progress -Mode Stop -Action SophosFW; # Log stop timestamp

    return $SophosFW;
}

function Set-SophosFW {
    # Controls Sophos firewall services, state
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory=$true,
            Position=0,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            HelpMessage='Specify service state change action. Accepts Start or Stop.')
         ]
        [alias('Action','State')]
        [ValidateSet('Start', 'Stop')]
        $ServiceAction
    )

Set-PSDebug -Trace 1

    $ErrorActionPreference = 'SilentlyContinue';
    Show-Progress -Mode Start -Action SophosFW; # Log start timestamp
    if (Test-AdminPerms) {
		# We already have elevated permissions; proceed with controlling services
        switch ($ServiceAction) {
            'Start' {
            	Write-Log -Message 'Confirmed elevated privileges; resuming Sophos services' -Function SophosFW -verbose;
		        Get-Service Sophos* | start-Service;
		        Get-Service Swi* | start-Service;
                Start-Sleep -Seconds 1;
                Get-SophosFW -ServiceStatus Running;
            }
            'Stop' {
            	Write-Log -Message 'Confirmed elevated privileges; halting Sophos services' -Function SophosFW  -verbose;
		        Get-Service Sophos* | stop-Service;
		        Get-Service Swi* | stop-Service;
                Start-Sleep -Seconds 1;
                Get-SophosFW -ServiceStatus Stopped;
            }
        }        
	} else {
        # Before we attempt to elevate permissions, check current services state 
        switch ($ServiceAction) {
            'Start' {
		        if ( Get-SophosFW -ServiceStatus Running ) {
			        Write-Log -Message 'Sophos firewall services confirmed running' -Function SophosFW -verbose;
		        } else {
			        Write-Log -Message 'Need to elevate privileges for proper completion ... requesting admin credentials.' -Function SophosFW;
			        start-process -FilePath "$PSHOME\powershell.exe" -ArgumentList ' -Command {Get-Service Sophos* | start-Service; Get-Service Swi* | start-Service -ErrorAction:SilentlyContinue;}' -verb RunAs -Wait;
			        Write-Log -Message 'Elevated privileges session completed ... firewall services running :' -Function SophosFW;
                    Get-SophosFW -ServiceStatus Running;
		        }
            }
            'Stop' {
		        if (Get-SophosFW -ServiceStatus Stopped) {
			        Write-Log -Message 'Sophos firewall services confirmed stopped' -Function SophosFW -verbose;
		        } else {
			        Write-Log -Message 'Need to elevate privileges for proper completion ... requesting admin credentials.' -Function SophosFW -Debug;
Set-PSDebug -Step
			        start-process -FilePath powershell.exe -ArgumentList '-NoProfile -NoLogo -NonInteractive -Command "& {Get-Service Sophos* > $env:userprofile\Documents\WindowsPowerShell\log\stop-sophos.log; Get-Service Sophos* | stop-Service; Get-Service Swi* >> $env:userprofile\Documents\WindowsPowerShell\log\stop-sophos.log; Get-Service Swi* | stop-Service; start-sleep 1; Get-Service sophos* >> $env:userprofile\Documents\WindowsPowerShell\log\stop-sophos.log; Get-Service Swi* >> $env:userprofile\Documents\WindowsPowerShell\log\stop-sophos.log}"' -verb RunAs -Wait; # -ErrorAction SilentlyContinue | Write-Log -Function SophosFW -Debug
Set-PSDebug -Off
			        Write-Log -Message 'Elevated privileges session completed ... firewall services stopped: ' -Function SophosFW -Verbose;
                    Get-SophosFW -ServiceStatus Stopped;
		        }
            }
        }
	}
    Show-Progress -Mode Stop -Action SophosFW; # Log stop timestamp
    
Set-PSDebug -Off
}
