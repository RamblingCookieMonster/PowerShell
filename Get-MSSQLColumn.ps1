function Get-MSSQLColumn { 
<#
    .SYNOPSIS
        Return details on SQL columns for one or more tables
    
    .DESCRIPTION
        Return details on SQL columns for one or more tables

        This function depends on Invoke-SQLCMD2.  Thanks to Chad Miller and all the contributors!
        Download this from http://poshcode.org/4137 and get it into your session before running this command.

    .FUNCTIONALITY 
        SQL

    .PARAMETER table
        One or more tables to query

    .PARAMETER database
        SQL database to query.  Directly mapped to Invoke-SQLCMD2.  Get-Help Invoke-SQLCMD2 -Full for more info

    .PARAMETER allFields
        If specified, return all details from INFORMATION_SCHEMA.COLUMNS.
        If not specified, returns only column names for the specified table(s)

    .PARAMETER username
        username for query.  Directly mapped to Invoke-SQLCMD2.  Get-Help Invoke-SQLCMD2 -Full for more info

    .PARAMETER password
        password for query.  Directly mapped to Invoke-SQLCMD2.  Get-Help Invoke-SQLCMD2 -Full for more info

    .PARAMETER ServerInstance
        SQL Server Instance to query.  Directly mapped to Invoke-SQLCMD2.  Get-Help Invoke-SQLCMD2 -Full for more info

    .EXAMPLE
        #Display full details for each column in tables tblServerInfo and tblApplicationInfo, from server SomeServerInstance and database ServerDB
        Get-MSSQLColumn -table tblServerInfo, tblApplicationInfo -database ServerDB -ServerInstance SomeServerInstance -allFields | Out-GridView

    .EXAMPLE
        #Display all column names for tblServerInfo from server SomeServerInstance and database ServerDB
        Get-MSSQLColumn -table tblServerInfo -database ServerDB -ServerInstance SomeServerInstance

#>
    
    [cmdletbinding()]
    param(
        
        [parameter(
            Mandatory=$true,
            Position=0,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
            [string[]]$table,
        
        [parameter( Mandatory=$true )]
            [string]$database,

            [switch]$allFields,

            [string]$username = $null,

            [string]$password = $null,
        
        [parameter( Mandatory=$true )]
            [string]$ServerInstance
    )
    Begin
    {

        #Including this here to avoid dependencies...
        function Invoke-Sqlcmd2 { 
            <# 
            .SYNOPSIS 
            Runs a T-SQL script. 
            .DESCRIPTION 
            Runs a T-SQL script. Invoke-Sqlcmd2 only returns message output, such as the output of PRINT statements when -verbose parameter is specified.
            Paramaterized queries are supported. 
            .INPUTS 
            None 
                You cannot pipe objects to Invoke-Sqlcmd2 
            .OUTPUTS 
               System.Data.DataTable 
            .EXAMPLE 
            Invoke-Sqlcmd2 -ServerInstance "MyComputer\MyInstance" -Query "SELECT login_time AS 'StartTime' FROM sysprocesses WHERE spid = 1" 
            This example connects to a named instance of the Database Engine on a computer and runs a basic T-SQL query. 
            StartTime 
            ----------- 
            2010-08-12 21:21:03.593 
            .EXAMPLE 
            Invoke-Sqlcmd2 -ServerInstance "MyComputer\MyInstance" -InputFile "C:\MyFolder\tsqlscript.sql" | Out-File -filePath "C:\MyFolder\tsqlscript.rpt" 
            This example reads a file containing T-SQL statements, runs the file, and writes the output to another file. 
            .EXAMPLE 
            Invoke-Sqlcmd2  -ServerInstance "MyComputer\MyInstance" -Query "PRINT 'hello world'" -Verbose 
            This example uses the PowerShell -Verbose parameter to return the message output of the PRINT command. 
            VERBOSE: hello world 
            .NOTES 
            Version History 
            v1.0   - Chad Miller - Initial release 
            v1.1   - Chad Miller - Fixed Issue with connection closing 
            v1.2   - Chad Miller - Added inputfile, SQL auth support, connectiontimeout and output message handling. Updated help documentation 
            v1.3   - Chad Miller - Added As parameter to control DataSet, DataTable or array of DataRow Output type 
            v1.4   - Justin Dearing <zippy1981 _at_ gmail.com> - Added the ability to pass parameters to the query.
            v1.4.1 - Paul Bryson <atamido _at_ gmail.com> - Added fix to check for null values in parameterized queries and replace with [DBNull]
            v1.5   - Joel Bennett - add SingleValue output option
            .FUNCTIONALITY
            PowerShell Language
            #> 
            [CmdletBinding()] 
            param( 
            [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance, 
            [Parameter(Position=1, Mandatory=$false)] [string]$Database, 
            [Parameter(Position=2, Mandatory=$false)] [string]$Query, 
            [Parameter(Position=3, Mandatory=$false)] [string]$Username, 
            [Parameter(Position=4, Mandatory=$false)] [string]$Password, 
            [Parameter(Position=5, Mandatory=$false)] [Int32]$QueryTimeout=600, 
            [Parameter(Position=6, Mandatory=$false)] [Int32]$ConnectionTimeout=15, 
            [Parameter(Position=7, Mandatory=$false)] [ValidateScript({test-path $_})] [string]$InputFile, 
            [Parameter(Position=8, Mandatory=$false)] [ValidateSet("DataSet", "DataTable", "DataRow","SingleValue")] [string]$As="DataRow",
            [Parameter(Position=9, Mandatory=$false)] [System.Collections.IDictionary]$SqlParameters 
            ) 
            
            if ($InputFile) 
            { 
                $filePath = $(resolve-path $InputFile).path 
                $Query =  [System.IO.File]::ReadAllText("$filePath") 
            } 
            
            $conn=new-object System.Data.SqlClient.SQLConnection 
            
            if ($Username) 
            { $ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4}" -f $ServerInstance,$Database,$Username,$Password,$ConnectionTimeout } 
            else 
            { $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $ServerInstance,$Database,$ConnectionTimeout } 
            
            $conn.ConnectionString=$ConnectionString 
            
            #Following EventHandler is used for PRINT and RAISERROR T-SQL statements. Executed when -Verbose parameter specified by caller 
            if ($PSBoundParameters.Verbose) 
            { 
                $conn.FireInfoMessageEventOnUserErrors=$true 
                $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {Write-Verbose "$($_)"} 
                $conn.add_InfoMessage($handler) 
            } 
            
            $conn.Open() 
            $cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn) 
            $cmd.CommandTimeout=$QueryTimeout
            if ($SqlParameters -ne $null)
            {
                $SqlParameters.GetEnumerator() |
                    ForEach-Object {
                        If ($_.Value -ne $null)
                        { $cmd.Parameters.AddWithValue($_.Key, $_.Value) }
                        Else
                        { $cmd.Parameters.AddWithValue($_.Key, [DBNull]::Value) }
                    } > $null
            }
            
            $ds = New-Object system.Data.DataSet 
            $da = New-Object system.Data.SqlClient.SqlDataAdapter($cmd) 
            
            [void]$da.fill($ds) 
            
            $conn.Close() 
            
            switch ($As) 
            { 
                'DataSet'     { Write-Output ($ds) } 
                'DataTable'   { Write-Output ($ds.Tables) } 
                'DataRow'     { Write-Output ($ds.Tables[0]) }
                'SingleValue' { Write-Output ($ds.Tables[0] | Select-Object -Expand $ds.Tables[0].Columns[0].ColumnName ) }
            } 
 
        } #Invoke-SQLCMD2
        

        #Make sure invoke-sqlcmd2 is available
        if(-not ( get-command invoke-sqlcmd2 -ErrorAction SilentlyContinue))
        {
            Throw "This command relies on Invoke-SQLCMD2.  Please obtain the latest version and dot source it prior to running this command.`nThis script was built using the code from here: http://poshcode.org/4137"
        }


        #Build up the parameters for the query
        #TODO:  Add functionality to query for specific column names?
        $params = @{
            Query = "SELECT $( if($allFields){"*"} else{"COLUMN_NAME"}) FROM [INFORMATION_SCHEMA].[COLUMNS] WHERE TABLE_NAME = @table"
            ServerInstance = $ServerInstance
            ErrorAction = "Stop"
            Database = $database
        }
        if($username){
            $params.add("username",$username)
        }
        if($password){
            $params.add("password",$password)
        }

    }
    Process
    {
        foreach($sqlTable in $table)
        {

            #Build sql query parameters
            $sqlParams = @{
                table = $sqlTable
            }

            #Run the query, continue with the next table if we fail
            try
            {
                write-verbose "Running Invoke-SQLCMD with parameters:`n$($params | out-string)`nSQL Parameters:`n$($sqlParams | out-string)"
                $results = Invoke-Sqlcmd2 @params -SqlParameters $sqlParams
            }
            catch
            {
                Write-Error "Error returning columns from table '$sqlTable' on instance '$ServerInstance': $_"
                continue
            }

            #display all fields or expand column name depending on params
            if($allFields)
            {
                $results
            }
            else
            {
                $results | select -ExpandProperty COLUMN_NAME
            }
        }
    }
 }