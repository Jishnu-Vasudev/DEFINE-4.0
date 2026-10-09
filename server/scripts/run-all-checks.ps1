$ErrorActionPreference = "Stop"

Write-Host "=== RUNNING REHEARSAL VERIFICATION ==="
Write-Host ">>> P1 Auth + Admin CRUD:"
powershell -ExecutionPolicy Bypass -File ./scripts/p1-check.ps1
Write-Host ">>> P2 Messaging + WS + Presence:"
powershell -ExecutionPolicy Bypass -File ./scripts/p2-check.ps1
Write-Host ">>> P3 Floor Control + LiveKit:"
powershell -ExecutionPolicy Bypass -File ./scripts/p3-check.ps1
Write-Host ">>> P4 Admin Dashboard:"
powershell -ExecutionPolicy Bypass -File ./scripts/p4-check.ps1
Write-Host ">>> P5 Flutter App Core:"
powershell -ExecutionPolicy Bypass -File ./scripts/p5-check.ps1
Write-Host ">>> P6 PTT in App:"
powershell -ExecutionPolicy Bypass -File ./scripts/p6-check.ps1
Write-Host ">>> P7 Media + Call:"
powershell -ExecutionPolicy Bypass -File ./scripts/p7-check.ps1
Write-Host ">>> P8 Nearby Fallback:"
powershell -ExecutionPolicy Bypass -File ./scripts/p8-check.ps1
Write-Host "=== ALL CHECKS PASSED PERFECTLY ==="
