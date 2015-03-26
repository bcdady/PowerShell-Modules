#Requires -Version 3.0 -Modules PSLogger

<#
.SYNOPSIS
Extension of Sperry module, to simplify logging of function calls, with matching messages to the console, when specified
.DESCRIPTION
Built on to the Write-Log function / script originally provided by Jeff Hicks, this script makes the Show-Progress function portable, as part of the PSLogger Module
.PARAMETER stampType
The stampType parameter specifies to the Show-Progress functionn whether the update written to the log and/or shown on the console is a Start, Stop, or continue action.
When passed to the Write-Log function, the Show-Progress message inherits the timestamp and other features of that function.

.EXAMPLE
PS > Show-Progress 'Start'; # Log start timestamp

<< get example output and add into ShowProgress.ps1 Help >>

.EXAMPLE
PS > Show-Progress 'Stop'; # Log end timestamp

.NOTES
    NAME        :  Start-XenApp
    VERSION     :  1.1   
    LAST UPDATED:  3/25/2015
    AUTHOR      :  Bryan Dady
#>

function Show-Progress  {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [alias('mode','scope')]
        [ValidateSet('Start', 'Stop',$null)]
        [String[]]
        $stampType
    )

	Switch ($stampType) {
        'Start' {
			write-log "Starting $PsCmdlet"  -verbose;
			write-log "Logging to $loggingFilePreference" -verbose;
		};
        'Stop'  {
			write-log "Exiting $PsCmdlet" -verbose;
			write-log "`n";
			break;
		};
        default { write-log "continuing $PsCmdlet" -verbose; };
    }
}
