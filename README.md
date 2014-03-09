PowerShell
==========

Various PowerShell functions and scripts

# Instructions

Most of these files contain functions.  For example, Invoke-Sqlcmd2.ps1 contains the Invoke-Sqlcmd2 function.

    #Download and unblock the file(s).
    #Dot source the files as appropriate.
    . "\\Path\To\Invoke-Sqlcmd2"
    
    #Use the functions
    Get-Help Invoke-Sqlcmd2 -Full
    Invoke-Sqlcmd2 -ServerInstance MyServer\MyInstance -Query "SELECT ServerName, VCNumCPU FROM tblServerInfo" -As PSObject -Credential $cred | ?{$_.VCNumCPU -gt 8}
    
# Invoke-Sqlcmd2

I'm a fan of Invoke-Sqlcmd2.  Props to Chad Miller and the other contributors for a fantastic function.  I've added a few features with much help from others:

* Added pipeline support, with the option to append a ServerInstance column to keep track of your results:
  * ![Add ServerInstance column](/Images/ISCAppendServerInstance.png)
* Added the option to pass in a PSCredential instead of a plaintext password
  * ![Use PSCredential](/Images/ISCCreds.png)
* Added PSObject output type to allow comparisons without odd [System.DBNull]::Value behavior:
  * Previously, many PowerShell comparisons resulted in errors:
   * ![GT Comparison Errors](/Images/ISCCompareGT.png)
  * With PSObject output, comparisons behave as expected:
   * ![GT Comparison Fix](/Images/ISCCompareGTFix.png)
  * Previously, testing for nonnull / null values did not work as expected:
   * ![NotNull Fails](/Images/ISCCompareNotNull.png)
  * With PSObject output, null values are excluded as expected
   * ![NotNull Fails Fix](/Images/ISCCompareNotNullFix.png)
  * Speed comparison between DataRow and PSObject output with 1854 rows, 84 columns:
   * ![Speed PSObject v Datarow](/Images/ISCPSObjectVsDatarow.png)

#### That DBNull behavior is strange!  Why doesn't it behave as expected?

I agree.  PowerShell does a lot of work under the covers to provide behavior a non-developer might expect.  From my perspective, PowerShell should handle [System.DBNull]::Value like it does Null.  Please vote up [this Microsoft Connect suggestion](https://connect.microsoft.com/PowerShell/feedback/details/830412/provide-expected-comparison-handling-for-dbnull) if you agree!

Major thanks to [Dave Wyatt](http://powershell.org/wp/forums/topic/dealing-with-dbnull/) for providing the C# code that produces the PSObject output type as a workaround for this.

#### You clearly don't know SQL.  Why are you working on this function?

I absolutely do not know SQL.  If I'm doing something wrong please let me know!

I have a number of projects at work that involve PowerShell wrappers for SQL queries.  Invoke-Sqlcmd2 has been my go-to command for this - now that I'm spending more time with it, I plan to add some functionality.

#### Why is Invoke-Sqlcmd2 here?

I copied the code here to avoid the automated tweets for Poshcode.org submissions.  I make many small changes and didn't want to spam twitter : )

# Help!

Would love contributors, suggestions, feedback, etc.
