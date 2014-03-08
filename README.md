PowerShell
==========

Various PowerShell functions and scripts

# Instructions

Most of these files contain functions.  For example, Invoke-Sqlcmd2.ps1 contains the Invoke-Sqlcmd2 function.

    #Download and unblock the file(s).
    #Dot source the files as appropriate.
    . "\\Path\To\Invoke-Sqlcmd2"
    
    #Use the functions
    Invoke-Sqlcmd2 -ServerInstance MyServer\MyInstance -Query "SELECT ServerName, VCNumCPU FROM tblServerInfo" -As PSObject -Credential $cred | ?{$_.VCNumCPU -gt 8}
    
# Help!

Would love contributors, suggestions, feedback, etc.  I moved Invoke-Sqlcmd2 here to avoid the automated tweets for Poshcode.org submissions.  I make many small changes and didn't want to spam twitter : )