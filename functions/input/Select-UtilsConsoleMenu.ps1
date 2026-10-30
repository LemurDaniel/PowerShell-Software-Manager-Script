function Select-UtilsConsoleMenu {
    <#
    .SYNOPSIS
    Write a Menue to the Console with interactive selection.

    .Title
    Write a Menue to the Console with interactive selection.

    Supports several Pages.
        => Switchable via Left- and Right-Keyboard Keys.

    Chosen Element is Highlighted.
        => Switchable via Up- and Down-Keyboard Keys.

    Wirting a Text highlights every entry with the specifed text.
        => Pressing Backspace will remove the last letter from the text.

    .OUTPUTS
    The Selected Item.



    .EXAMPLE

    Select a from the Current Path:
    
    PS> $selected = Get-ChildItem -File | Select-UtilsConsoleMenu -Display name


    .EXAMPLE

    Return only the fullname property of a file on the current path:
    
    PS> $selected = Get-ChildItem -File 
        | Select-UtilsConsoleMenu -Display Name -Return FullName


    .LINK
    
    #>

    

    [CmdletBinding()]
    param (
        <#
        [Required]
        The option to display in the menu.

        This can be any object type.
        When using complex objects
        - use -Display to specify the property to show in the menu
        - use -Return to specify the property to return from the function
          (by default the whole object is returned)
        
        You can add addtional properties to the objects for special purposes:
        - ignoreSearch: $true        | This item will always be shown, regardless of search filter
        - menu: [System.Object[]]    | When selected, will open a new submenu with the provided objects.
                                     | An Option to leaving to the previous menu is included automatically.
        #>
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [System.Object]
        $Options,

        # Additional header options to display above the menu.
        # These will be displayed on all pages and excluded from the search.
        # [Parameter()]
        # [System.Object[]]
        # $HeaderOptions = @(),

        <#
        [Optional]
        The title or prompt to display above the menu.
        By default, 'Please Choose from the Menu:' is used.
        #>
        [Parameter()]
        [System.String]
        # These are for backward compatibility
        [Alias('Prompt', 'Description')]
        $Title = 'Please Choose from the Menu:',

        <#
        [Optional]
        The property of the object to display in the menu.
        By default, the 'display' property is used.
        #>
        [Parameter()]
        [System.String]
        [Alias('Property')]
        $Display = 'display',

        <#
        [Optional]
        The property of the object to return from the function.
        By default, the whole object is returned.
        #>
        [Parameter()]
        [System.String]
        $Return,

        <#
        [Optional]
        Marks the name of the property that indicates whether an option is a menu.
        Items of that property open a new submenu when selected.
        By default, 'menu' is used.
        #>
        [Parameter()]
        [System.String]
        [Alias('SubMenus', 'SubMenuProperty')]
        $SubMenu = 'menu',

        <#
            Custom colors for the prompt and options.

            Provide a hashtable with the following keys.
            Each key is optional and $null will be replaced with the default value.
            - Page
                - ForeGround
                - BackGround
            - Select
                - ForeGround
                - BackGround
            - Search
                - ForeGround
                - BackGround
            - EvenLine
                - ForeGround
                - BackGround
            - UnevenLine
                - ForeGround
                - BackGround
            - Title
                - ForeGround
                - BackGround

            Following Colors are supported:
            - HEX: #FFFFFF
            - RGB: 255, 255, 255
            - ColorName: Colors in $PSStyle.ForeGround or $PSStyle.BackGround

            Example:
            @{
                Page        = @{ 
                    ForeGround = 'BrightBlack'
                    BackGround = 'White' 
                }
                Select      = @{ 
                    ForeGround = 'BrightWhite'
                    BackGround = 'BrightBlack'
                }
                Search      = @{ 
                    ForeGround = 'Cyan'
                    BackGround = $null 
                }
                EvenLine    = @{ 
                    ForeGround = 'BrightWhite'
                    BackGround = $null 
                }
                UnevenLine  = @{ 
                    ForeGround = 'BrightBlack'
                    BackGround = $null 
                }
                Title = @{ 
                    ForeGround = 'BrightWhite'
                    BackGround = $null 
                }
            }
        #>
        [Parameter()]
        [System.Collections.Hashtable]   
        $CustomColors = @{}
    )

    END {

        # Remove elements so we cann call UtilsConsoleMenuInternal with splatting
        $null = $PSBoundParameters.Remove('Options')
        $null = $PSBoundParameters.Remove('SubMenu')

        # '$Input' is a special variable in the END block.
        # It contains all the piped input objects as an array.
        $AllOptions = $Input ?? $Options

        $leaveSubmenuId = "leaveSubmenu-$([System.Guid]::NewGuid().ToString())"
        $currentMenu = $AllOptions
        $selectedItem = $null
        do {

            $result = $currentMenu | Select-UtilsConsoleMenuInternal @PSBoundParameters

            if ($null -NE $result."$SubMenu") {
                $backOption = @{}
                $backOption.id = $leaveSubmenuId
                $backOption.ignoreSearch = $true
                $backOption."$Display" = "<< Back to previous menu >>"
                $backOption.previousMenu = $currentMenu
                # Enter Submenu
                $currentMenu = @()
                $currentMenu += $backOption
                $currentMenu += $result."$SubMenu"
            }
            elseif ($result.id -EQ $leaveSubmenuId) {
                # Leave to previous menu
                $currentMenu = $result.previousMenu
            }
            else {
                $selectedItem = $result
            }

        } while ($null -EQ $selectedItem)

        return $selectedItem
    }

    # Not needed anymore
    # CLEAN {
    #     # The clean up function is NOT used, because the behaviour of execution is different,
    #     # - when the function exits by pressing Enter.
    #     # - when the function exits by throwing an exception.
    # }
}