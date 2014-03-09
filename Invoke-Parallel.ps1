function Invoke-Parallel {
    <#
    .SYNOPSIS
        Function to control parallel processing using runspaces

    .DESCRIPTION
        Function to control parallel processing using runspaces

            Note that each runspace will not have access to variables and commands loaded in your session or in other runspaces.  The parameter parameter is included to help with this.

    .PARAMETER ScriptFile
        File to run against all input objects.  Must include parameter to take in the input object, or use $args.  Optionally, include parameter to take in parameter.  Example: C:\script.ps1

    .PARAMETER ScriptBlock
        Scriptblock to run against all computers.
        
            The parameter block is added for you, allowing behaviour similar to foreach-object:
                Refer to the input object as $_.
                Refer to the parameter parameter as $parameter

    .PARAMETER inputObject
        Run script against these specified objects.

    .PARAMETER parameter
        This object is passed to every script block.  You can use it to pass information to the script block; for example, the path to a logging folder
        
            Reference this object as $parameter if using the scriptblock parameterset.

    .PARAMETER Throttle
        Maximum number of threads to run at a single time.

    .PARAMETER SleepTimer
        Milliseconds to sleep after checking for completed runspaces and in a few other spots.  I would not recommend dropping below 200 or increasing above 500

    .PARAMETER runspaceTimeout
        Maximum time in seconds a single thread can run.  If execution of your code takes longer than this, it is disposed.  Default: 0 (seconds)

        WARNING:  Using this parameter requires that maxQueue be set to throttle (it will be by default) for accurate timing.  Details here:
        http://gallery.technet.microsoft.com/Run-Parallel-Parallel-377fd430

    .PARAMETER maxQueue

        Maximum number of powershell instances to add to runspace pool.  If this is higher than $throttle, $timeout will be inaccurate
        
        If this is equal or less than throttle, there will be a performance impact

        The default value is $throttle times 3, if $runspaceTimeout is not specified
        The default value is $throttle, if $runspaceTimeout is specified

    .PARAMETER logFile

        Path to a file where we can log results, including run time for each thread, whether it completes, completes with errors, or times out.

    .EXAMPLE
        Each example uses Test-ForPacs.ps1 which includes the following code:
            param($computer)

            if(test-connection $computer -count 1 -quiet -BufferSize 16){
                $object = [pscustomobject] @{
                    Computer=$computer;
                    Available=1;
                    Kodak=$(
                        if((test-path "\\$computer\c$\users\public\desktop\Kodak Direct View Pacs.url") -or (test-path "\\$computer\c$\documents and settings\all users
        \desktop\Kodak Direct View Pacs.url") ){"1"}else{"0"}
                    )
                }
            }
            else{
                $object = [pscustomobject] @{
                    Computer=$computer;
                    Available=0;
                    Kodak="NA"
                }
            }

            $object

    .EXAMPLE
        Invoke-Parallel -scriptfile C:\public\Test-ForPacs.ps1 -inputobject $(get-content C:\pcs.txt) -runspaceTimeout 10 -throttle 10

            Pulls list of PCs from C:\pcs.txt,
            Runs Test-ForPacs against each
            If any query takes longer than 10 seconds, it is disposed
            Only run 10 threads at a time

    .EXAMPLE
        Invoke-Parallel -scriptfile C:\public\Test-ForPacs.ps1 -inputobject c-is-ts-91, c-is-ts-95

            Runs against c-is-ts-91, c-is-ts-95 (-computername)
            Runs Test-ForPacs against each

    .EXAMPLE
        $stuff = [pscustomobject] @{
            ContentFile = "windows\system32\drivers\etc\hosts"
            Logfile = "C:\temp\log.txt"
        }
    
        $computers | Invoke-Parallel -parameter $stuff {
            $contentFile = join-path "\\$_\c$" $parameter.contentfile
            Get-Content $contentFile |
                set-content $parameter.logfile
        }

        This example uses the parameter argument.  This parameter is a single object.  To pass multiple items into the script block, we create a custom object (using a PowerShell v3 language) with properties we want to pass in.

        Inside the script block, $parameter is used to reference this parameter object.  This example sets a content file, gets content from that file, and sets it to a predefined log file.

    .FUNCTIONALITY
        PowerShell Language

    .NOTES
        Credit to Boe Prox 
        http://learn-powershell.net/2012/05/10/speedy-network-information-query-using-powershell/
        http://gallery.technet.microsoft.com/scriptcenter/Speedy-Network-Information-5b1406fb#content

    .LINK
        http://gallery.technet.microsoft.com/Run-Parallel-Parallel-377fd430
    #>
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

        [validatescript({test-path (Split-Path $_ -parent)})]
            [string]$logFile = "C:\temp\log.log"
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
                        -CurrentOperation "$startedCount threads defined - $totalCount input objects - $script:completedCount input objects processed"`
                        -PercentComplete ($script:completedCount / $totalCount * 100)

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
                            
                            $script:completedCount++
                        
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
                            
                            $script:completedCount++
                            
                            #Depending on how it hangs, we could still get stuck here as dispose calls a synchronous method on the powershell instance
                            $runspace.powershell.dispose()
                            $runspace.Runspace = $null
                            $runspace.powershell = $null
                            $completedCount++

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
        $script:completedCount = 0
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