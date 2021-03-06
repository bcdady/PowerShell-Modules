﻿<#
.SYNOPSIS
    PrinterFunctions Module contains functions that help make it easier to interact with printer ports via WMI (for backward compatability).
.DESCRIPTION
    PrinterFunctions.psm1 - Provides common functions for retrieving info and controlling printer settings

#>

function Get-Printer {
    [CmdletBinding()]
    [OutputType([int])]
    Param (
        # List Default printer
        [switch]
        $Default,

        # Enumerate only local printers
        [switch]
        $Local,

        # Enumerate only network printers
        [switch]
        $Network
    )
<#
.Synopsis
   Get-Printer retrieves details of printer ports
.DESCRIPTION
   Can enumerate default printer, local printers, and network printers
.EXAMPLE
   Get-Printer -Default

.EXAMPLE
   Get-Printer -Default

#>
    Show-Progress -msgAction Start -msgSource $PSCmdlet.MyInvocation.MyCommand.Name
    [string]$CIMfilter;

    if ($Default) { $CIMfilter = "Default='True'"; }
        
    elseif ($Local) { $CIMfilter = "Local='True'"; } 

    elseif ($Network) { $CIMfilter = "Network='True'"; } 

    # else  $CIMfilter remains $null, so returns all results

    Get-CimInstance -ClassName Win32_Printer -Filter $CIMfilter | format-table -Property Name,ShareName,SystemName,Default,Local,Network -AutoSize

    Show-Progress -msgAction Stop -msgSource $PSCmdlet.MyInvocation.MyCommand.Name
}

<#
Example of how to retrieve color capabilities, like Color, Duplex.
Also shows DriverName and print server name
Get-WmiObject -Class win32_printer -Filter "ShareName='GBCI02_IT223'" | format-list ShareName,Capabilities,CapabilityDescriptions,DriverName,ServerName

ShareName              : GBCI02_IT223
Capabilities           : {4, 2, 3, 5}
CapabilityDescriptions : {Copies, Color, Duplex, Collate}
DriverName             : TP Output Gateway
ServerName             : \\gbci02ps02

#>

function Set-Printer  {
<#
.SYNOPSIS
Set your own default printer by specifying it's ShareName
.DESCRIPTION
Set-Printer uses WMI to set the Default printer, specified by it's short, simple ShareName property. To list all available printers by ShareName, see the Get-NetworkPrinters or Get-LocalPrinters cmdlets.
.PARAMETER printerShareName
Specify the desired printers ShareName property
.EXAMPLE
PS C:\>  Set-Printer GBCI91_IT252
Set's the default printer to GBCI91_IT252
.NOTES
NAME        :  Set-Printer
VERSION     :  1.1
LAST UPDATED:  3/30/2015
AUTHOR      :  Bryan Dady

#>
    param (
        [String]
        $printerShareName
    )
    return (Get-WmiObject -Class win32_printer -Filter "ShareName='$printerShareName'").SetDefaultPrinter();
    
}

