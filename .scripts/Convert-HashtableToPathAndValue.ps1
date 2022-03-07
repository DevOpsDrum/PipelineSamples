<#
.DESCRIPTION
    Convert hashtable into two column table with path and value
.EXAMPLE
    PS> .scripts/Convert-HashtableToPathAndValue.ps1 -Hashtable <hashtable object>
    Iterate through hashtable and and display report with dot (.) notation path and [string] values 
.OUTPUTS
    [Object[]]
    | path | value |
    | ---- | ----- |
    | $Hashtable.propertyOne | 12345 |
    | $Hashtable.PropertyTwo.Level2 | ABCDEFT |
    
.NOTES
    Script is intended to create an object that can be used to compare two JSON or YAML objects.
#>

[CmdletBinding()]
[OutputType([System.Object[]])]
param(
    [Parameter(HelpMessage = 'Hashtable object to be converted')]
    [hashtable] $Hashtable
)

begin {
    $queue = @('$Hashtable') # initalize queue with hashtable object, in single quotes (literal)
    $final = @() # final array with property and value hashtables
    $complete = $false # while loop trigger
    
    <#
    .DESCRIPTION
        Helper function to save path and value to $final array
    .EXAMPLE
        Add-ToFinal -Path $base.myProperty.thing -Value "12345"
    #>
    function Add-ToFinal {
        [CmdletBinding()]
        [OutputType([System.Void])]
        param(
            [Parameter(HelpMessage = 'Property path, e.g. $base.myProperty.thing')]
            [string] $Path,
            [Parameter(HelpMessage = 'Value, e.g. "12345')]
            [string] $Value
        )
        
        $script:final += [ordered]@{
            path  = "$Path"
            value = "$Value"
        }
    }
}

process {
    while ($complete -ne $true) {
        $tempQueue = @() # items to add to queue for next while loop iteration
        
        # loop through each item in $queue
        foreach ($qItem in $queue) {
            $qItemType = (Invoke-Expression $qItem).GetType().Name
            Write-Verbose "👀 Look at queue item: $qItem [$qItemType]"
            
            if ($qItemType -eq 'String') {
                # If queue item is a string, save to final and go to next $qItem
                # > The reason we have to sections that call Add-ToFinal is because this one is used for
                # > array values that are strings and the one below is for hash table values that are strings
                
                $value = (Invoke-Expression $qItem) # value of the current $qItem
                
                Write-Verbose "➕ Add ${qItem}:${value} to final array"
                Add-ToFinal -Path $qItem -Value $value
            } else {
                # go through child items of $qItem
                
                [int] $i = 0 # item counter, needed to label array items
                foreach ($item in (Invoke-Expression $qItem).GetEnumerator()) {
                    $itemType = $item.GetType().Name
                    
                    if ($qItemType -eq 'Object[]') {
                        # if $qItem is an object array,
                        # path is the $qItem name and the ordinal index
                        $path = "$($qItem)[$i]"
                    } else {
                        # otherwise, the path is $qItem + "." + $item name
                        $path = "$($qItem).$($item.Name)"
                    }
                    
                    if ($itemType -eq 'String') {
                        # If queue item is a string, save to final and go to next $qItem
                        # > The reason we have to sections that call Add-ToFinal is because this one is used for
                        # > hash table values that are strings and the one above is for array values that are strings
                        
                        Write-Verbose "➕ Add ${path}:${item} to final array"
                        Add-ToFinal -Path "$path" -Value $item # value is the name of the current $qItem item
                    } else {
                        # add to $tempQueue
                        Write-Verbose "➕ Add '$path' to queue array"
                        $tempQueue += @("$path")
                    }
                    
                    $i++ # increment item counter
                } # /foreach item in $qItem
            } # /if ($qItemType -eq 'String')  > else
        } # /foreach $qItem in $queue
        
        if ($tempQueue.Count -eq 0) {
            $complete = $true
        } else {
            $queue = $tempQueue | Sort-Object -Unique # deduplicate array, which happens when an array has multiple string values
            Write-Debug "📜 Queue Contents:"
            Write-Debug ($queue -join ",")
        }
    } # /while ($complete -ne $true)
}

end {
    # return $final as two column table
    return $final | ForEach-Object { [PSCustomObject]$_ } | Format-Table -AutoSize -Wrap
}
