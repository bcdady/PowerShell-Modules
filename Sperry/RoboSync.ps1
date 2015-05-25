#Requires -Version 3.0 -Modules Sperry, PSLogger
<#
        .SYNOPSIS
        Robocopy command and control script to synchronize user profile folders between local and network home directories, and logs results
        .DESCRIPTION
        Profile-Sync re-uses preset robocopy parameters, to make it easy to synchronize several different network-based (NAS) home directories with the expected local directories. Robocopy parameters are set to keep the latest documents and IE favorites up to date across the various profile paths.
        .EXAMPLE
        Profile-Sync.ps1 [writes Profile-Sync.log to the same directory]

        .OUTPUTS
        Creates a text lof file using write-log function, dot-sourced referenced from write-log.ps1 within the script.
        Variable $loggingFilePreference specifies where to write this log file

        .NOTES
        NAME      : Profile-Sync.ps1
        LANGUAGE  : Windows PowerShell
        AUTHOR    : Bryan Dady
        DATE      : June 09, 2014
        COMMENT   : Profile-Sync.ps1 can live anywhere, although it expects local environment variables from a windows logged on session to function properly.
        Synchronizes primary (H:), admin ("2" account;  documents and favorites only), and local user profile folders
#>
# ======= HEADER ========================
$myPath = split-path $MyInvocation.MyCommand.Path;
$myName = $MyInvocation.MyCommand.Name;

# ======= SETUP =========================
[Cmdletbinding(SupportsShouldProcess=$true)]
$loggingPreference='Continue';
$loggingPath = Split-Path $PSScriptRoot | join-Path -ChildPath 'log' -Resolve;
$logFileDateString = get-date -UFormat '%Y%m%d';
[bool]$PurgeTarget = $false; 

# Use regular expression make a .log file that matches this scripts name; makes logging portable
$MyInvocation.MyCommand.Name -match "(.*)\.\w{2,3}?$" *>$NULL; $myLogName = $Matches.1;
$loggingFilePreference = Join-Path -Path $loggingPath -ChildPath "$myLogName-$logFileDateString.log"

# Use regular expression on launch path to determine if this script is in dev mode (in a folder named 'working') or not; makes logging more portable
if ($testMode) { $loggingFilePreference = Join-Path -Path $loggingPath -ChildPath "$myLogName-test-$logFileDateString.log"; }

<#
  Robocopy.exe example: robocopy.exe source destination [options]
  Our preferred options: 
    /S   :: copy Subdirectories, but not empty ones.
    /PURGE :: delete dest files/dirs that no longer exist in source.
    /R:n :: number of Retries on failed copies: default 1 million.
    /W:n :: Wait time between retries: default is 30 seconds.
    /L   :: List only - don't copy, timestamp or delete any files.	
    /LOG+:file :: output status to LOG file (append to existing log).
    /TEE :: output to console window, as well as the log file.
    /NJH :: No Job Header.
    /NJS :: No Job Summary.
    /MAX:n :: MAXimum file size - exclude files bigger than n bytes.
    /MIN:n :: MINimum file size - exclude files smaller than n bytes.
    /MAXLAD:n :: MAXimum Last Access Date - exclude files unused since n.
    /XF file [file]... :: eXclude Files matching given names/paths/wildcards.
    /XD dirs [dirs]... :: eXclude Directories matching given names/paths.
    e.g. /XD: `$RECYCLE.BIN
#>

# robocopy specific log filename strings; initialized once, reused within robosync function :
$monthNames = (new-object system.globalization.datetimeformatinfo).MonthNames; # instantiate array of names of months
[string]$thisMonth = $monthNames[((Get-Date).Month-1)]; # Get the name of the current month by looking up get-date results in $monthNames (zero-based) array
$logFileDateString = get-date -UFormat '%Y%m%d';
$logFileName = "robosync-$logFileDateString.log";
$robocopyOptions = "/S /R:1 /W:1 /NS /NC /NP /LOG+:$loggingPath\$logFileName /TEE /XF `~`$* desktop.ini *.log Win8RP-Pro-Boot.zip /XD log `$RECYCLE.BIN DAI ""Win8 ADK"" ""My Demos"" EIT KRosling SnagIt TFEM NO-SYNC";

