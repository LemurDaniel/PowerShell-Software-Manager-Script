function Install-UtilsSoftware {
    <#
    .SYNOPSIS
    Installs Software is use so I don't forget them in the future and quick install.

    .DESCRIPTION
    This function provides a console menu to install, upgrade or deinstall software packages using PowerShell modules, npm packages, or WinGet packages.

    .OUTPUTS
    
    .EXAMPLE

    .LINK
    
    #>

    

    param (
        [Parameter()]
        [switch]
        $Deinstall,

        # install npm packages locally instead of globally
        [Parameter()]
        [switch]
        $Local
    )

    <#
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// >> Install powershell-yaml module if not already installed
    //// >> Read available Package Managers from YAML files
    //// >> Setup: Install necessary Modules and load package lists from YAML files
        
    #>

    # >> Install powershell-yaml module if not already installed
    if ($null -EQ (Get-Module -Name powershell-yaml -ListAvailable)) {
        Write-Host -ForeGroundColor Magenta "Installing required Module 'powershell-yaml'"
        Install-Module -Name powershell-yaml -Repository PSGallery
    }

    # >> Read available Package Managers from YAML files
    $packageManager = Get-ChildItem -Path $PSScriptRoot -Filter "software.*.yaml" 
    | ForEach-Object {
        Get-Content -Path $_.FullName | ConvertFrom-Yaml
    }
    | Select-UtilsConsoleMenu -Display "displayName" -Description "Select Package Manager:"


    # >> Setup: Install necessary Modules and load package lists from YAML files
    if (
        $packageManager.id -EQ "winget" -AND
        $null -EQ (Get-Command -Module Microsoft.WinGet.Client -ErrorAction SilentlyContinue)
    ) {
        Write-Host -ForeGroundColor Magenta "Installing required Module 'Microsoft.WinGet.Client'"
        Install-Module -Name Microsoft.WinGet.Client -Repository PSGallery
        Import-Module -Name Microsoft.WinGet.Client

        $null = Read-Host "...Continue"
    }



    <#
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// >> Setup the Package Manager commands
    //// >> Wrapper function: Invoke Commands provided by package manager
    //// >> Wrapper function: Prepare Console Menu Options

    #>
    enum Operation {
        none
        install
        upgrade
        deinstall
    }

    function Invoke-Process {
        param (
            [System.String[]]$Commands
        )
        
        $programm = $Commands -join "`n"
        $arguments = @() + $packageManager.process.args
        $arguments += "$programm"

        return . $packageManager.process.path @arguments
    }

    function Invoke-PrepareConsoleMenuOptions {

        param(
            [Parameter()]
            [System.Object[]]
            $Items,

            [Parameter()]
            [System.Object]
            $installedPackages
        )

        foreach ($package in $Items) {

            if ($null -NE $package.category) {
                $package.display = ">> $($package.category)"
                $package.packages = Invoke-PrepareConsoleMenuOptions -Items $package.packages
                continue
            }

            $package.isInstalled = $package.id -IN $installed.id
            if ($package.isInstalled) {
                $package.version = $installed 
                | Where-Object -Property id -EQ $package.id 
                | Select-Object -ExpandProperty version
            }

            if ($Deinstall.IsPresent -AND -NOT $package.isInstalled) {
                $package.operation = [Operation]::none
                $package.display = "(Not installed) $($package.name) @-.-.-"
                $package.command = ""
            }
            elseif ($Deinstall.IsPresent -AND $package.isInstalled) {
                $package.operation = [Operation]::deinstall
                $package.display = "(Deinstall) $($package.name) @$($package.version)"
                $package.command = $package.deinstall ?? $packageManager.process.commands.deinstall
            }
            elseif ($package.isInstalled) {
                $package.operation = [Operation]::upgrade
                $package.display = "(Upgrade) $($package.name) @$($package.version)"
                $package.command = $package.update ?? $packageManager.process.commands.update
            }
            else {
                $package.operation = [Operation]::install
                $package.display = "(Install) $($package.name) @-.-.-"
                $package.command = $package.install ?? $packageManager.process.commands.install         
            }

            $package.command = $package.command.Replace('${id}', $package.id)
            $package.command = $package.command.Replace('${name}', $package.name)
            $package.command = $package.command.Replace('${version}', $package.version)
        }

        return $Items
    }



    <#
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// >> Retrieve installed packages via list command of selected Package Manager
    //// >> Prepare list of packages for Console Menu
            - All packages are sorted in categories which are handled as a tree structure.
            - Root category holds all level-0 packages and sub-categories.
            - Each sub-category holds its own packages or further sub-categories.
            
    //// >> Show Console Menu to select package
        
    #>

    do {
        
        $options = @()
        $options += @{
            id           = 'end'
            display      = "<< Exit >>"
            operation    = [Operation]::none
            ignoreSearch = $true
        }

        # >> Retrieve installed packages via list command of selected Package Manager
        Write-Host -ForeGroundColor Cyan "$($PackageManager.displayName) | Loading installed packages..."
        $installed = Invoke-Process -Commands $packageManager.process.commands.list | ConvertFrom-Json -AsHashtable

        # >> Prepare list of packages for Console Menu
        $options += Invoke-PrepareConsoleMenuOptions -Items $packageManager.packages -installedPackages $installed

        # >> Show Console Menu to select package
        $packageSelected = $options | Select-UtilsConsoleMenu -SubMenuProperty 'packages' -Description "Install via '$($PackageManager.displayName)':"

        # >> Leave the menu loop without further output
        if ($packageSelected.id -EQ "end") {
            break
        }



        <#
        //////////////////////////////////////////////////////////////////////////////////////////////////////////
        //// >> Perform Installation / Upgrade / Deinstallation via selected Package Manager
        
        #>

        # >> Perform Installation / Upgrade / Deinstallation via selected Package Manager
        if ($packageSelected.Operation -EQ [Operation]::none) {
            Write-Host -ForegroundColor Yellow "No valid package selected. Exiting..."
        }
        elseif ($packageSelected.Operation -EQ [Operation]::install) {
            Write-Host -ForegroundColor Green "Installing package '$($packageSelected.name)'..."
            Invoke-Process -Commands $packageSelected.command
        }
        elseif ($packageSelected.Operation -EQ [Operation]::upgrade) {
            Write-Host -ForegroundColor Green "Upgrading package '$($packageSelected.name)'..."
            Invoke-Process -Commands $packageSelected.command
        }
        elseif ($packageSelected.Operation -EQ [Operation]::deinstall) {
            Write-Host -ForegroundColor Green "Deinstalling package '$($packageSelected.name)'..."
            Invoke-Process -Commands $packageSelected.command
        }
        else {
            Write-Host -ForegroundColor Yellow "No valid Package selected. Exiting..."
        }

        $null = Read-Host "...Press any key"
        Clear-Host


    } while ($null -NE $packageSelected -AND $packageSelected.id -NE "end")

}
