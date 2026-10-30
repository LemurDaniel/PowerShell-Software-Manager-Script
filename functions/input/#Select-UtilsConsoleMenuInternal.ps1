function Select-UtilsConsoleMenuInternal {
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

    BEGIN {
        function Convert-Color {
            param(
                [System.Object] $Color,
                [System.String] $Type
            )

            if ($null -EQ $Color) {
                return $null
            }

            if ($Color -IS [System.String] -AND $Color.startswith('#')) {
                $Color = [System.Convert]::FromHexString($Color.substring(1))
            }

            if (-NOT ($Color -IS [System.String])) {
                $COLORS_24BIT = @{
                    FOREGROUND = "`e[38;2;{0};{1};{2}m"
                    BackGround = "`e[48;2;{0};{1};{2}m"
                }
        
                return $COLORS_24BIT."$Type" -f $Color[0], $Color[1], $Color[2]
            }


            if ($null -EQ $PSStyle."$Type"."$Color") {
                throw [System.InvalidOperationException]::new("The provided color '$Color' is not a valid color.")
            }
            else {
                return $PSStyle."$Type"."$Color"
            }      
        }

        # These are default colors, which can be overridden by custom colors.
        $transformedColors = @{
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

        $difference = $CustomColors.Keys | Where-Object { $_ -NOTIN $transformedColors.Keys }
        if ($difference.Count -GT 0) {
            throw [System.InvalidOperationException]::new("`nOn CustomColors, the following keys are not valid: $difference.`nPlease use the following keys: $($transformedColors.Keys)")
        }

        foreach ($key in $transformedColors.Keys) {
            
            $difference = $CustomColors[$key].Keys | Where-Object { $_ -NOTIN 'ForeGround', 'BackGround' }
            if ($difference.Count -GT 0) {
                throw [System.InvalidOperationException]::new("`nOn Custom Color for '$Key', the following keys are not valid: $difference`nPlease use the following keys: 'ForeGround', 'BackGround'")
            }

            $fg = $CustomColors[$key].ForeGround ?? $transformedColors[$key].ForeGround
            $transformedColors[$key].ForeGround = Convert-Color -Color $fg -Type 'ForeGround'

            $bg = $CustomColors[$key].BackGround ?? $transformedColors[$key].BackGround
            $transformedColors[$key].BackGround = Convert-Color -Color $bg -Type 'BackGround'
        }
        
        <#
            Setting up the default colors for the prompt, input and error message.
        #>
        $_Color_Reset_ = $PSStyle.Reset 
        $_linebreak_ = [System.Environment]::NewLine

        $_Color_Page_ = '' + $transformedColors.Page.ForeGround + $transformedColors.Page.BackGround
        $_Color_Select_ = '' + $transformedColors.Select.ForeGround + $transformedColors.Select.BackGround
        $_Color_Search_ = '' + $transformedColors.Search.ForeGround + $transformedColors.Search.BackGround
        $_Color_EvenLine_ = '' + $transformedColors.EvenLine.ForeGround + $transformedColors.EvenLine.BackGround
        $_Color_UnevenLine_ = '' + $transformedColors.UnevenLine.ForeGround + $transformedColors.UnevenLine.BackGround
        $_Color_Title_ = '' + $transformedColors.Title.ForeGround + $transformedColors.Title.BackGround


        <#

            ////////////////////////////////////////////////////////////////////
            ///// Setting up variables for the menu.
        #>
        # Customization of the menue.
        $print = @{
            shortendSuffix    = '... '
            prefixSelected    = ' => '
            prefixNonSelected = '    '
        }
                
        # The transformed selection options, appearing in the entry list.
        $SelectionOptions = @()

        # index of the entry in the current page.
        $currentSelectionIndex = 0
        # index of currently selected page.
        $currentPageIndex = 0

        # The current search string, when the user types something.
        $searchString = ''


        # The reserved lines above and below the entries.
        # These are substracted from the selection height.
        # - 2 for the Title line + linebreak
        # - 2 for the page menue + linebreak
        # - Additional 5 for good measure.
        $reservedLines = 9

        $reservedWidth = [System.Math]::Max($print.prefixSelected.length, $print.prefixNonSelected.length) + 4
        $initialSelectionWitdh = $Host.UI.RawUI.BufferSize.Width - $reservedWidth - $print.shortendSuffix.Length
        $initialSelectionHeight = [System.Math]::Max($Host.UI.RawUI.BufferSize.Height, 10)

        # This is the number of options that can be displayed on a single page, which decides the number of pages.
        $pageSelectionLimit = $initialSelectionHeight - $reservedLines

        if ($PSBoundParameters.ContainsKey('HeaderOptions')) {
            # TODO: Implement HeaderOptions
            # This is a placeholder for the header options.
            throw [System.NotImplementedException]::new("HeaderOptions are not implemented yet.")
        }


        <#
        
            ////////////////////////////////////////////////////////////////////
            ///// Clearing the host and setting up the console.

            Clearing the entire console causes a lot of flickering.
            Currently Clear-Host is only performed:
            - On initial draw of the menu.
        #>

        Clear-Host

        # Save existing value and change it to true.
        $TreatControlCAsInput = [System.Console]::TreatControlCAsInput
        [System.Console]::TreatControlCAsInput = $true
        $cursorTopPosition = [System.Numerics.Vector2]::new(
            [System.Console]::GetCursorPosition().Item1,
            [System.Console]::GetCursorPosition().Item2
        )

    }

    PROCESS {
        <#
            If the user provided the object as a parameter,
            we pipe it to a new instance of the function.
        #>
        if (-NOT $PSCmdlet.MyInvocation.ExpectingInput) {
            $null = $PSBoundParameters.Remove('Options')
            return $Options | Select-UtilsConsoleMenu @PSBoundParameters
        }

        
        if (
            -NOT ($Options -IS [System.String]) -AND 
            -NOT ($Options -IS [System.ValueType])
        ) {
            if (
                -NOT [System.String]::IsNullOrEmpty($Return) -AND
                [System.String]::IsNullOrEmpty($Options."$Return")    
            ) {
                throw [System.InvalidOperationException]::new("`nThe provided object does not contain a property with the name '$Return'.`nUse the -Return parameter to specify a custom property name.`n")
            }

            if (
                -NOT [System.String]::IsNullOrEmpty($Display) -AND
                [System.String]::IsNullOrEmpty($Options."$Display")    
            ) {
                throw [System.InvalidOperationException]::new("`nThe provided object does not contain a property with the name '$Display'.`nUse the -Display parameter to specify a custom property name.`n")
            }
        }

        $SelectionOptions += @{
            name         = $Options."$Display" ?? $Options
            returnValue  = $Options."$Return" ?? $Options
            ignoreSearch = $Options.ignoreSearch ?? $false
        }

    }

    END {
        if (-NOT $PSCmdlet.MyInvocation.ExpectingInput) {
            return
        }

        <#
        
            ////////////////////////////////////////////////////////////////////
            ///// Helper Functions
            
        #>
        
        <#
            When updating the menue most component are automatically overdrawn.
            This makes the need for an entire console clear unnecessary.
        
            However there are special cases to be considered:
            - Different text lengths of entries in the list.
            - On the last page the page menue and search menue may be drawn at different positions.
            - We want to undraw the search menue, when the search string is empty.

        #>
        $lastDrawnPositions = @{
            Title = $null
            pageMenu    = $null
            searchMenue = $null
            entries     = @()
        }
        function Save-Position {
            param (
                [System.String] $Text,
                [System.Int32] $LineBreaks = 0
            )

            return @{
                Length = $Text.Length
                Cursor = [System.Numerics.Vector2]::new(
                    [System.Console]::GetCursorPosition().Item1,
                    [System.Console]::GetCursorPosition().Item2 + $LineBreaks
                )
            }
        }

        <#
            Undraws components when required, to avoid whole clear-Host calls.
            It avoids nearly all flickering on the console menue.
        #>
        function Invoke-Clear {
            [CmdletBinding()]
            param (
                [Parameter(ValueFromPipeline = $true)]    
                [System.Object] 
                $LastDrawn
            )
            
            BEGIN {
                $saveCursorX = [System.Console]::GetCursorPosition().Item1
                $saveCursorY = [System.Console]::GetCursorPosition().Item2
            }

            PROCESS {
                if ($null -EQ $LastDrawn) {
                    return
                }

                # Clear the line at the specified cursor position.
                [System.Console]::SetCursorPosition($LastDrawn.Cursor.X, $LastDrawn.Cursor.Y)
                [System.Console]::Write(" " * $LastDrawn.Length)
            }

            END {
                # Reset cursor position to the original position.
                [System.Console]::SetCursorPosition($saveCursorX, $saveCursorY)
            }
        }

        <#
            This function is used to clean up the console when the user:
            - Presses ESC or CTRL+C.
            - Presses Enter to select an option.
        #>
        function Invoke-ClearUpAll {
            # Make sure to always leave in any case function with a visible cursor again.
            [System.Console]::CursorVisible = $true 
            [System.Console]::TreatControlCAsInput = $TreatControlCAsInput

            <#
            Revert the cursor position and undraw the entire menue.

            This is in case the function exits by NOT pressing Enter.
        #>
            $lastDrawnPositions.pageMenu | Invoke-Clear
            $lastDrawnPositions.searchMenue | Invoke-Clear
            $lastDrawnPositions.Title | Invoke-Clear
            $lastDrawnPositions.entries | Invoke-Clear
            [System.Console]::SetCursorPosition(
                $cursorTopPosition.X, 
                $cursorTopPosition.Y
            )
        }


        <#
        
            ////////////////////////////////////////////////////////////////////
            ///// The main execution loop of the function.
            
        #>

        do {

            [System.Console]::CursorVisible = $false
            [System.Console]::SetCursorPosition($cursorTopPosition.X, $cursorTopPosition.Y)
        
            if (-NOT [System.String]::IsNullOrEmpty($Title)) {
                $lastDrawnPositions.Title = Save-Position -Text $Title
                [System.Console]::WriteLine($_Color_Title_ + $Title + $_Color_Reset_ + $_linebreak_)
            }

            # Define filtered options as an array, to avoid powershell unpacking single array element.
            [System.Object[]]$filteredOptions = $SelectionOptions
            | Where-Object {
                $_.name -ILIKE "*$searchString*" -OR $_.ignoreSearch -EQ $true
            }

            # This is the number of pages
            $totalCountOfPages = [System.Math]::Ceiling($filteredOptions.Count / $pageSelectionLimit)

            # The last page may not be full, so we need to calculate the maximum index of the last page.
            $lastPageMaxIndex = $filteredOptions.Count % $pageSelectionLimit - 1

            $isLastPage = $currentPageIndex -EQ ($totalCountOfPages - 1)

            # Options to display on the current page.
            $currentPageOptions = $filteredOptions 

            # When there are multiple pages, we filter the optiosns to only show the current page.
            if ($totalCountOfPages -GT 1) {
                $currentPageOptions = $currentPageOptions 
                | Select-Object -Skip ($currentPageIndex * $pageSelectionLimit) 
                | Select-Object -First $pageSelectionLimit
            }
            

            # This is a special case, when swapping to the last page.
            # The selection index from the previous page may exceed the last page.
            if ($currentSelectionIndex -GT $lastPageMaxIndex -AND $isLastPage) {
                $currentSelectionIndex = $lastPageMaxIndex
            }
            
            # When the selected index is outside the range of the current page, we need to reset it.
            # This is the case when the user types a search string and the number of options changes.
            # The different number of options on the last page was already handled above.
            if (
                $currentSelectionIndex -LT 0 -OR
                $currentSelectionIndex -GT $currentPageOptions.Count - 1
            ) {
                $currentSelectionIndex = 0
            }


            <#
                When the user clears the search string,
                then we need to undraw the search menue.
            #>
            if ($searchString.Length -EQ 0 -AND $null -NE $lastDrawnPositions.searchMenue) {
                $lastDrawnPositions.searchMenue = $lastDrawnPositions.searchMenue | Invoke-Clear
            }

            <#
            
                Any time the currently number of currently drawn entires is LESS THAN the previously drawn entries,
                the page menue and search menue move up, wheras the previously drawn postions are not cleared.

                Therefore we need to clear the previously drawn entries.
            #>
            if (
                $lastDrawnPositions.entries.Count -GT 0 -AND
                $currentPageOptions.Count -NE $lastDrawnPositions.entries.Count
            ) {
                $lastDrawnPositions.pageMenu = $lastDrawnPositions.pageMenu | Invoke-Clear
                $lastDrawnPositions.searchMenue = $lastDrawnPositions.searchMenue | Invoke-Clear
                $lastDrawnPositions.entries | Select-Object -Skip $currentPageOptions.Count | Invoke-Clear
            }


            <#
            
                //////////////////////////////////////
                /// Below we draw all the entries of the menue.
                /// This is the main part of the function.
            #>

            # clear the list for last drawn entry positions.
            $currentDrawnEntryPositions = @()

            for ($index = 0; $index -LT $currentPageOptions.Count; $index++) {

                $displayedText = $currentPageOptions[$index].Name

                $_Color_Text_ = $index % 2 -EQ 0 ? $_Color_EvenLine_ : $_Color_UnevenLine_            

                # This shorthens any option to not exceed the terminal width.
                # Dynamic resizing of the terminal is NOT taken into account, therefore will fail in that case!
                if ($displayedText.Length -GT $initialSelectionWitdh) {
                    $maximumLineLength = [System.Math]::Min($displayedText.length, $initialSelectionWitdh)
                    $displayedText = $displayedText.Substring(0, $maximumLineLength)
                    $displayedText = $displayedText + $print.shortendSuffix
                }
                
                # Draws the selected option as highlighted text.
                if ($index -EQ $currentSelectionIndex) {
                    $currentDrawnEntryPositions += Save-Position -Text ($print.prefixSelected + $displayedText)
                    $displayedText = $print.prefixSelected + $_Color_Text_ + $_Color_Select_ + $displayedText + $_Color_Reset_
                } 

                # This draws any normal appearing text.
                elseif (-NOT ($displayedText -ILIKE "*$searchString*") ) {
                    $currentDrawnEntryPositions += Save-Position -Text ($print.prefixNonSelected + $displayedText)
                    $displayedText = $print.prefixNonSelected + $_Color_Text_ + $displayedText + $_Color_Reset_
                }

                # This highlights the part of each option that matches the search string.
                else {
                    $currentDrawnEntryPositions += Save-Position -Text ($print.prefixNonSelected + $displayedText)

                    $startIndex = $displayedText.toLower().IndexOf($searchString.toLower())
                    $startIndex = [System.Math]::Max($startIndex, 0)
                        
                    $beforeHighlight = $displayedText.Substring(0, $startIndex)
                    $highlightedPart = $displayedText.Substring($startIndex, [System.Math]::Max($searchString.Length, 0))
                    $afterHighlight = $displayedText.Substring($startIndex + $searchString.Length)

                    $displayedText = $print.prefixNonSelected + $_Color_Text_ + $beforeHighlight + $_Color_Reset_
                    $displayedText += $_Color_Search_ + $highlightedPart + $_Color_Reset_
                    $displayedText += $_Color_Text_ + $afterHighlight + $_Color_Reset_
                } 

                # This is to account for different lengths of previous drawn entries at the same position.
                $difference = ($lastDrawnPositions.entries[$index] ?? '').Length - $currentDrawnEntryPositions[$index].Length

                $difference = [System.Math]::Max($difference, 0)
                [System.Console]::Write($displayedText)
                [System.Console]::WriteLine(' ' * $difference)
            }

            # Store the current drawn entry positions for undrawing when required.
            $lastDrawnPositions.entries = $currentDrawnEntryPositions

            <#

                When the page count is greater than 0, then this will draw a menue containing:
                - The current page.
                - The total number of pages.
            #>
            if ($totalCountOfPages -GT 0) {

                $displayPageCount = "$($currentPageIndex+1)/$totalCountOfPages"

                # Save the current page position for undrawing when required.
                # We add 1 to the Y position, because of the $_linebreak_ in the [System.Console]::WriteLine() below.
                $lastDrawnPositions.pageMenu = Save-Position -Text $displayPageCount -LineBreaks 1

                [System.Console]::Write($_linebreak_ + $_Color_Page_ + $displayPageCount + $_Color_Reset_)
            }
    

            <#

                When the user types a search string, then this will draw a menue containing:
                - The search string.
                - The number of remaining elements.
                - The total number of elements.
            #>
            if ($searchString.Length -GT 0) {
                $displaySearchData = "     Searching For: {0}'{1}'{2} | Remaining {3} of {4} Elements     "
                $displaySearchData = $displaySearchData -f '{0}', $SearchString, '{1}', $filteredOptions.Count, $SelectionOptions.Count

                # Save the current search string position for undrawing when required.
                $lastDrawnPositions.searchMenue = Save-Position -Text $displaySearchData

                $displaySearchData = $displaySearchData -f $_Color_Search_, $_Color_Reset_
                [System.Console]::Write($displaySearchData)
            }


            [System.Console]::WriteLine($_linebreak_)


            <#
            
                ////////////////////////////////////////
                /// Handle Key Inputs from User.

            #>
            
            $e = [System.Console]::ReadKey($true)


            <#
                Cancel the operation if the user presses ESC or CTRL+C.
            #>
            if (
                $e.Key -EQ [System.ConsoleKey]::Escape -OR
                ($e.Key -EQ [System.ConsoleKey]::C -AND $e.Modifiers -EQ "Control")
            ) {
                Invoke-ClearUpAll
                throw [System.OperationCanceledException]::new("User canceled the operation.")
            }


            <#
                When the user presses Enter, we need to return the selected option.
            #>
            elseif ($e.Key -EQ [System.ConsoleKey]::Enter) {
                Invoke-ClearUpAll
                return $filteredOptions[$currentPageIndex * $pageSelectionLimit + $currentSelectionIndex].returnValue
            }


            <#
                This handles the selection of the options with the arrow keys.
                - Up Arrow: Move up in the list.
                - Down Arrow: Move down in the list.
                - Left Arrow: Move to the previous page.
                - Right Arrow: Move to the next page.
            #>
            elseif (
                $e.Key -EQ [System.ConsoleKey]::LeftArrow 
            ) {
                $currentPageIndex = ($currentPageIndex + $totalCountOfPages - 1) % $totalCountOfPages
            }
            elseif (
                $e.Key -EQ [System.ConsoleKey]::RightArrow 
            ) {
                $currentPageIndex = ($currentPageIndex + $totalCountOfPages + 1) % $totalCountOfPages
            }
            elseif (
                $e.Key -EQ [System.ConsoleKey]::UpArrow 
            ) {
                $currentSelectionIndex = $currentSelectionIndex - 1
                if ($currentSelectionIndex -LT 0) {
                    $currentPageIndex = ($currentPageIndex + $totalCountOfPages - 1) % $totalCountOfPages
                    $currentSelectionIndex = $pageSelectionLimit - 1
                }
            }
            elseif (
                $e.Key -EQ [System.ConsoleKey]::DownArrow 
            ) {
                $currentSelectionIndex = $currentSelectionIndex + 1
                # Loop back to first index when maximum index downwards is reached
                if (
                    $currentSelectionIndex -GT $pageSelectionLimit - 1 -OR 
                        ($currentSelectionIndex -GT $lastPageMaxIndex -AND $isLastPage)
                ) {
                    $currentPageIndex = ($currentPageIndex + $totalCountOfPages + 1) % $totalCountOfPages
                    $currentSelectionIndex = 0
                }
            }
                

            <#
                This handles the search string input.
                - Backspace: Remove the last character from the search string.
                - Any other key: Add the character to the search string and filter the options.
            #>
            elseif (
                $e.Key -EQ [System.ConsoleKey]::Backspace
            ) {
                $searchString = $searchString.Substring(0, [System.Math]::Max(0, $searchString.Length - 1))
            }

            elseif ($null -NE $e.Key) {
                $temporarySearchString = $searchString + $e.KeyChar
                $remaining = $SelectionOptions 
                | Where-Object -Property name -ILIKE "*$temporarySearchString*"

                $searchString = $remaining.Length -GT 0 ? $temporarySearchString : $searchString
            }

            
            <#
                This gives a hint to the user about the available keys.
            #>
            else {
                $hint = 'Use on of the Following Keys: (ArrowUP | ArrowDown | W | S | Enter)'
                Write-Host -ForeGroundColor Magenta -Separator "$_Color_Search_$hint...$_Color_Reset_"
                $null = [System.Console]::ReadKey($true)
            }

      
        } while ($e.Key -NE [System.ConsoleKey]::Enter)
    
    }

    CLEAN {
        # The clean up function is NOT used, because the behaviour of execution is different,
        # - when the function exits by pressing Enter.
        # - when the function exits by throwing an exception.
    }
}