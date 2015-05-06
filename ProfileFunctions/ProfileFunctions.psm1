<#
.SYNOPSIS
    ProfileFunctions Module contains functions that are easily re-used across all PowerShell profiles
.DESCRIPTION
    ProfileFunctions.psm1 - Stores common functions for customizing PowerShell Console AND ISE profiles
.NOTES
    File Name   : ProfileFunctions.psm1
    Author      : Bryan Dady
    Link Note   : Some functions originally inspired by zerrouki
.LINK
    http://www.zerrouki.com/powershell-profile-example/
#>

function New-Profile {
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
    [CmdletBinding()]
    [OutputType([int])]
    Param (
        # Specifies which profile to edit; if not specified, ise presumes $profile means Microsoft.PowerShellISE_profile.ps1
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateSet('AllUsersAllHosts','AllUsersCurrentHost','CurrentUserAllHosts','CurrentUserCurrentHost')]
        $profileName
    )    # If a $profile's not created yet, create the profile file
    if (!(test-path $profile)) 
        {$new_profile = new-item -type file -path $profile.$profileName} # ;  -force}

$profile_string_content = @'
# PowerShell $Profile
# Created by New-Profile cmdlet in ProfileFunctions module

Write-Output "Loading PowerShell `$Profile: $PSCommandPath`n";

# Load / import ProfileFunctions Module
write-output "`nloading ProfileFunctions"; import-module ProfileFunctions -verbose;


if (![bool](Get-Alias rdp)) {
    # rdp alias not yet set, so let's add it
    New-Alias -Name rdp -Value Start-RemoteDesktop
}

Set-WindowTitle;
Set-PSprompt;

write-output "`nCurrent PS execution policy is: "; Get-ExecutionPolicy;

write-output '`nTo view additional available modules, run: Get-Module -ListAvailable';
write-output '`nTo view cmdlets available in a give module, run: Get-Comand -Module <ModuleName>';


'@

    # write the profile content into the new file
    Add-Content -Value $profile_string_content -Path $new_profile; # -PassThru
}
[Boolean]$FrameTitleDefault;
[string]$defaultFrameTitle;

function Get-WindowTitle {
    # store default host windows title
    if ($FrameTitleDefault) { $defaultFrameTitle = $Host.UI.RawUI.WindowTitle }
}

function Set-WindowTitle {
    $FrameTitleDefault = $true;
    Get-WindowTitle
    $hosttime = (Get-ChildItem $pshome\PowerShell.exe).creationtime;
    [string]$hostVersion = $Host.version;
    [string]$titlePWD    = Get-Location;
    $TitleText = 'PowerShell'
    if (Test-AdminPerms) {$TitleText = 'PowerShell (Admin)'}
    $Host.UI.RawUI.WindowTitle = "$TitleText $hostVersion - $titlePWD [$hosttime]";
    $FrameTitleDefault = $false;
#    clear-host;
}

function Reset-WindowTitle {
    $Host.UI.RawUI.WindowTitle = $defaultFrameTitle;
}

function Set-PSprompt {
 'PS $> '
}

function New-AdminConsole {
    start-process powershell.exe '-noprofile' -Verb RunAs -Wait
}

New-Alias -Name adminShell -Value New-AdminConsole -ErrorAction Ignore

New-Alias -Name adminHost -Value New-AdminConsole -ErrorAction Ignore

New-Alias -Name sudo -Value New-AdminConsole -ErrorAction Ignore


function Reset-Profile {
    . $Profile
}

function Test-AdminPerms {
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] 'Administrator')
}

function Start-RemoteDesktop  {
    param (
        [ValidateNotNullOrEmpty]
        [String]
        $RemoteServer
    )

    # thanks zerrouki! http://www.zerrouki.com/powershell-profile-example/

    Start-Process -FilePath mstsc.exe -ArgumentList "/admin /v:$RemoteServer /fullscreen"; # /w:1024 /h:768
}

function Test-Port {
    [cmdletbinding()]
    param(
        [parameter(mandatory=$true)]
        [string]$Target,
        [parameter(mandatory=$true)]
        [int32]$Port,
        [int32]$Timeout=2000
    )
    $outputobj=New-Object -TypeName PSobject;
    $outputobj | Add-Member -MemberType NoteProperty -Name TargetHostName -Value $Target;
    if(Test-Connection -ComputerName $Target -Count 2) {
        $outputobj | Add-Member -MemberType NoteProperty -Name TargetHostStatus -Value 'ONLINE';
    } else {
        $outputobj | Add-Member -MemberType NoteProperty -Name TargetHostStatus -Value 'OFFLINE';
    } 
    $outputobj | Add-Member -MemberType NoteProperty -Name PortNumber -Value $Port;
    $Socket=New-Object System.Net.Sockets.TCPClient;
    $Connection=$Socket.BeginConnect($Target,$Port,$null,$null);
    $Connection.AsyncWaitHandle.WaitOne($timeout,$false) | Out-Null;
    if($Socket.Connected -eq $true) {$outputobj | Add-Member -MemberType NoteProperty -Name ConnectionStatus -Value 'Success';
    } else {
        $outputobj | Add-Member -MemberType NoteProperty -Name ConnectionStatus -Value 'Failed';
    }
    $Socket.Close | Out-Null;
    $outputobj | Select-Object TargetHostName, TargetHostStatus, PortNumber, Connectionstatus | Format-Table -AutoSize;
}
 
