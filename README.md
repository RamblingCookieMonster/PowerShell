# PowerShell

Various PowerShell functions and scripts.  These are published as [WFTools](https://www.powershellgallery.com/packages/WFTools/0.1.39) on the PowerShell Gallery (thanks to @psrdrgz for the idea!)

Two functions have been migrated to their own repositories to simplify and enable improved collaboration.  Copies remain here for historical purposes and may be updated:

* [Invoke-Parallel](https://github.com/RamblingCookieMonster/Invoke-Parallel)
* [Invoke-SqlCmd2](https://github.com/sqlcollaborative/Invoke-SqlCmd2)

## Instructions

These files contain functions.  For example, Invoke-Sqlcmd2.ps1 contains the Invoke-Sqlcmd2 function.

```powershell
    # PowerShell 5, or PackageManagement available?
    Install-Module WFTools -Force
    Import-Module WFTools
    Get-Command -Module WFTools
    Get-Help ConvertTo-FlatObject -Full

    # Alternatively:
    # Download and unblock the file(s).
    # Dot source the file(s) as appropriate.
    . "\\Path\To\Invoke-Sqlcmd2"

    # Use the functions
    Get-Help Invoke-Sqlcmd2 -Full
    Invoke-Sqlcmd2 -ServerInstance MyServer\MyInstance -Query "SELECT ServerName, VCNumCPU FROM tblServerInfo" -As PSObject -Credential $cred | ?{$_.VCNumCPU -gt 8}
```

Note: Using Import-Module to load these functions will break certain scenarios for Invoke-Parallel's variable import ([details](https://github.com/RamblingCookieMonster/Invoke-Parallel/issues/16#issuecomment-77167598)) - dot source the function if you need this.

## TechNet Galleries Contributions

Many of these functions started out in the Technet Gallery.  You might find more context at these links.

* [ConvertFrom-SID](http://gallery.technet.microsoft.com/ConvertFrom-SID-Map-SID-to-dcb354d9)
* [Get-ADGroupMembers](http://gallery.technet.microsoft.com/Get-ADGroupMembers-Get-AD-0ee3ae48)
* [Get-FolderEntry](http://gallery.technet.microsoft.com/Get-FolderEntry-List-all-bce0ff43)
* [Get-GPPFile](http://gallery.technet.microsoft.com/Get-GPPFile-Get-Group-26b11d0b)
* [Get-GPPShortcut](http://gallery.technet.microsoft.com/Get-GPPShortcut-Get-Group-5f321329)
* [Get-InstalledSoftware](http://gallery.technet.microsoft.com/Get-InstalledSoftware-Get-5607a465)
* [Get-MSSQLColumn](http://gallery.technet.microsoft.com/Get-MSSQLColumn-Get-f7cd7904)
* [Get-NetworkStatistics](http://gallery.technet.microsoft.com/Get-NetworkStatistics-66057d71)
* [Get-PropertyType](http://gallery.technet.microsoft.com/Get-PropertyType-546b9eeb)
* [Get-ScheduledTasks](http://gallery.technet.microsoft.com/Get-ScheduledTasks-Get-d2207def)
* [Get-UACSetting](http://gallery.technet.microsoft.com/Get-UACSetting-Query-UAC-7afae0de)
* [Get-UserSession](http://gallery.technet.microsoft.com/Get-UserSessions-Parse-b4c97837)
* [Invoke-Parallel](http://gallery.technet.microsoft.com/Run-Parallel-Parallel-377fd430)
* [Open-ISEFunction](http://gallery.technet.microsoft.com/Open-defined-functions-in-22788d0f)
* [Test-ForAdmin](http://gallery.technet.microsoft.com/Test-ForAdmin-Verify-75d84aba)

## Help!

Would love contributors, suggestions, feedback, and other help!
