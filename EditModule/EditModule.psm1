#Requires -Version 3.0
Function Edit-Module {
<#
.SYNOPSIS
    Opens a specified module file from the $env:PSModulePath in ISE
.DESCRIPTION
    This function uses Get-Module to retrieve a module from $env:PSModulePath and then
    it opens the module from that location into a new tab in ISE for editing. Wildcard
    characters that resolve to a single module are supported.

    Module properties changed in PowerShell v3, so the behavior of the original Edit-Module function (from Scripting Guy Ed Wilson's 'PowerShellISEModule')
    The following updates enable easy editing of both the Data file as well as as the Module script (.psm1), and other module member scripts
.EXAMPLE
    Edit-Module PowerShellISEModule
    Edit-Module PowerShellISEModule opens the PowerShellISEModule into a new tab in the ISE for editing 
.EXAMPLE
    Edit-Module PowerShellISE*
    Edit-Module PowerShellISE* opens the PowerShellISEModule into a new tab in the ISE for editing by using a wild card character for the module name
.PARAMETER NAME
    The name of the module. Wild cards that resolve to a single module are supported
.NOTES
    NAME:  Edit-Module
    AUTHOR: originally authored "by ed wilson, msft"
        edited by Bryan Dady to include Param support, FileType parameter, add support to edit imported modules as well as from ListAvailable
    LASTEDIT: 04/29/2015
    KEYWORDS: Scripting Techniques, Modules

.LINK
     Http://www.ScriptingGuys.com
 #>
 [cmdletbinding()]
 Param(
     [Parameter(Mandatory=$true,
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        HelpMessage='Specify a module name to edit')
        ]
     [ValidateScript({Get-Module -ListAvailable | Select-Object -Property Name})]
     [string[]]
     $Name,

     [Parameter(Mandatory=$false,
        Position=1,
        ValueFromPipeline=$false,
        ValueFromPipelineByPropertyName=$false,
        HelpMessage='Specify Script Module (.psm1), or manifest / Script Data file (.psd1) <optional>')
        ]
     [ValidateSet('Manifest','ScriptModule','Scripts','All')]
     [string[]]
     $FileType='Manifest'
 )

 # * RFE * Enhance Name parameter validation to autocomplete available module names; at least for modules in -ListAvailable

     # 1st we attempt to access an imported module
    $ModuleObj = (Get-Module -Name $Name);

    # Test if we've got a valid module object, or if we need to try again with -ListAvailable
    if ($ModuleObj -ne $null) {
        Write-Debug "Obtained handle to module $ModuleObj.path";
    } else {
        Write-Debug "Unable to obtain object handle for a module named $Name";

        # try agin using ListAvailable
        $ModuleObj = (Get-Module -ListAvailable $Name);
        # Test if we've got a valid module object, or if we need to show that it can't be done
        if ($ModuleObj -ne $null) {
            Write-Debug "Obtained handle to module $ModuleObj.path";
        } else {
            Write-Warning -Message "Unable to obtain object handle for a module named $Name";
        }
    }
    
    # Now that we've got a valid module object to work with, we can pick the files we want to open in ISE
    if ($ModuleObj -ne $null) {
 
        # Get the Module Type
        # "such as a script file or an assembly. This property is introduced in Windows PowerShell 2.0". 
        # https://msdn.microsoft.com/en-us/library/system.management.automation.psmoduleinfo.moduletype(v=vs.85).aspx
        if ($ModuleObj.ModuleType -eq 'Script') {
        # .Path property points to the .psm1 script module file "introduced in Windows PowerShell 3.0". - 
            # https://msdn.microsoft.com/en-us/library/microsoft.powershell.core.activities.testmodulemanifest_properties(v=vs.85).aspx
        $ModScriptFile   = $ModuleObj.Path 

        if ($ModScriptFile | Select-String -Pattern $env:ProgramFiles -SimpleMatch) {
            # Path to module is is Program Files, so the module can only be edited with local admin privileges
            [bool]$SharedModule = $true;
        }


        # Define and test for the psd1 data/manifest file
        $ModDataFile = Join-Path -Path $ModuleObj.ModuleBase -ChildPath "$($ModuleObj.Name).psd1" -Resolve -ErrorAction Stop;
        if (Test-Path -Path $ModDataFile -PathType Leaf -ErrorAction SilentlyContinue ) {
            Write-Debug -Message "PowerShell_ISE.exe -File  $ModDataFile";
            Write-Output -InputObject "`nOpening Module Manifest $($ModuleObj.Name) (.psd1), version $($ModuleObj.Version.ToString())`n`n`tPlease update the Version and Help Comments to reflect any changes made."
            Start-Sleep -Seconds 3;
         }
        if ($SharedModule) {Open-AdminISE -File $ModDataFile;}
        else { & PowerShell_ISE.exe -File $ModDataFile; }        

    } else {
        Write-Log -Message "Unexpected ModuleType is $($ModuleObj.ModuleType)" -Function $MyInvocation.MyCommand.Name -Verbose
    }
 
        # By joining the Module Base path property with the name of the rootmodule, we can build a full path to the .psm1 module script
    #       $ModScriptFile = Join-Path -Path $ModuleObj.ModuleBase -ChildPath $ModuleObj.RootModule -Resolve -ErrorAction Stop;

        Write-Debug "`$FileType is $FileType";

        switch ($FileType) {
         'ScriptModule'   {
            Write-Debug -Message "PowerShell_ISE.exe -File  $ModScriptFile";
            if ($SharedModule) {Open-AdminISE -File $ModScriptFile;}
            else { & PowerShell_ISE.exe -File $ModScriptFile; }
         }
         'Scripts' {
            $ModuleObj.NestedModules | foreach {
                Write-Debug -Message "ISE [NestedModule] $PSItem";
                # ($ModuleObj.NestedModules | Get-ChildItem).FullName
                if ($SharedModule) { Open-AdminISE -File ($PSItem | Get-ChildItem).FullName; }
                else { & PowerShell_ISE.exe -File ($PSItem | Get-ChildItem).FullName; }
            }
            $ModuleObj.scripts | foreach {
                Write-Debug -Message "ISE [script] $PSItem";
                if ($SharedModule) { Open-AdminISE -File  $PSItem.Path; }
                else { & PowerShell_ISE.exe -File $PSItem.Path; }
            }
         }
         'All' {
            Write-Debug -Message "Editing all module files and scripts for $ModuleObj";
            if ($SharedModule) {
                Open-AdminISE -File  $ModScriptFile;
                Open-AdminISE -File $ModDataFile;
                $ModuleObj.NestedModules | foreach { Open-AdminISE -File $PSItem.Path }
                $ModuleObj.scripts | foreach { Open-AdminISE -File $PSItem.Path }
            } else { 
                & PowerShell_ISE.exe -File  $ModScriptFile;
                & PowerShell_ISE.exe -File $ModDataFile;
                $ModuleObj.NestedModules | foreach { & PowerShell_ISE.exe -File $PSItem.Path }
                $ModuleObj.scripts | foreach { & PowerShell_ISE.exe -File $PSItem.Path }
            }
          }
        } # end switch block

    } else { 
        Write-Output 'Failed to locate path(s) to module files for editing.'
    }# end if ; no matching module found

} #end function Edit-Module

function Open-AdminISE {
<#
.SYNOPSIS
    Launch a new PowerShell ISE window, with Admin priveleges
.DESCRIPTION
    Simplifies opening a PowerShell ISE editor instance, with Administrative permissions, from the console / keyboard, instead of having to grab the mouse to Right-Click and select 'Run as Administrator'
#>
 [cmdletbinding()]
 Param(
     [Parameter(Mandatory=$true,
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        HelpMessage='Specify a module name to edit')
       ]
     [ValidateScript({Resolve-Path -Path $PSItem})]
     [Alias('FilePath','Module','Path')]
     [string[]]
     $File
 )

    Start-Process -FilePath "$PSHOME\powershell_ise.exe" -ArgumentList "-File $File" -Verb RunAs -WindowStyle Normal;
}

New-Alias -Name Open-AdminEditor -Value Open-AdminISE -ErrorAction Ignore;

Export-ModuleMember -function * -Alias *
