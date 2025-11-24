using namespace System.Net

class APIInput : System.Attribute
{
    # APIInput() attribute used to specify type used for an API endpoint as input.
    [HttpStatusCode] $StatusCode = [HttpStatusCode]::OK
    [bool] $Required = $false
    [string] $Description
    [string] $Type
    [string] $ContentType = 'application/json'
}
