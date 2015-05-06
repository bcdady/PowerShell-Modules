#Requires -Version 3.0
Function Edit-Module {
<#
.SYNOPSIS
    This opens a spefied module file from the $env:PSModulePath in ISE
.DESCRIPTION
    This function uses Get-Module to retrieve a module from $env:PSModulePath and then
    it opens the module from that location into a new tab in ISE for editing. Wildcard
    characters that resolve to a single module are supported.
.EXAMPLE
    Edit-Module PowerShellISEModule
    Edit-Module PowerShellISEModule opens the PowerShellISEModule into a new tab in the
    ISE for editing 
.EXAMPLE
    Edit-Module PowerShellISE*
    Edit-Module PowerShellISE* opens the PowerShellISEModule into a new tab in the
    ISE for editing by using a wild card character for the module name
.PARAMETER NAME
    The name of the module. Wild cards that resolve to a single module are supported
.NOTES
    NAME:  Edit-Module
    AUTHOR: originally authored by ed wilson, msft
        edited by Bryan Dady to include Param support and FileType parameter, add support to edit imported modules as well as from ListAvailable
    LASTEDIT: 04/29/2015
    KEYWORDS: Scripting Techniques, Modules

.LINK
     Http://www.ScriptingGuys.com
 #Requires -Version 2.0
 #>
 [cmdletbinding()]
 Param(
     [Parameter(Mandatory=$true,
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        HelpMessage='Specify a module name to edit')
        ]
#     [ValidateScript({Get-Module -ListAvailable $PSItem})]
     [string[]]
     $Name,

     [Parameter(Mandatory=$false,
        Position=1,
        ValueFromPipeline=$false,
        ValueFromPipelineByPropertyName=$false,
        HelpMessage='Specify Script Module (.psm1), or manifest / Script Data file (.psd1) <optional>')
        ]
     [ValidateSet('ScriptModule','Manifest','Scripts','All')]
     [string[]]
     $FileType='ScriptModule'
 
 )

 # * RFE * Enhance Name parameter validation to autocomplete / intellisense available module names; at least for modules in -ListAvailable
 
 # powershell_ise.exe (Get-Module -ListAvailable $name).path
 # In PS 4 this original syntax (from the Edit-Module function provided by ed wilson) results in the Module Data file (.psd1), only
 # the following updates enable easy editing of both the Data file as well as as the Module script (.psm1), and other module member scripts

     # 1st we attempt to access an imported module
    $ModuleObj = (Get-Module $Name);

    # Test if we've got a valid module object, or if we need to try again with -ListAvailable
    if ($ModuleObj -ne $null) {
        Write-Debug "Obtained handle to module $ModuleObj.path";
    } else {
        Write-Debug "Unable to obtained object handle for a module named $Name";

        # try agin using ListAvailable
        $ModuleObj = (Get-Module -ListAvailable $Name);
        # Test if we've got a valid module object, or if we need to show that it can't be done
        if ($ModuleObj -ne $null) {
            Write-Debug "Obtained handle to module $ModuleObj.path";
        } else {
            Write-Warning -Message "Unable to obtained object handle for a module named $Name";
        }
    }
    
    # Now that we've got a valide module object to work with, we can pick the files we want to open in ISE
    if ($ModuleObj -ne $null) {
 
     # .Path property points to the .psd1 manifest file
     $ModDataFile   = $ModuleObj.Path 
 
     # By joining the Module Base path property with the name of the rootmodule, we can build a full path to the .psm1 module script
     $ModScriptFile = Join-Path -Path $ModuleObj.ModuleBase -ChildPath $ModuleObj.RootModule -Resolve -ErrorAction Stop;
 
    Write-Debug "`$FileType is $FileType"

    switch ($FileType) {
         'Manifest' {
            Write-Debug -Message "PowerShell_ISE.exe -File  $ModDataFile";
            & PowerShell_ISE.exe -File $ModDataFile;
         }
         'ScriptModule'   {
            Write-Debug -Message "PowerShell_ISE.exe -File  $ModScriptFile";
            & PowerShell_ISE.exe -File  $ModScriptFile;
         }
         'Scripts' {
            $ModuleObj.NestedModules | foreach {
                Write-Debug -Message "ISE [NestedModule] $PSItem" -Debug;
                # ($ModuleObj.NestedModules | Get-ChildItem).FullName
                & PowerShell_ISE.exe -File ($PSItem | Get-ChildItem).FullName;
            }
            $ModuleObj.scripts | foreach {
                Write-Debug -Message "ISE [script] $PSItem" -Debug;
                & PowerShell_ISE.exe -File $PSItem;
            }
         }
         'All' {
            Write-Debug -Message "Editing all module files and scripts for $ModuleObj" -Debug;
            & PowerShell_ISE.exe -File  $ModScriptFile;
            & PowerShell_ISE.exe -File $ModDataFile;
            $ModuleObj.NestedModules | foreach { & PowerShell_ISE.exe -File $PSItem.Path }
            $ModuleObj.scripts | foreach { & PowerShell_ISE.exe -File $PSItem.Path }

         }
     } # end switch block

    } else { 
        Write-Output 'Failed to locate path(s) to module files for editing.'
    }# end if ; no matching module found

} #end function Edit-Module

Export-ModuleMember -alias * -function * -variable *
