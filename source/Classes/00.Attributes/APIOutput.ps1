using namespace System.Net

class APIOutput : System.Attribute
{
    # APIOutput() attribute used to specify type used for an API endpoint as output.
    [HttpStatusCode] $StatusCode = [HttpStatusCode]::OK
    [string] $Description
    [string] $Type
    [string] $ContentType = 'application/json'

}
