# Load the SQL Server module
Import-Module SQLPS -DisableNameChecking

# Define the SQL Server instance
$serverInstance = "SQL-1"

# Create a new SMO Server object
$server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverInstance

# Add NT AUTHORITY\SYSTEM to the sysadmin role
$login = $server.Logins["NT AUTHORITY\SYSTEM"]
if ($login -eq $null) {
    Write-Host "Login 'NT AUTHORITY\SYSTEM' does not exist."
} else {
    $login.AddToRole("sysadmin")
    Write-Host "Login 'NT AUTHORITY\SYSTEM' has been added to the sysadmin role."
}