# ======= ROBOSYNC FUNCTION =============
function Start-Robosync  {
    [Cmdletbinding(SupportsShouldProcess=$true)]
    param (
        #[Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$true, HelpMessage='Specify path to source directory, can be UNC.')]
        [alias('from')]
        [String[]]
        [ValidateScript({Test-Path -Path $_ -PathType Container -IsValid})]
        $Source,

        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$true, HelpMessage='Specify path to destination directory, can be UNC.')]
        [String[]]
        [alias('target','to')]
        [ValidateScript({Test-Path -Path $_ -PathType Container -IsValid})]
        $Destination
    )    

    if ($Destination -imatch 'C:\\Users\\') {
        #unless cleanRemote, presume we're robo-syncing recently changed files from remote shares to local, so don't sync back anything that hasn't been touched in the past 90 days
        $robocopyOptions = $robocopyOptions, '/MAXLAD:90' -join ' ';
        if ($PurgeTarget) {
            $robocopyOptions = $robocopyOptions, '/PURGE' -join ' ';
        }
    }
    if ($Destination -imatch 'Desktop') {
        #Constrain desktop items to be copied to < 100 MB
        $robocopyOptions = $robocopyOptions, '/MAX:1048576' -join ' ';
    }

    if ($Destination -imatch 'Favorites') {
        #Constrain desktop items to be copied to < 100 MB
        $robocopyOptions = $robocopyOptions, '/MAX:1048576' -join ' ';
    }

    # if -whatif was included, proceed with dry run
    if (!$PSCmdlet.ShouldProcess($AddedFolder) ) {
        # update log file name to specify test mode, and add /L switch to robocopy options to run in List Only mode 
        $robocopyOptions -replace "$logFileName", "robosync-test-$logFileDateString.log";
        $robocopyOptions = $robocopyOptions, '/L' -join ' ';
        write-log "# # # Robocopy $Source $Destination $robocopyOptions";
        Start-Process robocopy.exe "$Source $Destination $robocopyOptions" -wait -verb open  2> $loggingPath\robosync-test-errors.log 3> $loggingPath\robosync-test-warnings.log; # 3>&2 didn't work
        write-log "`t`t[spacer]`n";
    } else {
        #Run the Robocopy
        write-log "# # # Robocopy $Source $Destination $robocopyOptions";
        Start-Process robocopy.exe "$Source $Destination $robocopyOptions" -wait -verb open  2> $loggingPath\robosync-errors.log 3> $loggingPath\robosync-warnings.log; # 3>&2 didn't work
        write-log "`t`t[spacer]`n";
            
    }
    # show results from the just-created robosync log file
    Read-Log -MessageSource $logFileName -lineCount 50;
    
}

# ======= MAIN BODY =====================
$erroractionpreference = 'Continue' # shows error message, but continue

# If in XenApp, sync server side, and then through 'remotely' mapped C: drive
if ($env:ComputerName -ne 'GC91IT78') {
    Write-Host -Object 'Preparing to sync work network folders' -ForegroundColor DarkYellow
} else { Write-Host -Object 'Consider uploading backups of appropriate files to OneDrive' -ForegroundColor Green }

# Define variables for each source and target, to be used in a hashtable
<#
        $H2Docs = '$HOMESHARE2\My Documents' 
        $H1Infra = '$env:HOMESHARE\My Documents\Infrastructure'
        $H1Docs = '$env:HOMESHARE\My Documents'
        $H2Favs = '$HOMESHARE2\Favorites'
        $H1Favs = '$env:HOMESHARE\Favorites'
        $LocalDocs = '$env:USERPROFILE\Documents'
        $LocalFavs = '$env:USERPROFILE\Favorites'
        $AppSenseRecent = '$env:HOMESHARE\AppSenseData\Recent\Win7-2008'
        $LocalRecent = '$env:AppData\Microsoft\Windows\Recent'
        $LocalDesktop = '$env:USERPROFILE\Desktop'
        $H1Desktop = '$env:HOMESHARE\Desktop'; # Constrain to files smaller than 100 MB
        $H1FavsIT = '$env:HOMESHARE\Favorites\Links\GBCI IT'
        $H2FavsIT = '$HOMESHARE2\Favorites\Links\GBCI IT'
#>

[string]$ModPSLogger = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\PSLogger"
[string]$ModSperry = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\Sperry"
[string]$ModProPal = "$env:ProgramFiles\WindowsPowerShell\Modules\ProfilePal"
[string]$GitPSLogger = "$env:USERPROFILE\Documents\GitHub\PSLogger"
[string]$GitSperry = "$env:USERPROFILE\Documents\GitHub\Sperry"
[string]$GitProPal = "$env:ProgramFiles\GitHub\ProfilePal"

<#
        $H2Docs = $H1Infra;
        $H2Favs = $H1Favs;
        $H1Docs = $LocalDocs;
        $H1Favs = $LocalFavs;
        $LocalDocs = $H1Docs;
        $LocalFavs = $H1Favs;
        $LocalRecent = $AppSenseRecent;
        $LocalDesktop = $H1Desktop;
        $H1FavsIT = $H2FavsIT;
#>
function Sync-PSLogger   { Start-Robosync -Source "$ModPSLogger" -Destination "$GitPSLogger" }
function Sync-Sperry     { Start-Robosync -Source "$ModSperry" -Destination "$GitSperry" }
function Sync-ProfilePal { Start-Robosync -Source "$ModProPal" -Destination "$GitProPal" }

