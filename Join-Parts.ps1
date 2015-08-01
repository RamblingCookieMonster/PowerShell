function Join-Parts
{
    <#
    .SYNOPSIS
        Join strings with a specified separator.

    .DESCRIPTION
        Join strings with a specified separator.

        This strips out null values and any duplicate separator characters.

        See examples for clarification.

    .PARAMETER Separator
        Separator to join with

    .PARAMETER Parts
        Strings to join

    .EXAMPLE
        Join-Parts -Separator "/" this //should $Null /work/ /well

        # Output: this/should/work/well

    .EXAMPLE
        Join-Parts -Parts http://this.com, should, /work/, /wel

        # Output: http://this.com/should/work/wel

    .EXAMPLE
        Join-Parts -Separator "?" this ?should work ???well

        # Output: this?should?work?well

    .EXAMPLE

        $CouldBeOneOrMore = @( "JustOne" )
        Join-Parts -Separator ? -Parts CouldBeOneOrMore

        # Output JustOne

        # If you have an arbitrary count of parts coming in,
        # Unnecessary separators will not be added

    .NOTES
        Credit to Rob C. and Michael S. from this post:
        http://stackoverflow.com/questions/9593535/best-way-to-join-parts-with-a-separator-in-powershell
    
    #>
    [cmdletbinding()]
    param
    (
    [string]$Separator = "/",

    [parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Parts = $null
        
    )

    ( $Parts |
        Where { $_ } |
        Foreach { ( [string]$_ ).trim($Separator) } |
        Where { $_ }
    ) -join $Separator
}
