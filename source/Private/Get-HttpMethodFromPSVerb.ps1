function Get-HttpMethodFromPSVerb
{
    <#
        .SYNOPSIS
        Converts a PowerShell verb to an HTTP method.

        .DESCRIPTION
        This function takes a PowerShell verb and returns the corresponding HTTP method.

        .PARAMETER Verb
        The PowerShell verb to convert.

        .OUTPUTS
        Returns the HTTP method as a string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Verb
    )

    switch -regex ($Verb)
    {
        # The POST method is used to submit an entity to the specified resource, often causing a change in state or side effects on the server.
        # The PUT method replaces all current representations of the target resource with the request payload.
        # The DELETE method deletes the specified resource.
        # The PATCH method is used to apply partial modifications to a resource.
        # The HEAD method asks for a response identical to that of a GET request, but without the response body.
        # The GET method requests a representation of the specified resource.
        # The OPTIONS method is used to describe the communication options for the target resource.
        # The CONNECT method establishes a tunnel to the server identified by the target resource.
        # The TRACE method performs a message loop-back test along the path to the target resource.

        'Add'           { 'POST' }
        'Clear'         { 'DELETE'}
        'Close'         { 'HEAD'}
        'Copy'          { 'PUT'}
        'Enter'         { 'PATCH' }
        'Exit'          { 'GET'}
        'Find'          { 'GET'}
        'Format'        { 'GET'}
        'Get'           { 'GET'}
        'Hide'          { 'PATCH' }
        'Join'          { 'PUT'}
        'Lock'          { 'POST' }
        'Move'          { 'PUT' }
        'New'           { 'POST' }
        'Open'          { 'GET' }
        'Optimize'      { 'PUT'}
        'Push'          { 'POST' }
        'Pop'           { 'DELETE' }
        'Redo'          { 'PATCH' }
        'Remove'        { 'DELETE' }
        'Rename'        { 'PUT' }
        'Reset'         { 'PATCH' }
        'Resize'        { 'PATCH' }
        'Search'        { 'GET' }
        'Select'        { 'GET' }
        'Set'           { 'PUT' }
        'Show'          { 'GET' }
        'Skip'          { 'PATCH' }
        'Split'         { 'PATCH' }
        'Step'          { 'PATCH' }
        'Switch'        { 'GET' }
        'Undo'          { 'PATCH' }
        'Unlock'        { 'DELETE' }
        'Watch'         { 'GET' }
        'Connect'       { 'POST' }
        'Disconnect'    { 'DELETE' }
        'Read'          { 'GET' }
        'Receive'       { 'POST' }
        'Send'          { 'POST' }
        'Write'         { 'PUT' }
        'Backup'        { 'PUT' }
        'Checkpoint'    { 'PUT' }
        'Compare'       { 'GET' }
        'Compress'      { 'POST' }
        'Convert'       { 'POST' }
        'ConvertFrom'   { 'GET' }
        'ConvertTo'     { 'POST' }
        'Dismount'      { 'DELETE' }
        'Edit'          { 'PATCH' }
        'Expand'        { 'GET' }
        'Export'        { 'POST' }
        'Group'         { 'GET' }
        'Import'        { 'POST' }
        'Initialize'    { 'PUT' }
        'Limit'         { 'PATCH' }
        'Merge'         { 'PUT' }
        'Mount'         { 'POST' }
        'Out'           { 'POST' }
        'Publish'       { 'POST' }
        'Restore'       { 'PUT' }
        'Save'          { 'PUT' }
        'Sync'          { 'POST' }
        'Unpublish'     { 'DELETE' }
        'Update'        { 'PUT' }
        'Debug'         { 'GET' }
        'Measure'       { 'GET' }
        'Ping'          { 'GET' }
        'Repair'        { 'PATCH' }
        'Resolve'       { 'GET' }
        'Test'          { 'GET' }
        'Trace'         { 'TRACE' }
        'Approve'       { 'POST' }
        'Assert'        { 'PATCH' }
        'Build'         { 'POST' }
        'Complete'      { 'PUT' }
        'Confirm'       { 'POST' }
        'Deny'          { 'DELETE' }
        'Deploy'        { 'POST' }
        'Disable'       { 'PATCH' }
        'Enable'        { 'PATCH' }
        'Install'       { 'POST' }
        'Invoke'        { 'POST' }
        'Register'      { 'POST' }
        'Request'       { 'POST' }
        'Restart'       { 'PATCH' }
        'Resume'        { 'PATCH' }
        'Start'         { 'POST' }
        'Stop'          { 'DELETE' }
        'Submit'        { 'POST' }
        'Suspend'       { 'PATCH' }
        'Uninstall'     { 'DELETE' }
        'Unregister'    { 'DELETE' }
        'Wait'          { 'GET' }
        'Use'           { 'GET' }
        'Block'         { 'POST' }
        'Grant'         { 'POST' }
        'Protect'       { 'POST' }
        'Revoke'        { 'DELETE' }
        'Unblock'       { 'PUT' }
        'Unprotect'     { 'PUT' }
        default         { throw "Unsupported verb: $Verb" }
    }
}
