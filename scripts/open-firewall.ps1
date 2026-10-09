# Run ONCE in an ADMINISTRATOR PowerShell on the laptop that hosts the server.
# Chat works over TCP 3000, but voice needs TCP 7880/7881 and UDP 50000-50100.
# Windows silently blocks these when the popup was dismissed or the Wi-Fi/hotspot is "Public".

$rules = @(
  @{ Name = 'BunnyHop TCP'; Proto = 'TCP'; Ports = '3000,7880,7881' },
  @{ Name = 'BunnyHop UDP media'; Proto = 'UDP'; Ports = '50000-50100' }
)
foreach ($r in $rules) {
  Remove-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName $r.Name -Direction Inbound -Protocol $r.Proto -LocalPort $r.Ports -Action Allow -Profile Any | Out-Null
  Write-Host "allowed $($r.Proto) $($r.Ports)"
}

# Old "Block" rules Windows made when the popup for these programs was cancelled
Get-NetFirewallRule -Direction Inbound -Action Block -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName -match 'livekit|ptt-server' } |
  ForEach-Object { Write-Host "removing block rule: $($_.DisplayName)"; Remove-NetFirewallRule -Name $_.Name }

# Hotspot / unknown Wi-Fi defaults to Public, which is the strictest profile
Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq 'Public' } | ForEach-Object {
  Write-Host "setting '$($_.Name)' to Private"
  Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private
}
Write-Host "done. Restart livekit-server and ptt-server."
