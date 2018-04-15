
# write data to main http response
function Write-ToResponse
{
    param (
        [Parameter()]
        $Value,

        [Parameter()]
        $Response = $null,

        [Parameter()]
        [string]
        $ContentType = $null,

        [switch]
        $NotFound
    )

    if ($Response -eq $null)
    {
        $Response = $PodeSession.Web.Response
    }

    if ($NotFound)
    {
        $Response.StatusCode = 404
        return
    }

    if (![string]::IsNullOrWhiteSpace($ContentType))
    {
        $Response.ContentType = $ContentType
    }

    $writer = New-Object -TypeName System.IO.StreamWriter -ArgumentList $Response.OutputStream
    $writer.WriteLine([string]$Value)
    $writer.Close()
}


function Write-ToResponseFromFile
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Path,

        [Parameter()]
        $Response = $null
    )

    # if the file doesnt exist then just fail on 404
    if (!(Test-Path $Path))
    {
        Write-ToResponse -Response $Response -NotFound
    }
    else
    {
        $content = Get-Content -Path $Path

        # are we dealing with a dynamic ps file?
        $ext = [System.IO.Path]::GetExtension($Path)
        if (Test-Empty $ext)
        {
            Write-ToResponse -Value $content -Response $Response
            return
        }

        switch ($ext.Trim('.').ToLowerInvariant())
        {
            { @('pscss', 'psjs') -icontains $_ }
                {
                    $content = ConvertFrom-PSFile -Content $content
                }
        }

        Write-ToResponse -Value $content -Response $Response -ContentType (Get-ContentType -Extension $ext)
    }
}

function Write-JsonResponse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Value,

        [Parameter()]
        $Response = $null,

        [switch]
        $NoConvert
    )

    if (!$NoConvert)
    {
        $Value = ($Value | ConvertTo-Json)
    }

    Write-ToResponse -Value $Value -Response $Response -ContentType 'application/json; charset=utf-8'
}

function Write-JsonResponseFromFile
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Path,

        [Parameter()]
        $Response = $null
    )

    if (!(Test-Path $Path))
    {
        Write-ToResponse -Response $Response -NotFound
    }
    else
    {
        $content = Get-Content -Path $Path
        Write-JsonResponse -Value $content -Response $Response -NoConvert
    }
}

function Write-XmlResponse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Value,

        [Parameter()]
        $Response = $null,

        [switch]
        $NoConvert
    )

    if (!$NoConvert)
    {
        $Value = ($Value | ConvertTo-Xml)
    }

    Write-ToResponse -Value $Value -Response $Response -ContentType 'application/xml; charset=utf-8'
}

function Write-XmlResponseFromFile
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Path,

        [Parameter()]
        $Response = $null
    )

    if (!(Test-Path $Path))
    {
        Write-ToResponse -Response $Response -NotFound
    }
    else
    {
        $content = Get-Content -Path $Path
        Write-XmlResponse -Value $content -Response $Response -NoConvert
    }
}

function Write-HtmlResponse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Value,

        [Parameter()]
        $Response = $null,

        [switch]
        $NoConvert
    )

    if (!$NoConvert)
    {
        $Value = ($Value | ConvertTo-Html)
    }

    Write-ToResponse -Value $Value -Response $Response -ContentType 'text/html; charset=utf-8'
}

function Write-HtmlResponseFromFile
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Path,

        [Parameter()]
        $Response = $null
    )

    if (!(Test-Path $Path))
    {
        Write-ToResponse -Response $Response -NotFound
    }
    else
    {
        $content = Get-Content -Path $Path
        Write-HtmlResponse -Value $content -Response $Response -NoConvert
    }
}

# include helper to import the content of a view into another view
function Include
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    # get extension from the path
    $ext = [System.IO.Path]::GetExtension($Path)
    if (Test-Empty $ext)
    {
        throw "Missing extension on path when attempting to include: $($Path)"
    }

    # only look in the view directory
    $Path = (Join-Path 'views' $Path)

    if (!(Test-Path $Path))
    {
        throw "File not found at path: $($Path)"
    }

    return (Get-Content -Path $Path -Raw)
}

function Write-ViewResponse
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Path,

        [Parameter()]
        $Response = $null,

        [Parameter()]
        $Data = @{}
    )

    # add view engine extension
    $ext = [System.IO.Path]::GetExtension($Path)
    if ([string]::IsNullOrWhiteSpace($ext))
    {
        $Path += ".$($PodeSession.ViewEngine.ToLowerInvariant())"
    }

    # only look in the view directory
    $Path = (Join-Path 'views' $Path)

    if (!(Test-Path $Path))
    {
        Write-ToResponse -Response $Response -NotFound
    }

    $content = Get-Content -Path $Path -Raw

    switch ($PodeSession.ViewEngine.ToLowerInvariant())
    {
        'pshtml'
            {
                $content = ConvertFrom-PSFile -Content $content -Data $Data
            }
    }

    Write-HtmlResponse -Value $content -Response $Response -NoConvert
}

# write data to tcp stream
function Write-ToTcpStream
{
    param (
        [Parameter()]
        [ValidateNotNull()]
        [string]
        $Message,

        [Parameter()]
        $Client
    )

    if ($Client -eq $null)
    {
        $Client = $PodeSession.Tcp.Client
    }

    $stream = $Client.GetStream()
    $encoder = New-Object System.Text.ASCIIEncoding
    $buffer = $encoder.GetBytes("$($Message)`r`n")
    $stream.Write($buffer, 0, $buffer.Length)
    $stream.Flush()
}

function Read-FromTcpStream
{
    param (
        [Parameter()]
        $Client
    )

    if ($Client -eq $null)
    {
        $Client = $PodeSession.Tcp.Client
    }

    $bytes = New-Object byte[] 8192
    $stream = $client.GetStream()
    $encoder = New-Object System.Text.ASCIIEncoding
    $bytesRead = $stream.Read($bytes, 0, 8192)
    $message = $encoder.GetString($bytes, 0, $bytesRead)
    return $message
}