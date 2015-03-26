<#
.SYNOPSIS
    PrinterFunctions Module contains functions that help make it easier to interact with printer ports via WMI (for backward compatability).
.DESCRIPTION
    PrinterFunctions.psm1 - Provides common functions for retrieving info and controlling printer settings

.EXAMPLE
    PS C:\>  Set-DefaultPrinter GBCI91_IT252
    Set's the default printer to GBCI91_IT252
.NOTES
    NAME        :  PrinterFunctions.psm1
    VERSION     :  1.0   
    LAST UPDATED:  3/20/2015
    AUTHOR      :  Bryan Dady
.LINK

#>
function Get-DefaultPrinter {
    Get-WmiObject -Class win32_printer -Filter "Default='True'" | format-table -Property Name,ShareName,SystemName,Default,Local,Network -AutoSize
}

function Get-LocalPrinters {
    Get-WmiObject -Class win32_printer -Filter "Local='True'" | format-table -Property Name,ShareName,SystemName,Default,Local,Network -AutoSize
}

function Get-NetworkPrinters {
    Get-WmiObject -Class win32_printer -Filter "Network='True'" | format-table -Property Name,ShareName,deviceID,SystemName,Default,Local,Network -AutoSize
}

function Set-DefaultPrinter  {
<#
.SYNOPSIS
Set your own default printer by specifying it's ShareName
.DESCRIPTION
Set-DefaultPrinter uses WMI to set the Default printer, specified by it's short, simple ShareName property. To list all available printers by ShareName, see the Get-NetworkPrinters or Get-LocalPrinters cmdlets.
.PARAMETER printerShareName
Specify the desired printers ShareName property
.EXAMPLE
PS C:\>  Set-DefaultPrinter GBCI91_IT252
Set's the default printer to GBCI91_IT252
.NOTES
NAME        :  Set-DefaultPrinter
VERSION     :  1.0   
LAST UPDATED:  3/20/2015
AUTHOR      :  GLACIERBANCORP\bdady
.INPUTS
None
.OUTPUTS
None
#>

    param (
        [String]
        $printerShareName
    )
    return (Get-WmiObject -Class win32_printer -Filter "ShareName='$printerShareName'").SetDefaultPrinter();
    
}

# Export-ModuleMember -function * -alias *