#Requires -Version 7.2

<#
.SYNOPSIS
Interactive console menu to install, upgrade or deinstall software (winget, npm, PowerShell modules, dnf).

.DESCRIPTION
Entry point of the repo. Loads the functions and starts the menu.
The package lists live in 'functions/software/Software.*.yaml' - edit them to fit your needs.

.EXAMPLE
PS> ./software-manager.ps1

.EXAMPLE
PS> ./software-manager.ps1 -Deinstall
#>

[CmdletBinding()]
param (
    # Show deinstall instead of install/upgrade options
    [Parameter()]
    [switch]
    $Deinstall
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/functions/input/#Select-UtilsConsoleMenuInternal.ps1"
. "$PSScriptRoot/functions/input/Select-UtilsConsoleMenu.ps1"
. "$PSScriptRoot/functions/software/Install-UtilsSoftware.ps1"

Install-UtilsSoftware -Deinstall:$Deinstall
