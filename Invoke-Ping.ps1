Function Invoke-Ping 
{
<#
.SYNOPSIS
    Ping or test connectivity to systems in parallel
    
.DESCRIPTION
    Ping or test connectivity to systems in parallel

    Default action will run a ping against systems
    If Quiet parameter is specified, simply return an array of systems that responded
    If Detail parameter is specified, test WSMan, RemoteReg, RPC, RDP and/or SMB

    Note: If necessary, verify the final catch block.  Assumptions are made with regards to Test-Connection errors.

.PARAMETER ComputerName
    One or more computers to test

.PARAMETER Quiet
    If specified, only return addresses that responded to Test-Connection

.PARAMETER Detail
    Include one or more additional tests as specified:
        WSMan      via Test-WSMan
        RemoteReg  via Microsoft.Win32.RegistryKey
        RPC        via WMI
        RDP        via port 3389
        SMB        via \\ComputerName\C$
        *          All tests

.PARAMETER Timeout
    Time in seconds before we attempt to dispose an individual query.  Default is 20

.PARAMETER Throttle
    Throttle query to this many parallel runspaces.  Default is 100.

.EXAMPLE
    Invoke-Ping Server1, Server2, Server3 -Detail *

    # Check for WSMan, Remote Registry, Remote RPC, RDP, and SMB (via C$) connectivity against 3 machines

.EXAMPLE
    $Computers | Invoke-Ping

    # Ping computers in $Computers in parallel

.EXAMPLE
    $Responding = $Computers | Invoke-Ping -Quiet
    
    # Create a list of computers that successfully responded to Test-Connection

.FUNCTIONALITY
    Computers

#>
    [cmdletbinding(DefaultParameterSetName='Ping')]
    param(
        [Parameter( ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true, 
                    Position=0)]
        [string[]]$ComputerName,
        
        [Parameter( ParameterSetName='Detail')]
        [validateset("*","WSMan","RemoteReg","RPC","RDP","SMB")]
        [string[]]$Detail,
        
        [Parameter(ParameterSetName='Ping')]
        [switch]$Quiet,
        
        [int]$Timeout = 20,
        
        [int]$Throttle = 100
    )
    Begin
    {

        #http://gallery.technet.microsoft.com/Run-Parallel-Parallel-377fd430
        function Invoke-Parallel {

            [cmdletbinding(DefaultParameterSetName='ScriptBlock')]
            Param (   
                [Parameter(Mandatory=$false,position=0,ParameterSetName='ScriptBlock')]
                    [System.Management.Automation.ScriptBlock]$ScriptBlock,

                [Parameter(Mandatory=$false,ParameterSetName='ScriptFile')]
                [ValidateScript({test-path $_ -pathtype leaf})]
                    $scriptFile,

                [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
                [Alias('CN','__Server','IPAddress','Server','ComputerName')]    
                    [PSObject]$InputObject,

                    [PSObject]$parameter,

                    [int]$Throttle = 20,

                    [int]$SleepTimer = 200,

                    [int]$runspaceTimeout = 0,

                    [int]$maxQueue = $(
                        if($runspaceTimeout -ne 0){$Throttle}
                        else{$throttle * 3}
                    ),

                [validatescript({
                    if(-not $_){ $true }
                    else{ test-path (Split-Path $_ -parent) } 
                })]
                    [string]$logFile = $null
            )
            Begin {
        
                write-verbose "Throttle: '$throttle' SleepTimer '$sleepTimer' runSpaceTimeout '$runspaceTimeout' maxQueue '$maxQueue' logFile '$logFile'"
                #region functions
        
                    Function Get-RunspaceData {
                        [cmdletbinding()]
                        param( [switch]$Wait )

                        #loop through runspaces
                        #if $wait is specified, keep looping until all complete
                        Do {

                            #set more to false for tracking completion
                            $more = $false

                            #Progress bar if we have inputobject count (bound parameter)
                            Write-Progress  -Activity "Running Query"`
                                -Status "Starting threads"`
                                -CurrentOperation "$startedCount threads defined - $totalCount input objects - $global:completedCount input objects processed"`
                                -PercentComplete ($global:completedCount / $totalCount * 100)

                            #run through each runspace.           
                            Foreach($runspace in $runspaces) {
                
                                #get the duration - inaccurate
                                $currentdate = get-date
                                $runtime = $currentdate - $runspace.startTime
                                $runMin = [math]::round( $runtime.totalminutes ,2 )

                                #set up log object
                                $log = "" | select Date, Action, Runtime, Status, Details
                                $log.Action = "Removing:'$($runspace.object)'"
                                $log.Date = $currentdate
                                $log.Runtime = "$runMin minutes"

                                #If runspace completed, end invoke, dispose, recycle, counter++
                                If ($runspace.Runspace.isCompleted) {
                        
                                    $global:completedCount++
                    
                                    #check if there were errors
                                    $runspaceErrors = $runspace.powershell.HadErrors

                                    if($runspaceErrors) {
                            
                                        #set the logging info and move the file to completed
                                        $log.status = "CompletedWithErrors"
                                        Write-Verbose ($log | convertto-csv -Delimiter ";" -NoTypeInformation)[1]

                                    }
                                    else {
                            
                                        #add logging details and cleanup
                                        $log.status = "Completed"
                                        Write-Verbose ($log | convertto-csv -Delimiter ";" -NoTypeInformation)[1]
                                    }

                                    #everything is logged, clean up the runspace
                                    $runspace.powershell.EndInvoke($runspace.Runspace)
                                    $runspace.powershell.dispose()
                                    $runspace.Runspace = $null
                                    $runspace.powershell = $null

                                }

                                #If runtime exceeds max, dispose the runspace
                                ElseIf ( $runspaceTimeout -ne 0 -and $runtime.totalseconds -gt $runspaceTimeout) {
                        
                                    #Depending on how it hangs, we could still get stuck here as dispose calls a synchronous method on the powershell instance
                                    $runspace.powershell.dispose()
                                    $runspace.Runspace = $null
                                    $runspace.powershell = $null
                                    $global:completedCount++

                                    #add logging details and cleanup
                                    $log.status = "TimedOut"
                                    Write-verbose ($log | convertto-csv -Delimiter ";" -NoTypeInformation)[1]

                                }
               
                                #If runspace isn't null set more to true  
                                ElseIf ($runspace.Runspace -ne $null ) {
                                    $log = $null
                                    $more = $true
                                }

                                #log the results if a log file was indicated
                                if($logFile -and $log){
                                    ($log | convertto-csv -Delimiter ";" -NoTypeInformation)[1] | out-file $logFile -append
                                }

                            }

                            #Clean out unused runspace jobs
                            $temphash = $runspaces.clone()
                            $temphash | Where { $_.runspace -eq $Null } | ForEach {
                                $Runspaces.remove($_)
                            }

                            #sleep for a bit if we will loop again
                            if($PSBoundParameters['Wait']){ start-sleep -milliseconds $SleepTimer }

                        #Loop again only if -wait parameter and there are more runspaces to process
                        } while ($more -and $PSBoundParameters['Wait'])
            
                    #End of runspace function
                    }

                #endregion functions
        
                #region Init

                    #Build the scriptblock depending on the parameter used
                    switch ($PSCmdlet.ParameterSetName){
            
                        'ScriptBlock' {
                            $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock("param(`$_, `$parameter)`r`n" + $Scriptblock.ToString())
                        }
            
                        'ScriptFile' {
                            $scriptblock = [scriptblock]::Create($(get-content $scriptFile | out-string))
                        }
            
                        Default {Throw "Must provide ScriptBlock or ScriptFile"; Break}
                    }

                    #Create runspace pool with specified throttle
                    Write-Verbose "Creating runspace pool and session states"
                    $sessionstate = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
                    $runspacepool = [runspacefactory]::CreateRunspacePool(1, $Throttle, $sessionstate, $Host)
                    $runspacepool.Open() 

                    Write-Verbose "Creating empty collection to hold runspace jobs"
                    $Script:runspaces = New-Object System.Collections.ArrayList        
        
                    #If inputObject is bound get a total count and set bound to true
                    $global:__bound = $false
                    $allObjects = @()
                    if( $PSBoundParameters.ContainsKey("inputObject") ){
                        $global:__bound = $true
                    }

                    #Set up log file if specified
                    if( $logFile ){
                        new-item -ItemType file -path $logFile -force | out-null
                        ("" | Select Date, Action, Runtime, Status, Details | ConvertTo-Csv -NoTypeInformation -Delimiter ";")[0] | out-file $logFile
                    }

                    #write initial log entry
                    $log = "" | Select Date, Action, Runtime, Status, Details
                        $log.Date = $launchDate
                        $log.Action = "Batch processing started"
                        $log.Runtime = $null
                        $log.Status = "Started"
                        $log.Details = $null
                        if($logFile) { ($log | convertto-csv -Delimiter ";" -NoTypeInformation)[1] | out-file $logFile -append }

                #endregion INIT

            }

            Process {
        
                #add piped objects to all objects or set all objects to bound input object parameter
                if( -not $global:__bound ){
                    $allObjects += $inputObject
                }
                else{
                    $allObjects = $InputObject
                }
       
            }

            End {
        
                #counts for progress
                $totalCount = $allObjects.count
                $global:completedCount = 0
                $startedCount = 0

                foreach($object in $allObjects){
        
                    #region add scripts to runspace pool
            
                        #Create the powershell instance and supply the scriptblock with the other parameters
                        $powershell = [powershell]::Create().AddScript($ScriptBlock).AddArgument($object).AddArgument($parameter)
    
                        #Add the runspace into the powershell instance
                        $powershell.RunspacePool = $runspacepool
    
                        #Create a temporary collection for each runspace
                        $temp = "" | Select-Object PowerShell, StartTime, object, Runspace
                        $temp.PowerShell = $powershell
                        $temp.StartTime = get-date
                        $temp.object = $object
    
                        #Save the handle output when calling BeginInvoke() that will be used later to end the runspace
                        $temp.Runspace = $powershell.BeginInvoke()
                        $startedCount++

                        #Add the temp tracking info to $runspaces collection
                        Write-Verbose ( "Adding {0} to collection at {1}" -f $temp.object, $temp.starttime.tostring() )
                        $runspaces.Add($temp) | Out-Null
        
                        #loop through existing runspaces one time
                        Get-RunspaceData

                        #If we have more running than max queue (used to control timeout accuracy)
                        $firstRun = $true
                        while ($runspaces.count -ge $maxQueue) {

                            #give verbose output
                            if($firstRun){
                                Write-Verbose "$($runspaces.count) items running - exceeded $maxQueue limit."
                            }
                            $firstRun = $false
                
                            #run get-runspace data and sleep for a short while
                            Get-RunspaceData
                            Start-Sleep -milliseconds $sleepTimer
                
                        }

                    #endregion add scripts to runspace pool

                }
                 
                Write-Verbose ( "Finish processing the remaining runspace jobs: {0}" -f (@(($runspaces | Where {$_.Runspace -ne $Null}).Count)) )
                Get-RunspaceData -wait

                Write-Verbose "Closing the runspace pool"
                $runspacepool.close()    
        
                #collect garbage
                [gc]::Collect()           
            }
        }

        Write-Verbose "PSBoundParameters = $($PSBoundParameters | Out-String)"
        
        #Build up an array of computers to test
        $bound = $PSBoundParameters.keys -contains "ComputerName"
        if(-not $bound)
        {
            [System.Collections.ArrayList]$AllComputers = @()
        }
    }
    Process
    {

        #Handle both pipeline and bound parameter.  We don't want to stream objects, defeats purpose of parallelizing work
        if($bound)
        {
            $AllComputers = $ComputerName
        }
        Else
        {
            $AllComputers.add($ComputerName) | Out-Null
        }

    }
    End
    {

        $params = @($Detail, $Quiet)
        Invoke-Parallel -Throttle $Throttle -runspaceTimeout $Timeout -InputObject $AllComputers -parameter $params -ScriptBlock {
        
            $computer = $_.trim()
            $detail = $parameter[0]
            $quiet = $parameter[1]

            #They want detail, define and run test-server
            if($detail)
            {
                Try
                {
                    #Modification of jrich's Test-Server function: https://gallery.technet.microsoft.com/scriptcenter/Powershell-Test-Server-e0cdea9a
                    Function Test-Server{
                        [cmdletBinding()]
                        param(
	                        [parameter(
                                Mandatory=$true,
                                ValueFromPipeline=$true)]
	                        [string[]]$ComputerName,
                            [switch]$All,
                            [parameter(Mandatory=$false)]
	                        [switch]$CredSSP,
                            [switch]$RemoteReg,
                            [switch]$RDP,
                            [switch]$RPC,
                            [switch]$SMB,
                            [switch]$WSMAN,
                            [switch]$IPV6,
	                        [Management.Automation.PSCredential]$Credential
                        )
                            begin
                            {
	                            $total = Get-Date
	                            $results = @()
	                            if($credssp -and -not $Credential)
                                {
                                    Throw "Must supply Credentials with CredSSP test"
                                }

                                [string[]]$props = write-output Name, IP, Domain, Ping, WSMAN, CredSSP, RemoteReg, RPC, RDP, SMB

                                #Hash table to create PSObjects later, compatible with ps2...
                                $Hash = @{}
                                foreach($prop in $props)
                                {
                                    $Hash.Add($prop,$null)
                                }

                                function Test-Port{
                                    [cmdletbinding()]
                                    Param(
                                        [string]$srv,
                                        $port=135,
                                        $timeout=3000
                                    )
                                    $ErrorActionPreference = "SilentlyContinue"
                                    $tcpclient = new-Object system.Net.Sockets.TcpClient
                                    $iar = $tcpclient.BeginConnect($srv,$port,$null,$null)
                                    $wait = $iar.AsyncWaitHandle.WaitOne($timeout,$false)
                                    if(-not $wait)
                                    {
                                        $tcpclient.Close()
                                        Write-Verbose "Connection Timeout to $srv`:$port"
                                        $false
                                    }
                                    else
                                    {
                                        Try
                                        {
                                            $tcpclient.EndConnect($iar) | out-Null
                                            $true
                                        }
                                        Catch
                                        {
                                            write-verbose "Error for $srv`:$port`: $_"
                                            $false
                                        }
                                        $tcpclient.Close()
                                    }
                                }
                            }

                            process
                            {
                                foreach($name in $computername)
                                {
	                                $dt = $cdt= Get-Date
	                                Write-verbose "Testing: $Name"
	                                $failed = 0
	                                try{
	                                    $DNSEntity = [Net.Dns]::GetHostEntry($name)
	                                    $domain = ($DNSEntity.hostname).replace("$name.","")
	                                    $ips = $DNSEntity.AddressList | %{
                                            if(-not ( -not $IPV6 -and $_.AddressFamily -like "InterNetworkV6" ))
                                            {
                                                $_.IPAddressToString
                                            }
                                        }
	                                }
	                                catch
	                                {
		                                $rst = New-Object -TypeName PSObject -Property $Hash | Select -Property $props
		                                $rst.name = $name
		                                $results += $rst
		                                $failed = 1
	                                }
	                                Write-verbose "DNS:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
	                                if($failed -eq 0){
	                                    foreach($ip in $ips)
	                                    {
	    
		                                    $rst = New-Object -TypeName PSObject -Property $Hash | Select -Property $props
	                                        $rst.name = $name
		                                    $rst.ip = $ip
		                                    $rst.domain = $domain
		            
                                            if($RDP -or $All)
                                            {
                                                ####RDP Check (firewall may block rest so do before ping
		                                        try{
                                                    $socket = New-Object Net.Sockets.TcpClient($name, 3389) -ErrorAction stop
		                                            if($socket -eq $null)
		                                            {
			                                            $rst.RDP = $false
		                                            }
		                                            else
		                                            {
			                                            $rst.RDP = $true
			                                            $socket.close()
		                                            }
                                                }
                                                catch
                                                {
                                                    $rst.RDP = $false
                                                    Write-Verbose "Error testing RDP: $_"
                                                }
                                            }
		                                Write-verbose "RDP:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                                        #########ping
	                                    if(test-connection $ip -count 2 -Quiet)
	                                    {
	                                        Write-verbose "PING:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
			                                $rst.ping = $true
			    
                                            if($WSMAN -or $All)
                                            {
                                                try{############wsman
				                                    Test-WSMan $ip -ErrorAction stop | Out-Null
				                                    $rst.WSMAN = $true
				                                }
			                                    catch
				                                {
                                                    $rst.WSMAN = $false
                                                    Write-Verbose "Error testing WSMAN: $_"
                                                }
				                                Write-verbose "WSMAN:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
			                                    if($rst.WSMAN -and $credssp) ########### credssp
			                                    {
				                                    try{
					                                    Test-WSMan $ip -Authentication Credssp -Credential $cred -ErrorAction stop
					                                    $rst.CredSSP = $true
					                                }
				                                    catch
					                                {
                                                        $rst.CredSSP = $false
                                                        Write-Verbose "Error testing CredSSP: $_"
                                                    }
				                                    Write-verbose "CredSSP:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
			                                    }
                                            }
                                            if($RemoteReg -or $All)
                                            {
			                                    try ########remote reg
			                                    {
				                                    [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $ip) | Out-Null
				                                    $rst.remotereg = $true
			                                    }
			                                    catch
				                                {
                                                    $rst.remotereg = $false
                                                    Write-Verbose "Error testing RemoteRegistry: $_"
                                                }
			                                    Write-verbose "remote reg:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                                            }
                                            if($RPC -or $All)
                                            {
			                                    try ######### wmi
			                                    {	
				                                    $w = [wmi] ''
				                                    $w.psbase.options.timeout = 15000000
				                                    $w.path = "\\$Name\root\cimv2:Win32_ComputerSystem.Name='$Name'"
				                                    $w | select none | Out-Null
				                                    $rst.RPC = $true
			                                    }
			                                    catch
				                                {
                                                    $rst.rpc = $false
                                                    Write-Verbose "Error testing WMI/RPC: $_"
                                                }
			                                    Write-verbose "WMI/RPC:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                                            }
                                            if($SMB -or $All)
                                            {

                                                #Use set location and resulting errors.  push and pop current location
                    	                        try ######### C$
			                                    {	
                                                    $path = "\\$name\c$"
				                                    Push-Location -Path $path -ErrorAction stop
				                                    $rst.SMB = $true
                                                    Pop-Location
			                                    }
			                                    catch
				                                {
                                                    $rst.SMB = $false
                                                    Write-Verbose "Error testing SMB: $_"
                                                }
			                                    Write-verbose "SMB:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"

                                            }
	                                    }
		                                else
		                                {
			                                $rst.ping = $false
			                                $rst.wsman = $false
			                                $rst.credssp = $false
			                                $rst.remotereg = $false
			                                $rst.rpc = $false
                                            $rst.smb = $false
		                                }
		                                $results += $rst	
	                                }
                                }
	                            Write-Verbose "Time for $($Name): $((New-TimeSpan $cdt ($dt)).totalseconds)"
	                            Write-Verbose "----------------------------"
                                }
                            }
                            end
                            {
	                            Write-Verbose "Time for all: $((New-TimeSpan $total ($dt)).totalseconds)"
	                            Write-Verbose "----------------------------"
                                return $results
                            }
                        }
                    
                    #Build up parameters for Test-Server and run it
                        $TestServerParams = @{
                            ComputerName = $Computer
                            ErrorAction = "Stop"
                        }

                        if($detail -eq "*"){
                            $detail = "WSMan","RemoteReg","RPC","RDP","SMB" 
                        }

                        $detail | Select -Unique | Foreach-Object { $TestServerParams.add($_,$True) }
                        Test-Server @TestServerParams | Select -Property $( "Name", "IP", "Domain", "Ping" + $detail )
                }
                Catch
                {
                    Write-Warning "Error with Test-Server: $_"
                }
            }
            #We just want ping output
            else
            {
                Try
                {
                    #Pick out a few properties, add a status label.  If quiet output, just return the address
                    $result = $null
                    if( $result = @( Test-Connection -ComputerName $computer -Count 2 -erroraction Stop ) )
                    {
                        $result | Select -first 1 -Property Address, IPV4Address, IPV6Address, ResponseTime, @{ label = "STATUS"; expression = {"Responding"} } |
                            ForEach-Object {
                                
                                if( $quiet )
                                {
                                    $_.address
                                }
                                else
                                {
                                    $_
                                }
                            }
                    }
                }
                Catch
                {
                    if(-not $quiet)
                    {
                        #Ping failed.  I'm likely making inappropriate assumptions here, let me know if this is the case : )
                        $err = $_.tostring()

                        if($_ -match "No such host is known")
                        {
                            $status = "Unknown host"
                        }
                        elseif($_ -match "Error due to lack of resources")
                        {
                            $status = "No Response"
                        }
                        else
                        {
                            $status = "Error: $err"
                        }

                        "" | Select -Property @{ label = "Address"; expression = {$computer} }, IPV4Address, IPV6Address, ResponseTime, @{ label = "STATUS"; expression = {$status} }
                    }
                }
            }
        }
    }
}