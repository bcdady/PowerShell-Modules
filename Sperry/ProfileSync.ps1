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
# Specify path / drive letter to backup volume
$backupVolume = 'F:';

# ======= SETUP =========================
# Dot-source the borrowed write-log script, and setup it's necessary configs
$dotSource = Split-Path $PSScriptRoot | join-Path -ChildPath 'borrowed\Write-Log.ps1' -Resolve; . $dotSource;
[cmdletbinding()]
$loggingPreference='Continue';
$loggingPath = Split-Path $PSScriptRoot | join-Path -ChildPath 'log' -Resolve;
$logFileDateString = get-date -UFormat '%Y%m%d';
[bool]$cleanRemote = $false; 

# Use regular expression make a .log file that matches this scripts name; makes logging portable
$MyInvocation.MyCommand.Name -match "(.*)\.\w{2,3}?$" *>$NULL; $myLogName = $Matches.1;
$loggingFilePreference = Join-Path -Path $loggingPath -ChildPath "$myLogName-$logFileDateString.log"

# Use regular expression on launch path to determine if this script is in dev mode (in a folder named 'working') or not; makes logging more portable
if ($testMode) { $loggingFilePreference = Join-Path -Path $loggingPath -ChildPath "$myLogName-test-$logFileDateString.log"; }

##. $env:USERPROFILE\Documents\Scripts\borrowed\show-msgbox.ps1;
# $dotSource = Split-Path $PSScriptRoot | join-Path -ChildPath "borrowed\show-msgbox.ps1" -Resolve; . $dotSource;

# Robocopy.exe example: robocopy.exe source destination [options]
# Our preferred options: 
# /S   :: copy Subdirectories, but not empty ones.
# /PURGE :: delete dest files/dirs that no longer exist in source.
# /R:n :: number of Retries on failed copies: default 1 million.
# /W:n :: Wait time between retries: default is 30 seconds.
# /L   :: List only - don't copy, timestamp or delete any files.	
# /LOG+:file :: output status to LOG file (append to existing log).
# /TEE :: output to console window, as well as the log file.
# /NJH :: No Job Header.
# /NJS :: No Job Summary.
# /MAX:n :: MAXimum file size - exclude files bigger than n bytes.
# /MIN:n :: MINimum file size - exclude files smaller than n bytes.
# /MAXLAD:n :: MAXimum Last Access Date - exclude files unused since n.
# /XF file [file]... :: eXclude Files matching given names/paths/wildcards.
# /XD dirs [dirs]... :: eXclude Directories matching given names/paths.
# e.g. /XD: `$RECYCLE.BIN

# robocopy specific log filename strings; initialized once, reused within robosync function :
$monthNames = (new-object system.globalization.datetimeformatinfo).MonthNames; # instantiate array of names of months
[string]$thisMonth = $monthNames[((Get-Date).Month-1)]; # Get the name of the current month by looking up get-date results in $monthNames (zero-based) array
$logFileDateString = get-date -UFormat '%Y%m%d';
$logFileName = "robosync-$logFileDateString.log";
$robocopyOptions = "/S /R:1 /W:1 /NS /NC /NP /LOG+:$loggingPath\$logFileName /TEE /XF `~`$* desktop.ini Win8RP-Pro-Boot.zip /XD log `$RECYCLE.BIN DAI ""Win8 ADK"" ""My Demos"" EIT KRosling SnagIt TFEM NO-SYNC";

if ($testMode) {
	# update log file name to specify test mode, and add /L switch to robocopy options to run in List Only mode (similar to what-if) 
	$robocopyOptions -replace "$logFileName", "robosync-test-$logFileDateString.log" *>$NULL;
	$robocopyOptions = $robocopyOptions, '/L' -join ' ';
}

# ======= ROBOSYNC FUNCTION =============
function Start-Robosync  {
    param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$true, HelpMessage='Specify path to source directory, can be UNC.')]
        [String[]]
        [alias('source','from')]
        [ValidateNotNullOrEmpty]
        $sourcePath,

        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$true, HelpMessage='Specify path to destination directory, can be UNC.')]
        [String[]]
        [alias('target','destination',to)]
        [ValidateNotNullOrEmpty]
        $destPath
    )

