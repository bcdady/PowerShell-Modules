﻿#Requires -Version 3.0 -Modules Sperry, PSLogger
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

    $ErrorActionPreference = 'SilentlyContinue';
    Show-Progress -Mode Start -Action SophosFW; # Log start timestamp
    if (Test-LocalAdmin) {
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
                    Set-UAC;
                    start-process -FilePath "$PSHOME\powershell.exe" -ArgumentList '-NoProfile -Command "& {Start-Service -Name Sophos* -ErrorAction Ignore; Start-Service -Name Swi* -ErrorAction Ignore;}"' -verb RunAs -Wait;
                    $ServiceStatus = $?
                    if ($ServiceStatus) {
                        Write-Log -Message "Elevated privileges session completed ... firewall services running: $ServiceStatus" -Function SophosFW;
                    } else {
                        Write-Log -Message "Elevated privileges session completed. Result: $ServiceStatus. There was an issue starting / resuming firewall services" -Function SophosFW -Verbose;
                    }
                }
            }
            'Stop' {
                if (Get-SophosFW -ServiceStatus Stopped) {
                    Write-Log -Message 'Sophos firewall services confirmed stopped' -Function SophosFW -verbose;
                } else {
                    Write-Log -Message 'Need to elevate privileges for proper completion ... requesting admin credentials.' -Function SophosFW -Debug;
                    Set-UAC;
                    start-process -FilePath "$PSHOME\powershell.exe" -ArgumentList '-NoProfile -Command "& {Stop-Service -Name Sophos*; Stop-Service -Name Swi*}"' -verb RunAs -Wait;
                    $ServiceStatus = $?
                    if ($ServiceStatus) {
                        Write-Log -Message "Elevated privileges session completed ... firewall services running: $ServiceStatus" -Function SophosFW;
                    } else {
                        Write-Log -Message "Elevated privileges session completed. Result: $ServiceStatus. There was an issue suspending firewall services" -Function SophosFW -Verbose;
                    }
                }
            }
        }
	}
    Show-Progress -Mode Stop -Action SophosFW; # Log stop timestamp
}
