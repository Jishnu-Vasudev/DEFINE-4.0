$ErrorActionPreference = "Stop"

# Helper function to get or insert an admin invite code
$adminCode = node -e "const Database = require('better-sqlite3'); const path = require('path'); const { randomBytes } = require('crypto'); const db = new Database(path.join(process.cwd(), 'data.db')); let row = db.prepare('SELECT code FROM invites WHERE role = \'admin\' AND used = 0 LIMIT 1').get(); if (!row) { const code = randomBytes(4).toString('hex').toUpperCase(); db.prepare('INSERT INTO invites (code, team_id, role, expires_at, used) VALUES (?, NULL, \'admin\', NULL, 0)').run(code); row = { code }; } console.log(row.code);"

if (-not $adminCode) {
  Write-Host "[Step 1: Admin Join] FAIL - No admin code found"
  exit 1
}

# Helper to run curl with json body
function Post-Json([string]$url, [string]$json, [string]$token = "") {
  $headers = @("-H", "Content-Type: application/json")
  if ($token) {
    $headers += @("-H", "Authorization: Bearer $token")
  }
  $res = $json | curl.exe -s -X POST $url @headers -d "@-"
  return ($res | ConvertFrom-Json)
}

function Get-Json([string]$url, [string]$token = "") {
  $headers = @()
  if ($token) {
    $headers += @("-H", "Authorization: Bearer $token")
  }
  $res = curl.exe -s -X GET $url @headers
  return ($res | ConvertFrom-Json)
}

# 1. Admin Join
$joinJson = (@{ code = $adminCode.Trim(); name = "Admin User" } | ConvertTo-Json -Compress)
$resp = Post-Json "http://localhost:3000/auth/join" $joinJson

if ($resp.jwt -and $resp.user.role -eq "admin") {
  Write-Host "[Step 1: Admin Join] PASS"
  $adminToken = $resp.jwt
} else {
  Write-Host "[Step 1: Admin Join] FAIL"
  exit 1
}

# 2. Create Team
$teamJson = (@{ name = "Alpha Team" } | ConvertTo-Json -Compress)
$teamResp = Post-Json "http://localhost:3000/admin/teams" $teamJson $adminToken

if ($teamResp.id -and $teamResp.name -eq "Alpha Team") {
  Write-Host "[Step 2: Create Team] PASS"
  $teamId = $teamResp.id
} else {
  Write-Host "[Step 2: Create Team] FAIL"
  exit 1
}

# 3. Create Channel
$channelJson = (@{ team_id = $teamId; name = "Operations"; kind = "team" } | ConvertTo-Json -Compress)
$channelResp = Post-Json "http://localhost:3000/admin/channels" $channelJson $adminToken

if ($channelResp.id -and $channelResp.name -eq "Operations") {
  Write-Host "[Step 3: Create Channel] PASS"
  $channelId = $channelResp.id
} else {
  Write-Host "[Step 3: Create Channel] FAIL"
  exit 1
}

# 4. Create Member Invite
$inviteJson = (@{ team_id = $teamId; role = "member" } | ConvertTo-Json -Compress)
$inviteResp = Post-Json "http://localhost:3000/admin/invites" $inviteJson $adminToken

if ($inviteResp.code -and $inviteResp.qr_png_base64 -and $inviteResp.payload.code) {
  Write-Host "[Step 4: Create Member Invite] PASS"
  $memberCode = $inviteResp.code
} else {
  Write-Host "[Step 4: Create Member Invite] FAIL"
  exit 1
}

# 5. Member Join
$memberJoinJson = (@{ code = $memberCode; name = "Radio Operator 1" } | ConvertTo-Json -Compress)
$memberJoinResp = Post-Json "http://localhost:3000/auth/join" $memberJoinJson

if ($memberJoinResp.jwt -and $memberJoinResp.user.role -eq "member" -and ($memberJoinResp.channels | Where-Object { $_.id -eq $channelId })) {
  Write-Host "[Step 5: Member Join] PASS"
  $memberToken = $memberJoinResp.jwt
} else {
  Write-Host "[Step 5: Member Join] FAIL"
  exit 1
}

# 6. Call /me/channels as Member
$meChannelsResp = Get-Json "http://localhost:3000/me/channels" $memberToken

if ($meChannelsResp | Where-Object { $_.id -eq $channelId }) {
  Write-Host "[Step 6: Member /me/channels] PASS"
} else {
  Write-Host "[Step 6: Member /me/channels] FAIL"
  exit 1
}

Write-Host "All P1 checks passed successfully!"
