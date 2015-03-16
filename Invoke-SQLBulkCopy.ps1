function Invoke-SQLBulkCopy {
<#
.SYNOPSIS
    Use the .NET SQLBulkCopy class to write data to SQL Server tables.

.DESCRIPTION
    Use the .NET SQLBulkCopy class to write data to SQL Server tables.
    
    The data source is not limited to SQL Server; any data source can be used, as long as the data can be loaded to a DataTable instance or read with a IDataReader instance.

.PARAMETER ServerInstance
    A SQL instance to run against. For default instances, only specify the computer name: "MyComputer". For named instances, use the format "ComputerName\InstanceName".

.PARAMETER Database
    A string specifying the name of a database.

.PARAMETER Credential
    Specifies A PSCredential for SQL Server Authentication connection to an instance of the Database Engine.  If -Credential is not specified, Invoke-Sqlcmd attempts a Windows Authentication connection using the Windows account running the PowerShell session.
    SECURITY NOTE: If you use the -Debug switch, the connectionstring including plain text password will be sent to the debug stream.

.PARAMETER ConnectionTimeout
    Specifies the number of seconds when Invoke-Sqlcmd2 times out if it cannot successfully connect to an instance of the Database Engine. The timeout value must be an integer between 0 and 65534. If 0 is specified, connection attempts do not time out.

.PARAMETER Force
    If specified, skip the confirm prompt

.PARAMETER  BatchSize
	The batch size for the bulk copy operation.

.PARAMETER  NotifyAfter
	The number of rows to fire the notification event after transferring.  0 means don't notify.  Notifications hit the verbose stream (use -verbose to see them)

.PARAMETER ColumnMappings
    A hash table with the format Key = SourceColumn, Value = DestinationColumn

    Example, converting SourceColumn FirstName to DestinationColumn surname, and converting SourceColumn LastName to DestinationColumn givenname
        @{
            FirstName = 'surname'
            LastName  = 'givenname'
        }

.PARAMETER SQLConnection
    An existing SQLConnection to use

.EXAMPLE
    Invoke-SQLBulkCopy -ServerInstance $SQLInstance -Database $Database -Table $SQLTable -DataTable $DataTable -verbose -NotifyAfter 1000 -force

    Insert a datatable into a table.  Notify via verbose every 1000 rows. Don't prompt for confirmation.

.OUTPUTS
    None
        Produces no output

.NOTES
    This function borrows from:
        Chad Miller's Write-Datatable
        jbs534's Invoke-SQLBulkCopy
        Mike Shepard's Invoke-BulkCopy from SQLPSX

.LINK
    https://github.com/RamblingCookieMonster/PowerShell

.LINK
    http://msdn.microsoft.com/en-us/library/30c3y597

.LINK
    Out-DataTable

.LINK
    Invoke-Sqlcmd2

.LINK
    New-SQLConnection

.FUNCTIONALITY
    SQL
#>
    [cmdletBinding( DefaultParameterSetName = 'Instance',
                    SupportsShouldProcess = $true,
                    ConfirmImpact = 'High' )]
    param(
        [parameter( Position = 0,
                    Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName= $true)]
        [System.Data.DataTable]
        $DataTable,

        [Parameter( ParameterSetName = 'Instance',
                    Position = 1,
                    Mandatory = $true,
                    ValueFromPipeline = $false,
                    ValueFromPipelineByPropertyName = $true)]
        [Alias( 'SQLInstance', 'Server', 'Instance' )]
        [string]
        $ServerInstance,

        [Parameter( ParameterSetName = 'Connection',
                    Position = 1,
                    Mandatory = $true,
                    ValueFromPipeline = $false,
                    ValueFromPipelineByPropertyName = $false,
                    ValueFromRemainingArguments = $false )]
        [Alias( 'Connection', 'Conn' )]
        [System.Data.SqlClient.SQLConnection]
        $SQLConnection,

        [Parameter( Position = 2,
                    Mandatory = $true)]
        [string]
        $Database,

        [parameter( Position = 3,
                    Mandatory = $true)]
        [string]
        $Table,

        [Parameter( ParameterSetName = 'Instance',
                    Position = 4,
                    Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $Credential,
    
        [Parameter( ParameterSetName = 'Instance',
                    Position = 5,
                    Mandatory = $false)]
        [Int32]
        $ConnectionTimeout=15,

        [switch]
        $Temp,

        [int]
        $BatchSize = 0,

        [int]
        $NotifyAfter = 0,

        [System.Collections.Hashtable]
        $ColumnMappings,

        [switch]
        $Force

    )
    begin {

        #Handle existing connections
        if ($PSBoundParameters.Keys -contains "SQLConnection")
        {
            if ($SQLConnection.State -notlike "Open")
            {
                Try
                {
                    $SQLConnection.Open()
                }
                Catch
                {
                    Throw $_
                }
            }

            if ($Database -and $SQLConnection.Database -notlike $Database)
            {
                Try
                {
                    $SQLConnection.ChangeDatabase($Database)
                }
                Catch
                {
                    Throw "Could not change Connection database '$($SQLConnection.Database)' to $Database`: $_"
                }
            }

            if ($SQLConnection.state -notlike "Open")
            {
                Throw "SQLConnection is not open"
            }
        }
        else
        {
            if ($Credential) 
            {
                $ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4}" -f $ServerInstance,$Database,$Credential.UserName,$Credential.GetNetworkCredential().Password,$ConnectionTimeout
            }
            else 
            {
                $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $ServerInstance,$Database,$ConnectionTimeout
            } 
            
            $SQLConnection = New-Object System.Data.SqlClient.SQLConnection
            $SQLConnection.ConnectionString = $ConnectionString 
            
            Write-Debug "ConnectionString $ConnectionString"
            
            Try
            {
                $SQLConnection.Open() 
            }
            Catch
            {
                Write-Error $_
                continue
            }
        }

        $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy $SQLConnection
        $bulkCopy.BatchSize = $BatchSize
        $bulkCopy.BulkCopyTimeout = 10000000

        if ($Temp)
        {
            $bulkCopy.DestinationTableName = "#$Table"
        }
        else
        {
            $bulkCopy.DestinationTableName = $Table
        }
        if ($NotifyAfter -gt 0)
        {
            $bulkCopy.NotifyAfter=$notifyafter
		    $bulkCopy.Add_SQlRowscopied( {Write-Verbose "$($args[1].RowsCopied) rows copied"} )
        }
        else
        {
            $bulkCopy.NotifyAfter=$DataTable.Rows.count
		    $bulkCopy.Add_SQlRowscopied( {Write-Verbose "$($args[1].RowsCopied) rows copied"} )
        }       
    }
    process
    {
        try
        {
            foreach ($column in ( $DataTable.Columns | Select -ExpandProperty ColumnName ))
            {
                if ( $PSBoundParameters.ContainsKey( 'ColumnMappings') -and $ColumnMappings.ContainsKey($column) )
                {
                    [void]$bulkCopy.ColumnMappings.Add($column,$ColumnMappings[$column])
                }
                else
                {
                    [void]$bulkCopy.ColumnMappings.Add($column,$column)
                }
            }
            Write-Verbose "ColumnMappings: $($bulkCopy.ColumnMappings | Format-Table -Property SourceColumn, DestinationColumn -AutoSize | Out-String)"
            
            if ($Force -or $PSCmdlet.ShouldProcess("$($DataTable.Rows.Count) rows, with BoundParameters $($PSBoundParameters | Out-String)", "SQL Bulk Copy"))
            {
                $bulkCopy.WriteToServer($DataTable)
            }
        }
        catch
        {
            throw $_
        }
    }
    end
    {
        #Only dispose of the connection if we created it
        if($PSBoundParameters.Keys -notcontains 'SQLConnection')
        {
            $SQLConnection.Close()
            $SQLConnection.Dispose()
        }
    }
}