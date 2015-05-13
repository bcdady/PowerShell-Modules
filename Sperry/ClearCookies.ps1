    <#
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

    Show-Progress -msgAction Start -msgSource $MyInvocation.MyCommand.Name;
    $cookieFiles = @(Get-Childitem ([system.environment]::getfolderpath('cookies')) | Select-String -Pattern "$cookieURI" | Select-Object -Unique Path, Line); #  | Format-List -Property *

    if ($cookieFiles -ne $null) {
        $cookieFiles  | ForEach-Object {
            $cookieFiles += $PSItem
        }
    }
    Show-Progress -msgAction Stop -msgSource $MyInvocation.MyCommand.Name; # Log end timestamp
    return $cookieFiles;
}

# *** RFE : only process unique file paths. Currently 

function Clear-IECookies {
    param ( [String]$URL )

    Show-Progress -msgAction Start -msgSource $MyInvocation.MyCommand.Name; # Log start timestamp
    $URL = 'rubicon'
    Get-IECookies -cookieURI $URL | 
        ForEach-Object
        -Begin {check unique} 
        -Process {
            write-output "Remove-Item -Path $($PSItem.Path)"
            # Remove-Item -Path $PSItem.Path -Force;
        }
        -End {"we're done"}

    Show-Progress -msgAction Stop -msgSource $MyInvocation.MyCommand.Name; # Log end timestamp
}
