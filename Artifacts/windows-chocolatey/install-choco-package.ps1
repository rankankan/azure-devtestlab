##################################################################################################>
#
# Optional parameters to this script file.
#

[CmdletBinding()]
param(
    # space-, comma- or semicolon-separated list of Chocolatey packages.
    [string] $Packages,
    [int] $PSVersionRequired = 3
)

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = 'Stop'

# Suppress progress bar output.
$ProgressPreference = 'SilentlyContinue'

###################################################################################################
#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    "`nThe artifact failed to apply.`n"

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

###################################################################################################
#
# Functions used in this script.
#

function Validate-Params
{
    [CmdletBinding()]
    param(
        [string] $Packages
    )

    if ([string]::IsNullOrEmpty($Packages))
    {
        throw 'Packages parameter is required.'
    }
}

function Ensure-PowerShell
{
    [CmdletBinding()]
    param(
        [int] $Version
    )

    if ($PSVersionTable.PSVersion.Major -lt $Version)
    {
        throw "The current version of PowerShell is $($PSVersionTable.PSVersion.Major). Prior to running this artifact, ensure you have PowerShell $Version or higher installed."
    }
}

function Invoke-ExpressionImpl
{
    [CmdletBinding()]
    param(
        $Expression
    )

    # This call will normally not throw. So, when setting -ErrorVariable it causes it to throw.
    # The variable $expError contains whatever is sent to stderr.
    iex $Expression -ErrorVariable expError

    # This check allows us to capture cases where the command we execute exits with an error code.
    # In that case, we do want to throw an exception with whatever is in stderr. Normally, when
    # Invoke-Expression throws, the error will come the normal way (i.e. $Error) and pass via the
    # catch below.
    if ($LastExitCode -or $expError)
    {
        if ($expError[0])
        {
            throw $expError[0]
        }
        throw "Command failed with exit code '$LastExitCode'."
    }
}

###################################################################################################
#
# Main execution block.
#

try
{
    # Ensure we set the working directory to that of the script.
    pushd $PSScriptRoot

    Validate-Params -Packages $Packages

    Ensure-PowerShell -Version $PSVersionRequired
    Enable-PSRemoting -Force -SkipNetworkProfileCheck

    Invoke-ExpressionImpl -Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

    $Packages = $Packages.split(',; ', [StringSplitOptions]::RemoveEmptyEntries) -join ' '
    $expression = "choco install -y -f --failstderr --no-progress --stoponfirstfailure $Packages"
    Invoke-ExpressionImpl -Expression $expression 

    "`nThe artifact was applied successfully.`n"
}
finally
{
    popd
}
