
$target = $PSScriptRoot
Write-Host "Checking for target folder in PATH: $target" -ForegroundColor Cyan
$rawPath = [Environment]::GetEnvironmentVariable("Path", "User")
$oldPath = $rawPath -split ';'
if ($oldPath -contains $target) {
	Write-Host "Target folder found in PATH. Removing..." -ForegroundColor Cyan
	$newPath = ($oldPath | Where-Object { $_ -ne $target }) -join ';'
	[Environment]::SetEnvironmentVariable("Path", $newPath, "User")
	Write-Host "Target folder removed from PATH." -ForegroundColor Green
} else {
	Write-Host "Target folder not found in PATH. No change needed." -ForegroundColor Yellow
}
