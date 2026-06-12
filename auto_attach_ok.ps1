<#
  auto_attach_ok.ps1
  Watches for Opal Kelly XEM7310 boards (USB ID 151f:0130) and automatically
  binds + attaches each new one to WSL. Runs forever until you press Ctrl-C.

  USAGE (must be an ADMIN PowerShell -- 'usbipd bind' requires admin):
    powershell -ExecutionPolicy Bypass -File .\auto_attach_ok.ps1

  Optional: set $RunTest = $true to also auto-run your WSL test on each board.
#>

# ---- settings ----------------------------------------------------------
$TARGET     = '151f:0130'                                   # Opal Kelly XEM7310
$PollSeconds = 2
$RunTest    = $false                                        # set $true for hands-free testing
$TestCmd    = 'python3 ~/fp_wire_test.py ~/fp_wire_test.bit'  # WSL command to run per board
# ------------------------------------------------------------------------

Write-Host "Watching for Opal Kelly boards ($TARGET). Ctrl-C to stop." -ForegroundColor Cyan
if ($RunTest) { Write-Host "Auto-test ENABLED: '$TestCmd' will run on each new board." -ForegroundColor Cyan }

# remember which bus IDs we've already attached so we don't repeat
$handled = @{}

while ($true) {
    $lines = usbipd list
    $inConnected = $true

    foreach ($line in $lines) {
        if ($line -match '^Persisted:') { $inConnected = $false; continue }
        if (-not $inConnected)          { continue }
        if ($line -notmatch $TARGET)    { continue }

        # parse "BUSID  VID:PID  Description....   STATE"
        if ($line -match '^(?<busid>\d+-\d+)\s+\S+\s+.*?\s{2,}(?<state>Not shared|Shared(?: \(forced\))?|Attached(?: \(forced\))?)\s*$') {
            $busid = $Matches['busid']
            $state = $Matches['state']

            if ($state -like 'Attached*') {
                # already attached; make sure it's marked handled
                $handled[$busid] = $true
                continue
            }

            Write-Host ("[{0}] new board (state: {1}) -> binding + attaching..." -f $busid, $state) -ForegroundColor Yellow
            usbipd bind   --busid $busid       2>&1 | Out-Null
            usbipd attach --wsl --busid $busid 2>&1 | Out-Null
            Start-Sleep -Milliseconds 800       # let WSL enumerate the device
            Write-Host ("[{0}] attached to WSL." -f $busid) -ForegroundColor Green

            if ($RunTest) {
                Write-Host ("[{0}] running test in WSL..." -f $busid) -ForegroundColor Yellow
                wsl -e bash -lc $TestCmd
                Write-Host ("[{0}] test done." -f $busid) -ForegroundColor Green
            }
            $handled[$busid] = $true
        }
    }

    # forget bus IDs that are no longer present (so a replug re-triggers)
    $present = ($lines | Select-String -Pattern '^\d+-\d+').Matches.Value
    foreach ($b in @($handled.Keys)) {
        if ($present -notcontains $b) { $handled.Remove($b) }
    }

    Start-Sleep -Seconds $PollSeconds
}