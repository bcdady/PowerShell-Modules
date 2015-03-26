﻿    <#
    .SYNOPSIS
    Examines current Internet Explorer cookies by source site (URL) and clears those that contain a matching URL
    .DESCRIPTION
    Enumerates all IE cookie text files, searches their content for a string match of the URL parameter, and if matched, deletes the cookie file
    .PARAMETER $URL
    Provide the domain / URL string you'd like to match, when searching for cookies to be cleared
    .EXAMPLE
    PS C:\> Clear-Cookies msn.com
    Clears (deletes) all cookie files that contain the text 'msn.com'
    .NOTES
        NAME        :  Clear-Cookies
        VERSION     :  1.0   
        LAST UPDATED:  3/20/2015
        AUTHOR      :  Bryan Dady
    .INPUTS
    None
    .OUTPUTS
    None
    #>
#Requires -Version 3.0 -Modules PSLogger
function Get-IECookies {
    param (
        [Parameter(
            Mandatory=$true,
            Position=0,
            ValueFromPipeline=$false,
            ValueFromPipelineByPropertyName=$true,
            HelpMessage='Specify web site to search within cookies for. Accepts any string, including wildcards.')]
        [ValidateNotNullOrEmpty()]
        [alias('address','site','URL')]
        [String]
        $cookieURI
        
    )
    Show-Progress 'Start'; # Log start timestamp
    $cookieFiles = @(Get-Childitem ([system.environment]::getfolderpath('cookies')) | Select-String -Pattern "$cookieURI" | Select-Object -Unique Path, Line); #  | Format-List -Property *

    if ($cookieFiles -ne $null) {
        $cookieFiles  | ForEach-Object {
            $cookieFiles += $PSItem
        }
    }
    Show-Progress 'Stop'; # Log end timestamp
    return $cookieFiles;
}

function Clear-IECookies {
    param ( [String]$URL )

#    Show-Progress 'Start'; # Log start timestamp
    Get-IECookies -cookieURI $URL | ForEach-Object {
        write-output "Remove-Item -Path $($PSItem.Path)"
        Remove-Item -Path $PSItem.Path -Force;
    }
#    Show-Progress 'Stop'; # Log end timestamp
}
