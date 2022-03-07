<#
.DESCRIPTION
    Convert hashtable into single-level Object[] with property name path and value
.EXAMPLE
    PS> .pipelines/scripts/Convert-HashtableToPathAndValue.ps1 `
        -Hashtable (Get-Content -Raw -Path "${HOME}/repos/myRepo/myConfig.yaml" | ConvertFrom-Yaml)
    Iterate through hashtable and create single-level Object[] with property name path and value, e.g. $Hashtable.propertyOne = 12345
.OUTPUTS
    [Object[]]
    * e.g.
        | Name                          | Value   |
        | ----------------------------- | ------- |
        | $Hashtable.propertyOne        | 12345   |
        | $Hashtable.PropertyTwo.Level2 | ABCDEFG |
.NOTES
    * Script is intended to create an object that can be used to compare JSON or YAML objects, like two config files
    * Convert JSON file:
        ```
        $jsonObject = Get-Content -Raw -Path "${HOME}/repos/myRepo/myConfig.json" | ConvertFrom-Json
        ./.pipelines/scripts/Convert-HashtableToPathAndValue.ps1 -Hashtable $jsonObject | Format-Table -AutoSize -Wrap
        ```
    * Convert YAML file:
        ```
        Import-Module powershell-yaml
        $yamlObject = Get-Content -Raw -Path "${HOME}/repos/myRepo/myConfig.yaml" | ConvertFrom-Yaml
        ./.pipelines/scripts/Convert-HashtableToPathAndValue.ps1 -Hashtable $yamlObject | Format-Table -AutoSize -Wrap
        ```
#>

[CmdletBinding()]
[OutputType([Object[]])]
param(
    [Parameter(HelpMessage = 'Hashtable object to be converted', ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [Hashtable] $Hashtable = (Get-Content -Raw -Path "${HOME}/repos/RP-Config/deploy/int-config.yaml" | ConvertFrom-Yaml)
)

begin {
    $queue = @('$Hashtable') # initalize queue with hashtable object, in single quotes (literal)
    $output = @{} # output hashtable with property and value hashtables
    $complete = $false # while loop trigger
    
    <#
    .DESCRIPTION
        Helper function to save path and value to $output hashtable
    .EXAMPLE
        Add-ToOutput -Path '$Hashtable.myProperty.thing' -Value '12345'
    #>
    function Add-ToOutput {
        [CmdletBinding()]
        [OutputType([System.Void])]
        param(
            [Parameter(HelpMessage = 'Property path, e.g. $base.myProperty.thing')]
            [string] $Path,
            [Parameter(HelpMessage = 'Value, e.g. "12345')]
            [string] $Value
        )
        
        $script:output += @{
            "$Path" = "$Value"
        }
    }
}

process {
    while ($complete -ne $true) {
        $tempQueue = @() # items to add to queue for next while loop iteration
        
        # loop through each item in $queue
        foreach ($qItem in $queue) {
            $qItemObject = (Invoke-Expression $qItem)
            
            if ($null -eq $qItemObject) {
                # handle empty array, e.g. `myItemArray: []`
                $qItemType = 'String' # empty arrays are considered a [String] datatype
                $value = '[]'
            } else {
                # anything but an empty array
                $qItemType = $qItemObject.GetType().Name
                $value = (Invoke-Expression $qItem) # value of the current $qItem; used if $qItemType -eq 'String'
            }
            
            Write-Verbose "👀 Look at queue item: $qItem [$qItemType]"
            
            if ($qItemType -match 'String' -or `
                    $qItemType -match 'Boolean' -or `
                    $qItemType -match 'Int' -or `
                    $qItemType -match 'Double') {
                # If queue item is a Scalar data type (String, Integer, Boolean, Decimal(Float)), save to output array and go to next $qItem
                # > The reason we have to sections that call Add-ToOutput is because this one is used for
                # > array values that are strings and the one below is for hashtable values that are strings
                
                Write-Verbose "➕ Add ${qItem}:${value} to output array"
                Add-ToOutput -Path $qItem -Value $value
            } else {
                # $qItemType is a List or Dictionary
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
                        # If queue item is a string, save to output and go to next $qItem
                        # > The reason we have to sections that call Add-ToOutput is because this one is used for
                        # > hashtable values that are strings and the one above is for array values that are strings
                        
                        Write-Verbose "➕ Add ${path}:${item} to output array"
                        Add-ToOutput -Path "$path" -Value $item # value is the name of the current $qItem item
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
    # return single-level Object[] with property name path and value
    return $output.GetEnumerator() | Sort-Object -Property Name
}
