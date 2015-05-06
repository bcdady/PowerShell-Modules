#requires -version 2.0
# -----------------------------------------------------------------------------
# Script: PSLogger.psm1
# Version: 1.1
# Original Write-Log Author: Jeffery Hicks
#    http://jdhitsolutions.com/blog
#    http://twitter.com/JeffHicks
# Date: 3/3/2011
# Keywords: Verbose, Logging
# Comments: "Those who neglect to script are doomed to repeat their work."
#
# Converted to PS Module and enhanced (if I may be so bold as to attempt to build upon Jeff's work) by Bryan Dady
#
#  ****************************************************************
#  * DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED *
#  * THOROUGHLY IN A LAB ENVIRONMENT. USE AT YOUR OWN RISK.  IF   *
#  * YOU DO NOT UNDERSTAND WHAT THIS SCRIPT DOES OR HOW IT WORKS, *
#  * DO NOT USE IT OUTSIDE OF A SECURE, TEST SETTING.             *
#  ****************************************************************
# -----------------------------------------------------------------------------

# Setup necessary configs for PSLogger's Write-Log cmdlet
[string]$loggingPreference='Continue'; # set $loggingPreference to anything other than continue, to leverage write-debug or write-verbose, without writing to a log on the filesystem
[string]$loggingPath = "$env:userprofile\Documents\WindowsPowerShell\log"
[string]$logFileDateString = get-date -UFormat '%Y%m%d'; # Need to keep an eye on this one, in case PowerShell sessions run for multiple days, I doubt this variable value will be refreshed / updated
[string]$LastFunction = '';
[bool]$writeIntro=$true

Function Write-Log {

<#
   .Synopsis
        Write a message to a log file. 
    .Description
        Write-Log can be used to write text messages to a log file. It can be used like Write-Verbose,
        and looks for two variables that you can define in your scripts and functions. If the function
        finds $LoggingPreference with a value of "Continue", the message text will be written to the file.
        The default file is PowerShellLog.txt in your %TEMP% directory. You can specify a different file
        path by parameter or set the $logFilePref variable. See the help examples.
    
        This function also supports Write-Verbose which means if -Verbose is detected, the message text
        will be written to the Verbose pipeline. Thus if you call Write-Log with -Verbose and a the 
        $loggingPreference variable is set to continue, you will get verbose messages AND a log file.
    .Parameter Message
        The message string to write to the log file. It will be prepended with a date time stamp.
    .Parameter Path
        The filename and path for the log file. The default is $env:temp\PowerShellLog.txt, 
        unless the $logFilePref variable is found. If so, then this value will be used.
   .Example
        PS C:\> . c:\scripts\write-log.ps1
    
    Here is a sample function that uses the Write-Log function after it has been dot sourced. Within the sample 
    function, the logging variables are defined.
    
Function TryMe {
    [cmdletbinding()]
    Param([string]$computername=$env:computername,
    [string]$Log
    )
    if ($log) 
    {
     $loggingPreference="Continue"
     $logFilePref=$log
    }
    Write-log "Starting Command"
    Write-log "Connecting to $computername"
    $b=gwmi win32_bios -ComputerName $computername
    $b
    Write-log $b.version
    Write-Log "finished" $log
}

TryMe -log e:\logs\sample.txt -verbose
  
   .Notes
    NAME: Write-Log
    AUTHOR: Jeffery Hicks
    VERSION: 1.0
    LASTEDIT: 03/02/2011
    
    Learn more with a copy of Windows PowerShell 2.0: TFM (SAPIEN Press 2010)
    
   .Link
       http://jdhitsolutions.com/blog/2011/03/powershell-automatic-logging/
    
    .Link
        Write-Verbose
#>

    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='The message string to write to the log file. It will be prepended with a date time stamp.')]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory=$false, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=1,
                   HelpMessage='The Function Parameter passes the name of the Function or CmdLet that invoked this Write-Log function')]
        [ValidateNotNullOrEmpty()]
        [Alias('Action', 'Source')]
        [String]
        $Function = 'PowerShell',

        [Parameter(Position=2,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   HelpMessage='The optional Path parameter specifies the path of the log file to write the message to.')]
        [string[]]
	    $Path="$env:userprofile\Documents\WindowsPowerShell\log\PowerShell.log"

    )

    # Detect -debug mode:
    # http://blogs.msdn.com/b/powershell/archive/2009/04/06/checking-for-bound-parameters.aspx
    # https://kevsor1.wordpress.com/2011/11/03/powershell-v2-detecting-verbose-debug-and-other-bound-parameters/
    if ($PSBoundParameters['Debug'].IsPresent) {
	    [bool]$testMode = $true; 
        $logFilePref = Join-Path -Path $loggingPath -ChildPath "$Function-test-$logFileDateString.log"
    } else {
	    [bool]$testMode = $false; 
        $logFilePref = Join-Path -Path $loggingPath -ChildPath "$Function-$logFileDateString.log"
    }

    # Detect if this Function is the same as the $LastFunction. If not, verbosely log which new Function is Active
    if ($Function -ne $LastFunction) {$writeIntro=$true} else {$writeIntro=$false}

    #Pass on the message to Write-Debug cmdlet if -Debug parameter was used
    Write-Debug -Message $Message;
    if ($writeIntro -and ( $Message -notlike 'Exit*')) {Write-Host -Message "Logging [Debug] to $logFilePref`n" };

    #Pass on the message to Write-Verbose cmdlet if -Verbose parameter was used
    Write-Verbose -Message $Message;
    if ($writeIntro -and ( $Message -notlike 'Exit*')) { Write-Host -Message "Logging [Verbose] to $logFilePref`n" };
    
    #only write to the log file if the $LoggingPreference variable is set to Continue
    if ($LoggingPreference -eq 'Continue') {
    
        #if a $logFilePref variable is found in the scope hierarchy then use that value for the file, otherwise use the default $path
        if ($logFilePref) {
		    $LogFile=$logFilePref
        } else {
		    $LogFile=$Path
        }
        if ($testMode) {
            Write-Output "$(Get-Date) [Debug]$Message" | Out-File -FilePath $LogFile -Append
        } elseif ($PSBoundParameters['Verbose'].IsPresent) {
            Write-Output "$(Get-Date) [Verbose]$Message" | Out-File -FilePath $LogFile -Append
        } else {
            Write-Output "$(Get-Date) $Message" | Out-File -FilePath $LogFile -Append
        }
    }

    $LastFunction = $Function; # retain 'state' of the last function name called, to simplify future logging statements from the same function

} #end function

Export-ModuleMember -function Write-Log, Show-Progress, Backup-Logs