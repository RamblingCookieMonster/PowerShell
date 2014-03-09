function Get-PropertyType {
<#
.SYNOPSIS
    Extract unique types for properties of one or more objects

.PARAMETER InputObject
    One or more objects to property types from

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
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [psobject]$inputObject,

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

            .PARAMETER inputObject
                A single object to convert to an array of property value pairs.

            .PARAMETER membertype
                Membertypes to include

            .PARAMETER excludeProperty
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
                [string[]]$memberType = @( "NoteProperty", "Property", "ScriptProperty" ),

                [string[]]$excludeProperty = $null
            )

            begin{
                #init array to dump all objects into
                $allObjects = @()

            }
            process{
                #if we're taking from pipeline and get more than one object, this will build up an array
                $allObjects += $inputObject
            }

            end{
                #use only the first object provided
                $allObjects = $allObjects[0]

                #Get properties.  I use convertto-csv to maintain property order
                $allObjects.psobject.properties | ?{$memberType -contains $_.memberType} | select -ExpandProperty Name | ?{if($excludeProperty){$excludeProperty -notcontains $_ } else{$_}}

            }
        } #Get-PropertyOrder


    }

    Process {

        #loop through every object
        foreach($obj in $inputObject){
    
            #extract the properties in this object
            $props = @( Get-PropertyOrder $obj | ?{ if($property) { $property -contains $_ } else { $true } } )

            #loop through every property in this one object
            foreach($prop in $props){
        
                #set up a variable name we will use to store an array of unique types
                $varName = "_My$prop"
            
                #try to get the property type.  If it's null, say so
                Try{
                    $type = $obj.$prop.gettype().FullName
                }
                Catch {
                    $type = $null
                }

                #not sure if we need this, but init currentvalue to null
                $currentValue = $null

                #check to see if we have an array of types for this property.  Set current value in the logic
                if(-not ($currentValue = Get-Variable $varName -ErrorAction SilentlyContinue -ValueOnly)){

                    #we don't have an array yet.  Start one, put the type in it, give it a description we can use later
                    Set-Variable -name $varName -value @( $type ) -force -Description "_MyProp"
            
                }
                else{

                    #We have an array.  Check to see if the type is already in it.
                    if($currentValue -notcontains $type){
                    
                        #type isn't in the array yet, add it
                        Set-Variable -name $varName -Value @( $currentValue + $type ) -force -Description "_MyProp"

                    }
                }
            }

        }
    }
    End {

        #get all the results, remove _My from their name
        Get-Variable -Scope 0 | ?{$_.Description -eq "_MyProp"} | Select-Object -Property @{ label = "Name"; expression = {$_.name -replace "^_My",""} }, Value

    }
}