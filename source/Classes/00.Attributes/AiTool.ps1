class AiTool : System.Attribute
{
    # AiTool() attribute used to expose a function as a PowerShell Universal AI tool.
    # Mirrors the APIEndpoint() attribute pattern: decorate a public function with this
    # attribute, then call Import-PSUAiTool to discover and register it in PSU.
    [bool]$IsAiTool = $true # Marker indicating this is an AI tool attribute
    [string]$Name # Name of the AI tool. Defaults to the function name when not set.
    [string]$Description # Description of the AI tool. Defaults to the function's comment-based help synopsis.
    [bool]$Authenticated = $false # Whether the tool requires an authenticated user
    [string[]]$Role # Role(s) required to access/invoke the tool
    [bool]$Mcp = $true # Whether the tool is exposed through Model Context Protocol (MCP)
    [string]$Environment # PSU environment the backing script should run in

    AiTool ()
    {
        # Default constructor for the attribute
    }
}
