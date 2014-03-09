function Get-FolderEntry { 
    <#
        .SYNOPSIS
            Lists all folders under a specified folder regardless of character limitation on path depth.

        .DESCRIPTION
            Lists all folders under a specified folder regardless of character limitation on path depth.

            This is based on Boe's Get-FolderItem command here:  http://gallery.technet.microsoft.com/scriptcenter/Get-Deeply-Nested-Files-a2148fd7

        .FUNCTIONALITY 
            Computers

        .PARAMETER Path
            One or more paths to search for subdirectories under

        .PARAMETER ExcludeFolder
            One or more paths to exclude from query

        .EXAMPLE
            Get-FolderEntry -Path "C:\users"
            
                FullPathLength FullName                                        FileCount
                -------------- --------                                        ---------
                             9 C:\Users\                                       1
                            23 C:\Users\SomeUser\                              7
                            31 C:\Users\SomeUser\AppData\                      0
                            37 C:\Users\SomeUser\AppData\Local\                0
                            47 C:\Users\SomeUser\AppData\Local\Microsoft\      0
                            ...

            Description
            -----------
            Returns all folders under the users folder.

        .EXAMPLE
            Get-FolderEntry -Path "C:\users" -excludefolder "C:\Users\SomeUser\AppData\Local\Microsoft\"
            
                FullPathLength FullName                                                FileCount
                -------------- --------                                                ---------
                             9 C:\Users\                                               1
                            23 C:\Users\SomeUser\                                      7
                            31 C:\Users\SomeUser\AppData\                              0
                            37 C:\Users\SomeUser\AppData\Local\                        0
                            52 C:\Users\SomeUser\AppData\Local\Microsoft Help\         0          #NOTE that we skipped the excludefolder path
                            ...

            Description
            -----------
            Returns all folders under the users folder, excluding C:\Users\SomeUser\AppData\Local\Microsoft\ and all subdirectories

        .INPUTS
            System.String
    
        .OUTPUTS
            System.IO.RobocopyDirectoryInfo

        .NOTES
            Name: Get-FolderItem
            Author: Boe Prox
            Date Created: 31 March 2013
            Updated by rcm
    #>
    [cmdletbinding(DefaultParameterSetName='Filter')]
    Param (
        [parameter(
            Position=0,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True)]
        [Alias('FullName')]
        [string[]]$Path = $PWD,

        [parameter(ParameterSetName='Filter')]
        [string[]]$Filter = '*.*',    

        [parameter(ParameterSetName='Exclude')]
        [string[]]$ExcludeFolder
    )

    Begin {
        
        #Define arguments for robocopy and regex to parse results
            $array = @("/L","/S","/NJH","/BYTES","/FP","/NC","/NFL","/TS","/XJ","/R:0","/W:0")
            $regex = "^(?<Count>\d+)\s+(?<FullName>.*)"

        #Create an arraylist
            $params = New-Object System.Collections.Arraylist
            $params.AddRange($array)
    }

    Process {

        ForEach ($item in $Path) {
            Try {
                
                $item = (Resolve-Path -LiteralPath $item -ErrorAction Stop).ProviderPath
                
                If (-Not (Test-Path -LiteralPath $item -Type Container -ErrorAction Stop)) {
                    Write-Warning ("{0} is not a directory and will be skipped" -f $item)
                    Return
                }
                
                If ($PSBoundParameters['ExcludeFolder']) {
                    $filterString = ($ExcludeFolder | %{"'$_'"}) -join ','
                    $Script = "robocopy `"$item`" NULL $Filter $params /XD $filterString"
                }
                Else {
                    $Script = "robocopy `"$item`" NULL $Filter $params"
                }

                Write-Verbose ("Scanning {0}" -f $item)
                
                #Run robocopy and parse results into an object.
                Invoke-Expression $Script | ForEach {
                    Try {
                        If ($_.Trim() -match $regex) {
                           $object = New-Object PSObject -Property @{
                                FullName = $matches.FullName
                                FileCount = [int64]$matches.Count
                                FullPathLength = [int] $matches.FullName.Length
                            } | select FullName, FileCount, FullPathLength
                            $object.pstypenames.insert(0,'System.IO.RobocopyDirectoryInfo')
                            Write-Output $object
                        } Else {
                            Write-Verbose ("Not matched: {0}" -f $_)
                        }
                    } Catch {
                        Write-Warning ("{0}" -f $_.Exception.Message)
                        Return
                    }
                }
            } Catch {
                Write-Warning ("{0}" -f $_.Exception.Message)
                Return
            }
        }
    }
}