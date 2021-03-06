﻿#Requires -Version 3.0 -Modules PSLogger

New-Variable -Name LastLogBackup -Description 'TimeStamp of the last time the Backup-Logs function was processed' -Scope Global -Force;
New-Variable -Name BackupCadence -Value 10 -Description 'Default recurrence frequency for running Backup-Logs function' -Scope Global -Force ;

[bool]$backupNow = $true;
function Backup-Logs {
<#
.SYNOPSIS
    Extension of Sperry module, to simplify cleanup of log files (commonly referred to as log rotation in UNIX / Linux context)
.DESCRIPTION
    As part of the PSLogger module, this script (function) is a complement to the Write-Log function, and simplifies WindowsPowerShell log maintenance
    By default, Backup-Logs will look for any/all files in $env:USERPROFILE\Documents\WindowsPowerShell\log, and if they're older than 7 days, move them into a archive\ subfolder
    If necesarry (and if sufficient permissions are available), the archive\ subfolder will be created automatically
    If the archive\ subfolder already exists, Backup-Logs will search for any files older than 90 days, and delete them.
    Note: For both the log age and the archive purge age, each file's LastWriteTime property is what is evaluated
    All of these conditions are customizable through parameters.
    Invoke get-help Backup-Logs -examples for additional information
.PARAMETER Path
    Optionally specifies the 'root' path of where to look for and maintain log files, to be moved to \archive\.
.PARAMETER Age
    Optionally specifies age of log files to be moved to \archive\.
.PARAMETER Purge
    Optionally specifies a date, by age from today(), for which all older log files will be deleted.
.EXAMPLE
    PS .\> Backup-Logs 

    Moves all .log files older than 7 days, from $env:USERPROFILE\Documents\WindowsPowerShell\log\ to $env:USERPROFILE\Documents\WindowsPowerShell\log\archive\
.EXAMPLE
    PS .\> Backup-Logs -age 14 -purge 90

    Moves all .log files older than 14 days, to $env:USERPROFILE\Documents\WindowsPowerShell\log\archive\, and deletes all files from the archive folder which are older than 90 days
.NOTES
    NAME        :  BackupLogs.ps1
    VERSION     :  1.0
    LAST UPDATED:  4/9/2015
    AUTHOR      :  Bryan Dady
#>
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [string]
        $path="$env:USERPROFILE\Documents\WindowsPowerShell\log",

        [Parameter(Mandatory=$false, Position=1)]
        [ValidateRange(0,9999)]
        [int16]
        $age=7,

        [Parameter(Mandatory=$false, Position=2)]
        [ValidateRange(0,9999)]
        [int16]
        $purge = 90,

        [Parameter(Mandatory=$false, Position=3)]
        [switch]
        $force
    )

    Show-Progress -msgAction Start -msgSource $MyInvocation.MyCommand.Name

    Write-Log -Message "Checking `$path: $path" -Function $MyInvocation.MyCommand.Name;

    if (Test-Path -Path "$path") {
        # confirmed $path exists; see if \archive subfolder exists
        if (Test-Path -Path "$path\archive") {
            Write-Log -Message 'confirmed archive folder exists' -Function $MyInvocation.MyCommand.Name;
            # set variable LastLogBackup based on the latest log file in $path\archive
            $LastLogFile = Get-ChildItem -Path $path\archive -Filter *.log -File | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1;
            Set-Variable -Name LastLogBackup -Value (Get-Date -Date $LastLogFile.LastAccessTime -DisplayHint Date -Format d) -PassThru;

            Write-Log -Message "LastLogBackup was $LastLogBackup" -Function $MyInvocation.MyCommand.Name;
            Set-Variable -Name NextBackupDate -Value (Get-Date -Date $LastLogBackup).AddDays($BackupCadence) -PassThru
            Write-Log -Message "NextBackupDate is $NextBackupDate" -Function $MyInvocation.MyCommand.Name;

            # Is today on or after $NextBackupDate ?
            if ($NextBackupDate -ge (Get-Date)) {
                # we DON'T need to backup right now
                $backupNow = $false;
            }
        } else {
            # log archive path doesn't yet exist, so create it
            Write-Log -Message 'Creating archive folder' -Function $MyInvocation.MyCommand.Name;
            New-Item -itemtype Directory -path $path\archive;
            Set-Variable -Name LastLogBackup -Value (Get-Date -DisplayHint Date -Format d);
            # Since we've never backed up to this path before, leave $backupNow = $true
        }

        if ($backupNow -or $force) {
            # we can now proceed with backing up logs
            $logFileDateString = get-date -UFormat '%Y%m%d';
            Write-Log -Message "Archiving files older than $age days." -Function $MyInvocation.MyCommand.Name -Verbose;
            Write-Log -Message " # # # BEGIN ROBOCOPY # # # # #`n" -Function $MyInvocation.MyCommand.Name;
        
            Write-Log -Message "About to run robocopy, logging to ""$path\Backup-Logs_$logFileDateString.log""" -Function $MyInvocation.MyCommand.Name;

            & robocopy.exe """$path"" ""$path\archive"" /MINAGE:$age /MOV /R:1 /W:1 /NS /NC /NP /NDL /TEE" | Out-File -FilePath "$path\Backup-Logs_$logFileDateString.log" -Append -NoClobber;

            Write-Log -Message " # # # END ROBOCOPY # # # # #`n" -Function $MyInvocation.MyCommand.Name;

            # Now we attempt to cleanup (purge) any old files
            [System.DateTime]$purgeDate = (Get-Date).AddDays(-$purge);
            Write-Log -Message "Purge date is $purgeDate" -Function $MyInvocation.MyCommand.Name;
        
            # Enumerate files, and purge those that haven't been updated wince $purge.
            Write-Log -Message "Deleting archive\ files older than $purgeDate" -Function $MyInvocation.MyCommand.Name -Verbose;

            Get-ChildItem -Path $path\archive -File | Where-Object {$_.LastWriteTime -lt $purgeDate} | Remove-Item -ErrorAction SilentlyContinue -WhatIf;

        } else {
            Write-Log -Message 'No need to archive log files right now.' -Function $MyInvocation.MyCommand.Name;
        }
    } else {
        Write-Log -Message "Unable to confirm existence of logs folder: $path" -Function $MyInvocation.MyCommand.Name -Verbose;
    }
    
    Show-Progress -msgAction Stop -msgSource $MyInvocation.MyCommand.Name
}

New-Alias -Name Archive-Logs -Value Backup-Logs -Description 'PSLogger Module' -ErrorAction SilentlyContinue;

Export-ModuleMember -function Backup-Logs -Alias Archive-Logs;