<#
Line 184: 		robosync "$HOMESHARE2\My Documents" "$env:HOMESHARE\My Documents\SAS";
Line 185: 		robosync "$HOMESHARE2\Favorites" "$env:HOMESHARE\Favorites";
Line 188: 		write-log "robosync Profile1 to LocalProfile" -verbose;
Line 189: 		robosync "$env:HOMESHARE\My Documents" "$env:USERPROFILE\Documents";
Line 190: 		robosync "$env:HOMESHARE\Favorites" "$env:USERPROFILE\Favorites";
Line 191: 		#robosync "$env:HOMESHARE\AppSenseData\Recent\Win7-2008" "$env:AppData\Microsoft\Windows\Recent";
Line 194: 		write-log "robosync LocalProfile to Profile1" -verbose;
Line 195: 		robosync "$env:USERPROFILE\Documents" "$env:HOMESHARE\My Documents";
Line 196: 		robosync "$env:USERPROFILE\Favorites" "$env:HOMESHARE\Favorites";
Line 197: 		robosync "$env:AppData\Microsoft\Windows\Recent $env:HOMESHARE\AppSenseData\Recent\Win7-2008";
Line 198: 		robosync "$env:USERPROFILE\Desktop $env:HOMESHARE\Desktop"; # Constrained to files smaller than 100 MB
Line 201: 		write-log "robosync Profile1 to Profile2 (favorites only)" -verbose;
Line 203: 		robosync """$env:HOMESHARE\Favorites\Links\GBCI IT"" ""$HOMESHARE2\Favorites\Links\GBCI IT""";
#>
	if ($destPath -imatch 'C:\\Users\\') {
		#unless cleanRemote, presume we're robo-syncing recently changed files from remote shares to local, so don't sync back anything that hasn't been touched in the past 90 days
		$robocopyOptions = $robocopyOptions, '/MAXLAD:90' -join ' ';
		if ($cleanRemote) {
			$robocopyOptions = $robocopyOptions, '/PURGE' -join ' ';
		}
	}
	if ($destPath -imatch 'Desktop') {
		#Constrain desktop items to be copied to < 100 MB
		$robocopyOptions = $robocopyOptions, '/MAX:1048576' -join ' ';
	}

	if ($destPath -imatch 'Favorites') {
		#Constrain desktop items to be copied to < 100 MB
		$robocopyOptions = $robocopyOptions, '/MAX:1048576' -join ' ';
	}

	write-log "# # # Robocopy $sourcePath $destPath $robocopyOptions";
	Start-Process robocopy.exe "$sourcePath $destPath $robocopyOptions" -wait -verb open  2> $loggingPath\robosync-errors.log 3> $loggingPath\robosync-warnings.log; # 3>&2 didn't work
	write-log "`t`t[spacer]`n";
}

# ======= MAIN BODY =====================
# Log start timestamp
Show-Progress 'Start';

# check if arguments / parameters were passed, to run a specific function
	 $args | ForEach-Object { switch ($PSItem) {
		'startup' {
			# when called from startup script, modify robosync options to cleanup destination content that has been removed from source
			[bool]$cleanRemote = $true; 
		} 
	}
}

# If in XenApp, sync server side, and then through 'remotely' mapped C: drive
# How do I detect if I'm in Citrix XenApp context or local PC OS?

# how do I back-up non-business files to F:\
# 1. make sure F: is writeable
# 2. sync select folders
$checkFS = Split-Path $PSScriptRoot | join-Path -ChildPath 'finished\read-write-unprotect.cmd' -Resolve;
if (Test-AdminPerms) {
	&  $checkFS;
} else {
	write-log 'Need to elevate privileges to proceed ... requesting admin credentials.' -verbose;
	write-debug  "start-process PowerShell.exe ""$checkFS"" -verb RunAs -NoNewWindow -PassThru -Wait -ErrorAction:SilentlyContinue" -verbose;
	start-process powershell.exe "$checkFS" -verb RunAs -Wait -ErrorAction:SilentlyContinue;
}

if (test-path -Path "$backupVolume" -IsValid) {
	write-log "Syncing scripts files to backup drive: $backupVolume";
	Start-Robosync "$env:USERPROFILE\Documents\Scripts" "$backupVolume\Scripts";
}

# Test for Profile1 = HOMESHARE
# RFE :: use $Home instead?
$erroractionpreference = 'Continue' # shows error message, but continue

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

# ======= THE END =================================
Show-Progress 'Stop';

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