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

I'm a fan of Invoke-Sqlcmd2.  Props to Chad Miller and the other contributors for a fantastic function.

### You clearly don't know SQL.  Why are you working on this function?

I absolutely do not know SQL.  If I'm doing something wrong please let me know!

I have a number of projects at work that involve PowerShell wrappers for SQL queries.  Invoke-Sqlcmd2 has been my go-to command for this - now that I'm spending more time with it, I plan to add some functionality.

### Why is Invoke-Sqlcmd2 here?

I copied the code here to avoid the automated tweets for Poshcode.org submissions.  I make many small changes and didn't want to spam twitter : )

# Help!

Would love contributors, suggestions, feedback, etc.
