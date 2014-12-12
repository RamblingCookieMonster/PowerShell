function Invoke-MySQLQuery { 
    <# 
    .SYNOPSIS 
        Runs a SQL script against a MySQL instance

    .DESCRIPTION 
        Runs a SQL script against a MySQL instance

        Paramaterized queries are supported. 

        Help details below borrowed from Invoke-Sqlcmd

        MySQL specific considerations should be taken.
            For example, consider evaluating the risks around differing connections string options - http://dev.mysql.com/doc/connector-net/en/connector-net-connection-options.html
            Contributions to this function would be appreciated : )
        
        IMPORTANT - This is a first draft.  As may be apparent, I am not a MySQL guy : )
                    Requires the ADO.NET driver for MySQL - http://dev.mysql.com/downloads/connector/net/

    .PARAMETER ComputerName
        One or more servers to query.

    .PARAMETER Database
        A character string specifying the name of a database. Invoke-MySQLQuery connects to this database in the instance that is specified in -ServerInstance.

    .PARAMETER Port
        TCP Port to connect to MySQL over

    .PARAMETER Query
        Specifies a query to be run.

    .PARAMETER InputFile
        Specifies a file to be used as the query input to Invoke-MySQLQuery. Specify the full path to the file.

    .PARAMETER Credential
        Specifies A PSCredential for authentication connection to an instance of the Database Engine.
        SECURITY NOTE: If you use the -Debug switch, the connectionstring including plain text password will be sent to the debug stream.
        SECURITY NOTE: Read up on connection string options, and evaluate the string provided in this function...

    .PARAMETER QueryTimeout
        Specifies the number of seconds before the queries time out.

    .PARAMETER ConnectionTimeout
        Specifies the number of seconds when Invoke-MySQLQuery times out if it cannot successfully connect to an instance of the Database Engine.

    .PARAMETER As
        Specifies output type - DataSet, DataTable, array of DataRow, PSObject or Single Value 

        PSObject output introduces overhead but adds flexibility for working with results: http://powershell.org/wp/forums/topic/dealing-with-dbnull/

    .PARAMETER SqlParameters
        Hashtable of parameters for parameterized SQL queries.  http://blog.codinghorror.com/give-me-parameterized-sql-or-give-me-death/

        Example:
            -Query "SELECT ServerName FROM tblServerInfo WHERE ServerName LIKE @ServerName"
            -SqlParameters @{"ServerName = "c-is-hyperv-1"}

    .PARAMETER AppendServerInstance
        If specified, append the MySQL server name and port to PSObject or DataRow output

    .INPUTS 
        ServerInstance 
            You can pipe SQL Instance names to Invoke-MySqlQuery.  The query will execute against each instance.

    .OUTPUTS
       As PSObject:     System.Management.Automation.PSCustomObject
       As DataRow:      System.Data.DataRow
       As DataTable:    System.Data.DataTable
       As DataSet:      System.Data.DataTableCollectionSystem.Data.DataSet
       As SingleValue:  Dependent on data type in first column.

   
    .EXAMPLE
        Invoke-MySQLQuery -ComputerName MyServer -Query "SELECT ServerName, VCNumCPU FROM tblServerInfo" -as PSObject | ?{$_.VCNumCPU -gt 8}
        Invoke-MySQLQuery -ComputerName MyServer -Query "SELECT ServerName, VCNumCPU FROM tblServerInfo" -as PSObject | ?{$_.VCNumCPU}

        This example uses the PSObject output type to allow more flexibility when working with results.
        
        If we used DataRow rather than PSObject, we would see the following behavior:
            Each row where VCNumCPU does not exist would produce an error in the first example
            Results would include rows where VCNumCPU has DBNull value in the second example

    .EXAMPLE
        'Server1', 'Server2', 'Server3' | Invoke-MySQLQuery -query "SHOW DATABASES" -as psobject -AppendServerInstance

        This example lists databases for each instance.  It includes a column for the MySQL server and ports in question.
            Database           MySQLServer MySQLPort
            --------           ----------- ---------
            information_schema Server1     3306     
            information_schema Server2     3306                                                    
            information_schema Server3     3306     

    .EXAMPLE
        #Construct a query using SQL parameters
            $Query = "SELECT ServerName, VCServerClass, VCServerContact FROM tblServerInfo WHERE VCServerContact LIKE @VCServerContact AND VCServerClass LIKE @VCServerClass"

        #Run the query, specifying values for SQL parameters
            Invoke-MySQLQuery -ComputerName SomeServer\NamedInstance -Database ServerDB -query $query -SqlParameters @{ VCServerContact="%cookiemonster%"; VCServerClass="Prod" }
            
            ServerName    VCServerClass VCServerContact        
            ----------    ------------- ---------------        
            SomeServer1   Prod          cookiemonster, blah                 
            SomeServer2   Prod          cookiemonster                 
            SomeServer3   Prod          blah, cookiemonster                 

    .NOTES 
        Version History 
        
        codeplex.com - http://sqlpsx.codeplex.com/       
        
        github.com   - https://github.com/RamblingCookieMonster/PowerShell
        v0.1.0       - Merged SQLPSX mySQLLib functions from Mike Shepard into Invoke-SqlCmd2 function

    .LINK
        https://github.com/RamblingCookieMonster/PowerShell

    .FUNCTIONALITY
        SQL
    #>

    [CmdletBinding( DefaultParameterSetName='Query' )]
    [OutputType([System.Management.Automation.PSCustomObject],[System.Data.DataRow],[System.Data.DataTable],[System.Data.DataTableCollection],[System.Data.DataSet])]
    param(
        [Parameter( Position=0,
                    Mandatory=$true,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    HelpMessage='SQL Server Instance required...' )]
        [Alias( 'Instance', 'Instances', 'ServerInstance', 'Server', 'Servers','cn' )]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $ComputerName,

        [Parameter( Position=1,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [int]$Port = 3306,

        [Parameter( Position=2,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false)]
        [string]
        $Database,
    
        [Parameter( Position=3,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    ParameterSetName='Query' )]
        [string]
        $Query,
        
        [Parameter( Position=3,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    ParameterSetName="File")]
        [ValidateScript({ Test-Path $_ })]
        [string]
        $InputFile,
        
        [Parameter( Position=4,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    ParameterSetName="Query")]
        [Parameter( Position=4,
                    Mandatory=$true,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    ParameterSetName="File")]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter( Position=5,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Int32]
        $QueryTimeout=600,
    
        [Parameter( Position=6,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [Int32]
        $ConnectionTimeout=15,
    
        [Parameter( Position=7,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [ValidateSet("DataSet", "DataTable", "DataRow","PSObject","SingleValue")]
        [string]
        $As="DataRow",
    
        [Parameter( Position=8,
                    Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false )]
        [System.Collections.IDictionary]
        $SqlParameters,

        [Parameter( Position=9,
                    Mandatory=$false )]
        [switch]
        $AppendServerInstance
    ) 

    Begin
    {
        
        if( -not ($Library = [System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")) )
        {
            Throw "This function requires the ADO.NET driver for MySQL:`n`thttp://dev.mysql.com/downloads/connector/net/"
        }
        

        if ($InputFile) 
        { 
            $filePath = $(Resolve-Path $InputFile).path 
            $Query =  [System.IO.File]::ReadAllText("$filePath") 
        }

        Write-Verbose "Running Invoke-MySQLQuery with ParameterSet '$($PSCmdlet.ParameterSetName)'.  Performing query '$Query'"

        If($As -eq "PSObject")
        {
            #This code scrubs DBNulls.  Props to Dave Wyatt
            $cSharp = @'
                using System;
                using System.Data;
                using System.Management.Automation;

                public class DBNullScrubber
                {
                    public static PSObject DataRowToPSObject(DataRow row)
                    {
                        PSObject psObject = new PSObject();

                        if (row != null && (row.RowState & DataRowState.Detached) != DataRowState.Detached)
                        {
                            foreach (DataColumn column in row.Table.Columns)
                            {
                                Object value = null;
                                if (!row.IsNull(column))
                                {
                                    value = row[column];
                                }

                                psObject.Properties.Add(new PSNoteProperty(column.ColumnName, value));
                            }
                        }

                        return psObject;
                    }
                }
'@

            Try
            {
                Add-Type -TypeDefinition $cSharp -ReferencedAssemblies 'System.Data','System.Xml' -ErrorAction stop
            }
            Catch
            {
                If(-not $_.ToString() -like "*The type name 'DBNullScrubber' already exists*")
                {
                    Write-Warning "Could not load DBNullScrubber.  Defaulting to DataRow output: $_"
                    $As = "Datarow"
                }
            }
        }

    }
    Process
    {
        foreach($Computer in $ComputerName)
        {
            Write-Verbose "Querying ComputerName '$Computer'"

            $ConnectionString = "Server={0};Port=$Port;Database={1};Uid={2};Pwd={3};allow zero datetime=yes;Connection Timeout={4}" -f $Computer,$Database,$Credential.UserName,$Credential.GetNetworkCredential().Password,$ConnectionTimeout
	        
            $conn=new-object MySql.Data.MySqlClient.MySqlConnection
            $conn.ConnectionString = $ConnectionString 
            Write-Debug "ConnectionString $ConnectionString"

            <# TODO Check if this is needed
            
            #Following EventHandler is used for PRINT and RAISERROR T-SQL statements. Executed when -Verbose parameter specified by caller 
            if ($PSBoundParameters.Verbose) 
            { 
                $conn.FireInfoMessageEventOnUserErrors=$true 
                $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] { Write-Verbose "$($_)" } 
                $conn.add_InfoMessage($handler) 
            } 
            #>
    
            Try
            {
                $conn.Open() 
            }
            Catch
            {
                Write-Error $_
                continue
            }

            $cmd = New-Object MySql.Data.MySqlClient.MySqlCommand($Query,$conn) 
            $cmd.CommandTimeout = $QueryTimeout

            if ($SqlParameters -ne $null)
            {
                $SqlParameters.GetEnumerator() |
                    ForEach-Object {
                        If ($_.Value -ne $null)
                        { $cmd.Parameters.AddWithValue("@$($_.Key)", $_.Value) }
                        Else
                        { $cmd.Parameters.AddWithValue("@$($_.Key)", [DBNull]::Value) }
                    } > $null
            }
    
            $ds = New-Object system.Data.DataSet 
            $da = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($cmd)
    
            Try
            {
                [void]$da.fill($ds)
                $conn.Close()
            }
            Catch
            { 
                $Err = $_
                $conn.Close()

                switch ($ErrorActionPreference.tostring())
                {
                    {'SilentlyContinue','Ignore' -contains $_} {}
                    'Stop' {     Throw $Err }
                    'Continue' { Write-Error $Err}
                    Default {    Write-Error $Err}
                }              
            }

            if($AppendServerInstance)
            {
                #Basics from Chad Miller
                $Column =  New-Object Data.DataColumn
                $Column.ColumnName = "MySQLServer"
                $ds.Tables[0].Columns.Add($Column)
                Foreach($row in $ds.Tables[0])
                {
                    $row.MySQLServer = $Computer
                }
                
                $Column =  New-Object Data.DataColumn
                $Column.ColumnName = "MySQLPort"
                $ds.Tables[0].Columns.Add($Column)
                Foreach($row in $ds.Tables[0])
                {
                    $row.MySQLPort = $Port
                }

            }

            switch ($As) 
            { 
                'DataSet' 
                {
                    $ds
                } 
                'DataTable'
                {
                    $ds.Tables
                } 
                'DataRow'
                {
                    $ds.Tables[0]
                }
                'PSObject'
                {
                    #Scrub DBNulls - Provides convenient results you can use comparisons with
                    #Introduces overhead (e.g. ~2000 rows w/ ~80 columns went from .15 Seconds to .65 Seconds - depending on your data could be much more!)
                    foreach ($row in $ds.Tables[0].Rows)
                    {
                        [DBNullScrubber]::DataRowToPSObject($row)
                    }
                }
                'SingleValue'
                {
                    $ds.Tables[0] | Select-Object -ExpandProperty $ds.Tables[0].Columns[0].ColumnName
                }
            }
        }
    }
 }