function Sync-HomeShares {
    # Log start timestamp
    Show-Progress -msgAction Start -msgSource $PSCmdlet.MyInvocation.MyCommand.Name

    # Test for Profile1 = HOMESHARE ;; RFE :: use $Home instead?
    if (test-path -Path "$env:HOMESHARE" -IsValid) {
        write-log "Profile1 is $env:HOMESHARE" -verbose;
        # Setup Profile2 : admin '2 account' HOMESHARE path string
        $HOMESHARE2 = $env:HOMESHARE, '2' -join '';
        if (test-path $HOMESHARE2 -ErrorAction SilentlyContinue) {
            write-log "Profile2 is $HOMESHARE2" -verbose;
        } else {
            #uh oh, that didn't work
            write-log "Could not confirm admin profile: $HOMESHARE2" -verbose;
            # Are we Andy Maney e.g. need to use a '3' account?
            $HOMESHARE2 = $env:HOMESHARE, '3' -join '';
            if (test-path $HOMESHARE2 -ErrorAction SilentlyContinue) {
                write-log "It's ok now, I found $HOMESHARE2 and will use it for Profile2";
            } else {
                #uh oh, we may not be connected to the network
                Show-Progress 'Stop';
                break;
            }
        }
        # Setup LocalProfile
        If (test-path $env:USERPROFILE -ErrorAction SilentlyContinue) {
            write-log "Local profile is $env:USERPROFILE";
            # At this point, we're good to go ...
            # Sync Profile2 to Profile1 - Docs, favs
            write-log 'robosync Profile2 to Profile1' -verbose;
            Start-Robosync """$HOMESHARE2\My Documents""" """$env:HOMESHARE\My Documents\Infrastructure""";
            Start-Robosync "$HOMESHARE2\Favorites" "$env:HOMESHARE\Favorites";

            # Sync Profile1 to LocalProfile - Docs, favs, recent
            write-log 'robosync Profile1 to LocalProfile' -verbose;
            Start-Robosync """$env:HOMESHARE\My Documents""" "$env:USERPROFILE\Documents";
            Start-Robosync "$env:HOMESHARE\Favorites" "$env:USERPROFILE\Favorites";
            #robosync "$env:HOMESHARE\AppSenseData\Recent\Win7-2008" "$env:AppData\Microsoft\Windows\Recent";

            # Sync LocalProfile to Profile1 - Docs, favs, recent
            write-log 'robosync LocalProfile to Profile1' -verbose;
            Start-Robosync "$env:USERPROFILE\Documents" """$env:HOMESHARE\My Documents""";
            Start-Robosync "$env:USERPROFILE\Favorites" "$env:HOMESHARE\Favorites";
            Start-Robosync "$env:AppData\Microsoft\Windows\Recent $env:HOMESHARE\AppSenseData\Recent\Win7-2008";
            Start-Robosync "$env:USERPROFILE\Desktop $env:HOMESHARE\Desktop"; # Constrained to files smaller than 100 MB
		
            # Sync Profile1 to Profile2 - favorites only
            write-log 'robosync Profile1 to Profile2 (favorites only)' -verbose;
            #Remove-Item $HOMESHARE2\Favorites -Recurse -ErrorAction:SilentlyContinue; # first we delete all other files from Profile2 Favorites (safe, because we just sync'ed these
            Start-Robosync """$env:HOMESHARE\Favorites\Links\GBCI IT"" ""$HOMESHARE2\Favorites\Links\GBCI IT""";
            write-log 'Completed Successfully' -verbose;
        }
    }

    Show-Progress -msgAction Stop -msgSource $PSCmdlet.MyInvocation.MyCommand.Name
}


trap [System.Exception] {
    write-log 'Errors occurred. See log file for details.' -verbose;
    #uh oh, we may not be connected to the network
    write-log "Likely could not connect to home share (`$env:HOMESHARE )";
    write-log "ErrorLevel: $error[0]";
    Read-Host 'Please press any key to acknowledge.' # $acknowledge =
}

# ======= PROFILE PATH REFERENCE ================
# [HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders]
<# "AppSenseData" = \\gbci02sanct3\homes$\gbci\BDady\AppSenseData\Recent\Win7-2008
        AppData=[Roaming]
        Cache=[Local]
        Cookies=[Local]
        Desktop=[Local]
        Favorites=[Local]
        History=[Local]
        Local AppData=[Local]
        My Music=AppSenseData\Music
        My Pictures=AppSenseData\Pictures
        My Video=AppSenseData\Video
        NetHood=[Local]
        Personal=[Local]\Documents
        PrintHood=[Roaming]
        Programs=[Roaming]
        Recent=\AppSenseData\Recent\Win7-2008
        SendTo=[Roaming]
        Start Menu=[Roaming]
        Startup=[Roaming]
        Templates=[Roaming]
#>