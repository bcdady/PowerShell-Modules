#Requires -Version 3.0
Function Edit-Module {
<#
.SYNOPSIS
    Opens a specified PowerShell module, for editing, in the ISE
.DESCRIPTION
    This function uses the Get-Module cmdlet to search for and retrieve information about a module (expected / available in $env:PSModulePath ) and then
    it opens the module from that location into a new tab in ISE for editing. Wildcard characters that resolve to a single module are supported. This function always opens the manifest file to be edited, and prompts/encourages the user/editor to update the ModuleVersion. Additional Module files such as the RootModule / module script (.psm1), and 

    PowerShell Module properties changed in PowerShell v3, and so the behavior of the original Edit-Module function (from Scripting Guy Ed Wilson's 'PowerShellISEModule') also changed. The following updates are intended to enable easy editing of both the Data (Manifest) file as well extending similar ease of use for editing the Module script (.psm1), and other scripts included in a Module.

    If the Module is installed into a shared file system path (e.g. $env:ProgramFiles), Edit-Module will attempt to open the ISE with elevated permissions, which are necesarry to edit a Module in place. If the user/editor cannot gain elevated permissions, then the ISE will open the module file(s) with read-only rights.
.EXAMPLE
    Edit-Module PowerShellISEModule
    Edit-Module PowerShellISEModule opens the PowerShellISEModule into a new tab in the ISE for editing 
.EXAMPLE
    Edit-Module PowerShellISE*
    Edit-Module PowerShellISE* opens the PowerShellISEModule into a new tab in the ISE for editing by using a wild card character for the module name
.PARAMETER NAME
    The name of the module. Wild cards that resolve to a single module are supported.
.NOTES
    NAME:  Edit-Module
    AUTHOR: originally authored "by ed wilson, msft"
        edited by Bryan Dady to extend PowerShell v3 functionality. Enhanceemnts include Param support, a new FileType parameter, support to edit modules imported into the active session as well as from -ListAvailable. Also adds ability to search for a Module by function name, and opening files in an elevated ISE session as necesarry.
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
     $FileType='ScriptModule'
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


            # Define and test for the .psd1 script data / manifest file
            $ModDataFile = Join-Path -Path $ModuleObj.ModuleBase -ChildPath "$($ModuleObj.Name).psd1" -Resolve -ErrorAction Stop;
            if (Test-Path -Path $ModDataFile -PathType Leaf -ErrorAction SilentlyContinue ) {
                Write-Debug -Message "PowerShell_ISE.exe -File  $ModDataFile";
                Write-Output -InputObject "`nOpening Module Manifest $($ModuleObj.Name) (.psd1), version $($ModuleObj.Version.ToString())`n`n`tPlease update the Version and Help Comments to reflect any changes made."
                Start-Sleep -Seconds 3;
             }
            # This function always opens the manifest to be edited, and prompts/encourages the user/editor to update the ModuleVersion.
            if ($SharedModule) { Open-AdminISE -File $ModDataFile; }
            else { & PowerShell_ISE.exe -File $ModDataFile; }        

        } else {
            Write-Log -Message "Unexpected ModuleType is $($ModuleObj.ModuleType)" -Function $MyInvocation.MyCommand.Name -Verbose
        }
 
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

function Find-Function {
    Param (

        [Parameter(Mandatory=$true, Position=0)]
        [String[]]
        $SearchPattern,

        # Use SimpleMatch (non RegEx) behavior in Select-String
        [Parameter(Mandatory=$false, Position=1)]
        [switch]
        $SimpleMatch = $false

    )
<#
    .SYNOPSIS
        Returns Module details, to which a specified function belongs.
    .DESCRIPTION
        Uses Get-Module and Select-String to find the RootModule which provides a specified ExportedCommand / Function name.
    .EXAMPLE
        PS C:\> Find-Function -SearchPattern 'Edit*'

        ModuleName   : Edit-Module
        FunctionName : EditModule
    .NOTES
        NAME        :  Find-Function
        VERSION     :  1.0.1
        LAST UPDATED:  6/25/2015
        AUTHOR      :  Bryan Dady
    .INPUTS
    None
    .OUTPUTS
    Write-Log
#>

    New-Variable -Name OutputObj -Description 'Object to be returned by this function' -Scope Private
    Get-Module -ListAvailable | Select-Object -Property Name,ExportedCommands | 
    ForEach-Object {
        # find and return only Module/function details where the pattern is matched in the name of the function
        if ($PSItem.ExportedCommands.Keys | Select-String -Pattern $SearchPattern) {
            # Optimize New-Object invokation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx

            $Private:properties = @{
                'ModuleName'   = $PSItem.Name;
                'FunctionName' = $PSItem.IPAddress;
            }
            $Private:RetObject = New-Object –TypeName PSObject –Prop $properties

        return $RetObject; # $OutputObj;
        
        } # end if
    } # end of foreach
} # end function Find-Function

Export-ModuleMember -function * -Alias *
