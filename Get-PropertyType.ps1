function Get-PropertyType {
    <#
    .SYNOPSIS
        Extract unique .NET types for properties of one or more objects

    .PARAMETER InputObject
        Get properties and their types for each of these

    .PARAMETER Property
        If specified, only return unique types for these properties

    .EXAMPLE
    
        #Define an array of objects
        
            $array = [pscustomobject]@{
                prop1 = "har"
                prop2 = $(get-date)
            },
            [pscustomobject]@{
                prop1 = "bar"
                prop2 = 2
            } 
    
        #Extract the property types from this array.  In this example, Prop1 is always a System.String, Prop2 is a System.DateTime and System.Int32
        
            $array | Get-PropertyType

                #  Name  Value                          
                #  ----  -----                          
                #  prop1 {System.String}                
                #  prop2 {System.DateTime, System.Int32}

        #Pretend prop2 should always be a DateTime.  Extract all objects from $array where this is not the case
        
            $array | ?{$_.prop2 -isnot [System.DateTime]}

                #  prop1 prop2
                #  ----- -----
                #  bar       2

    .FUNCTIONALITY 
        General Command
    #>
    param (
        [Parameter( Mandatory=$true,
                    ValueFromPipeline=$true)]
        [psobject]$InputObject,

        [string[]]$property = $null
    )

    Begin {

        #function to extract properties
        Function Get-PropertyOrder {
            <#
            .SYNOPSIS
                Gets property order for specified object
    
            .DESCRIPTION
                Gets property order for specified object

            .PARAMETER InputObject
                A single object to convert to an array of property value pairs.

            .PARAMETER Membertype
                Membertypes to include

            .PARAMETER ExcludeProperty
                Specific properties to exclude
    
            .FUNCTIONALITY
                PowerShell Language
            #>
            [cmdletbinding()]
             param(
                [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromRemainingArguments=$false)]
                    [PSObject]$InputObject,

                [validateset("AliasProperty", "CodeProperty", "Property", "NoteProperty", "ScriptProperty",
                    "Properties", "PropertySet", "Method", "CodeMethod", "ScriptMethod", "Methods",
                    "ParameterizedProperty", "MemberSet", "Event", "Dynamic", "All")]
                [string[]]$MemberType = @( "NoteProperty", "Property", "ScriptProperty" ),

                [string[]]$ExcludeProperty = $null
            )

            begin {

                if($PSBoundParameters.ContainsKey('inputObject')) {
                    $firstObject = $InputObject[0]
                }
            }
            process{

                #we only care about one object...
                $firstObject = $InputObject
            }
            end{

                #Get properties that meet specified parameters
                $firstObject.psobject.properties |
                    Where-Object { $memberType -contains $_.memberType } |
                    Select -ExpandProperty Name |
                    Where-Object{ -not $excludeProperty -or $excludeProperty -notcontains $_ }
            }
        } #Get-PropertyOrder

        $Output = @{}
    }

    Process {

        #loop through every object
        foreach($obj in $InputObject){
    
            #extract the properties in this object
            $props = @( Get-PropertyOrder -InputObject $obj | Where { -not $Property -or $property -contains $_ } )

            #loop through every property in this one object
            foreach($prop in $props){
                   
                #try to get the property type.  If it's null, say so
                Try{
                    $type = $obj.$prop.gettype().FullName
                }
                Catch {
                    $type = $null
                }

                #check to see if we already have types for this prop
                if(-not $Output.ContainsKey($prop)){

                    #we don't have an array yet.  Start one, put the type in it
                    $List = New-Object System.Collections.ArrayList
                    [void]$List.Add($type)
                    $Output.Add($prop, $List)
            
                }
                else{
                    if($Output[$prop] -notcontains $type){
                    
                        #type isn't in the array yet, add it
                        [void]$output[$prop].Add($type)
                    }
                }
            }
        }
    }
    End {
        
        $Output
    }
}