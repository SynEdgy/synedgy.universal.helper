class APIEndpoint : System.Attribute
{
    [bool]$IsEndpoint = $true # Indicates that this is an API endpoint attribute
    [bool]$AutoSerialization = $true # Whether the endpoint should automatically serialize the output to JSON
    [string]$Name
    [string]$ApiPrefix = 'api' # Prefix for the API endpoint URL
    [string]$Version = 'v1' # Version of the API endpoint
    [string]$Path # aka the URL path of the endpoint
    [string]$Description # Description of the endpoint
    [string]$Documentation # Documentation name the endpoint should be attached to
    [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD')]
    [string[]]$Method # HTTP method (GET, POST, PUT, DELETE, etc.)
    [bool]$Authentication = $false # Whether the endpoint requires authentication
    [string[]]$Role # Role required to access the endpoint
    [string]$Tag # Tag for categorizing the endpoint
    [int]$Timeout# Timeout for the endpoint in seconds
    [string]$Environment # Environment where the endpoint is executed (e.g. the PowerShell Universal environment)
    [string]$ContentType = 'application/json; charset=utf-8' # Content type of the response
    [ValidateSet('Information', 'Warning', 'Error', 'Verbose', 'Debug')] # TODO: Create the scriptlbock to add the -$loglevelAction Continue
    [string[]]$LogLevel = @('Information') # Log level for the endpoint
    [scriptblock]$Parameters # Override of parameters for the endpoint to splat to the command

    APIEndpoint ()
    {
        # Default constructor for the attribute
    }
}
