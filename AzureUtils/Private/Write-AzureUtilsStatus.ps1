function Write-AzureUtilsStatus {
    <#
        .SYNOPSIS
            Writes a leveled, color-coded status line to the host console.
        .DESCRIPTION
            Renders lines such as '    [INFO] ...' / '   [ERROR] ...' where the
            bracketed level is right-aligned so the brackets line up regardless of
            level length. Used for the export progress report. Writes to the host
            only (does not emit to the pipeline).
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string] $Level = 'INFO',

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Message
    )

    $color = switch ($Level) {
        'INFO'  { 'White' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
    }

    # "[INFO]" -> "    [INFO]", "[ERROR]" -> "   [ERROR]" (brackets aligned).
    $tag = "[$Level]".PadLeft(10)
    Write-Host "$tag $Message" -ForegroundColor $color
}
