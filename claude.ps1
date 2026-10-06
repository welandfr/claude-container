# Launcher for the containerized Claude Code (Windows / PowerShell).
#
# Picks a container name derived from the current directory and a free block of
# host ports, so several instances can run side by side. All arguments are
# passed through to `claude` inside the container.
#
# Env overrides:
#   CLAUDE_IMAGE        image to run                      (default: claude-code:latest)
#   CLAUDE_PORTS        container ports to publish        (default: "3000 8000")
#   CLAUDE_PORT_OFFSET  use this offset instead of searching
#   CLAUDE_NO_PORTS=1   publish no ports at all
#   CLAUDE_NAME         use this container name
#   CLAUDE_HOME_VOLUME  volume holding ~/.claude          (default: claude-home)

$ErrorActionPreference = 'Stop'

$image      = if ($env:CLAUDE_IMAGE)       { $env:CLAUDE_IMAGE }       else { 'claude-code:latest' }
$homeVolume = if ($env:CLAUDE_HOME_VOLUME) { $env:CLAUDE_HOME_VOLUME } else { 'claude-home' }
$maxOffset  = if ($env:CLAUDE_MAX_OFFSET)  { [int]$env:CLAUDE_MAX_OFFSET } else { 20 }
$portSpec   = if ($env:CLAUDE_PORTS)       { $env:CLAUDE_PORTS }       else { '3000 8000' }

$ports = @($portSpec -split '\s+' | Where-Object { $_ } | ForEach-Object { [int]$_ })
if ($env:CLAUDE_NO_PORTS -eq '1') { $ports = @() }

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error 'claude: docker not found on PATH'
    exit 1
}

# --- container name ----------------------------------------------------------
# claude-<current dir>, with -2, -3, ... appended if that name is taken. Named
# (rather than left anonymous) so `docker exec` can target a specific instance.
$existing = @(docker ps -a --format '{{.Names}}')

$name = $env:CLAUDE_NAME
if (-not $name) {
    $slug = (Split-Path -Leaf (Get-Location).Path).ToLower()
    $slug = $slug -replace '[^a-z0-9_.-]', '-' -replace '^[^a-z0-9]+', '' -replace '-{2,}', '-'
    if (-not $slug) { $slug = 'workspace' }
    $base = "claude-$slug"
    $name = $base
    $i = 2
    while ($existing -contains $name) {
        $name = "$base-$i"
        $i++
    }
}

# --- host port offset --------------------------------------------------------
# Published docker ports hold a listening socket on the host, so enumerating
# listeners is enough to spot a block already claimed by another instance.
$busy = $null
if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
    try {
        $busy = @(Get-NetTCPConnection -State Listen -ErrorAction Stop |
                  Select-Object -ExpandProperty LocalPort -Unique)
    } catch { $busy = $null }
}

function Test-PortBusy([int]$port) {
    if ($null -ne $busy) { return $busy -contains $port }
    # No Get-NetTCPConnection: fall back to a connect test against loopback.
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        if ($client.ConnectAsync('127.0.0.1', $port).Wait(200)) { return $true }
        return $false
    } catch { return $false } finally { $client.Dispose() }
}

$offset = $null
if ($ports.Count -gt 0) {
    if ($env:CLAUDE_PORT_OFFSET) {
        $offset = [int]$env:CLAUDE_PORT_OFFSET
    } else {
        foreach ($o in 0..$maxOffset) {
            $free = $true
            foreach ($p in $ports) {
                if (Test-PortBusy ($p + $o)) { $free = $false; break }
            }
            if ($free) { $offset = $o; break }
        }
        if ($null -eq $offset) {
            Write-Warning "claude: no free port block in +0..+$maxOffset; starting without published ports"
            $ports = @()
        }
    }
}

# --- run ---------------------------------------------------------------------
$dockerArgs = @(
    'run', '--rm', '-it',
    '--name', $name,
    '-v', "$((Get-Location).Path):/workspace",
    '-v', "${homeVolume}:/home/node",
    '-w', '/workspace'
)

$mapping = ''
foreach ($p in $ports) {
    $dockerArgs += @('-p', "127.0.0.1:$($p + $offset):$p")
    $mapping += " $($p + $offset)->$p"
}

$dockerArgs += $image
if ($args.Count -gt 0) { $dockerArgs += $args }

if ($mapping) {
    Write-Host "claude: $name  ports:$mapping"
} else {
    Write-Host "claude: $name  (no published ports)"
}

# Two launches racing for the same offset can still collide on `docker run`;
# re-running picks the next free block.
& docker @dockerArgs
exit $LASTEXITCODE