function Get-ArchiveContent {
    param (
        [String]
        $archiveFile
    )
#        [ValidateScript]    [string]$zipExe = 'C:\SWTOOLS\PortableApps\7-ZipPortable\App\7-Zip64\7z.exe'; # --help

<#Usage: 7z <command> [<switches>...] <archive_name> [<file_names>...]
       [<@listfiles...>]

<Commands>
  a: Add files to archive
  b: Benchmark
  d: Delete files from archive
  e: Extract files from archive (without using directory names)
  l: List contents of archive
  t: Test integrity of archive
  u: Update files to archive
  x: eXtract files with full paths
<Switches>
  -ai[r[-|0]]{@listfile|!wildcard}: Include archives
  -ax[r[-|0]]{@listfile|!wildcard}: eXclude archives
  -bd: Disable percentage indicator
  -i[r[-|0]]{@listfile|!wildcard}: Include filenames
  -m{Parameters}: set compression Method
  -o{Directory}: set Output directory
  -p{Password}: set Password
  -r[-|0]: Recurse subdirectories
  -scs{UTF-8 | WIN | DOS}: set charset for list files
  -sfx[{name}]: Create SFX archive
  -si[{name}]: read data from stdin
  -slt: show technical information for l (List) command
  -so: write data to stdout
  -ssc[-]: set sensitive case mode
  -ssw: compress shared files
  -t{Type}: Set type of archive
  -u[-][p#][q#][r#][x#][y#][z#][!newArchiveName]: Update options
  -v{Size}[b|k|m|g]: Create volumes
  -w[{path}]: assign Work directory. Empty path means a temporary directory
  -x[r[-|0]]]{@listfile|!wildcard}: eXclude filenames
  -y: assume Yes on all queries
#>
    # extract all contents, in directories, from $archiveFile
    Start-Process -FilePath $zipExe -ArgumentList "x $archiveFile";
}

#if (![bool](Get-Alias unzip)) {
    # unzip alias not yet set, so we add it
    New-Alias -Name unzip -Value Get-ArchiveContent -ErrorAction Ignore
#}
 
function tail ($file) {
    Get-Content $file -Wait;
}
 
function Get-UserName {
    [System.Security.Principal.WindowsIdentity]::GetCurrent().Name;
}

#if (![bool](Get-Alias whoami)) {
    # whoami alias not yet set, so we add it
    New-Alias -Name whoami -Value Get-UserName -ErrorAction Ignore
#}

function Edit-Profile {
<#
.Synopsis
   Open a PowerShell Profile script in the ISE editor
.DESCRIPTION
   Edit-Profile will attempt to open any existing PowerShell Profile scripts, and if none are found, will offer to invoke the New-Profile cmdlet to build one
   Both New-Profile and Edit-Profile can open any of the 4 contexts of PowerShell Profile scripts.
.PARAMETER ProfileName
    Accepts 'CurrentUserCurrentHost', 'CurrentUserAllHosts', 'AllUsersCurrentHost' or 'AllUsersAllHosts'
.EXAMPLE
   Edit-Profile
   Opens the default $profile script file, if it exists
.EXAMPLE
   Edit-Profile CurrentUserAllHosts
   Opens the specified CurrentUserAllHosts $profile script file, which applies to both Console and ISE hosts, for the current user
#>
    [CmdletBinding()]
    [OutputType([int])]
    Param (
        # Specifies which profile to edit; if not specified, ise presumes $profile means Microsoft.PowerShellISE_profile.ps1
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateSet('AllUsersAllHosts','AllUsersCurrentHost','CurrentUserAllHosts','CurrentUserCurrentHost')]
        $profileName
    )
    Begin {
        if ($profileName) {
            # If a profile was specified, and it exists, open it
            
            # If it doesn't exist, offer to create it
            if (Test-Path $profileName -ErrorAction SilentlyContinue) {
                # file exists, so we can pass it on to be opened
                $openProfile = $profileName;
            } else {
                # Specified file doesn't exist, so we offer to make it; fortunatley we have a function that helps with that
                New-Profile $profileName
            }
        }
        # otherwise, test for an existing profile, in order of most specific, to most general scope
        elseif (test-path $PROFILE -ErrorAction SilentlyContinue) {
            $openProfile = $PROFILE;
        } elseif (test-path $PROFILE.CurrentUserCurrentHost -ErrorAction SilentlyContinue) {
            $openProfile = $PROFILE.CurrentUserCurrentHost;
        } elseif (test-path $PROFILE.CurrentUserAllHosts -ErrorAction SilentlyContinue) {
            $openProfile = $PROFILE.CurrentUserAllHosts;
        } elseif (test-path $PROFILE.AllUsersCurrentHost -ErrorAction SilentlyContinue) {
            $openProfile = $PROFILE.AllUsersCurrentHost;
        } elseif (test-path $PROFILE.AllUsersAllHosts -ErrorAction SilentlyContinue) {
            $openProfile = $PROFILE.AllUsersAllHosts;
        }
    }

    Process {
        # if a profile is specified, and found, then we open it.
        if ($openProfile) {
            & powershell_ise.exe $openProfile;
        } else {
            Write-Warning 'Profile not found. Consider running New-Profile to create a ready-to-use profile script.';
        }
    }
    
}

Export-ModuleMember -function * -alias *