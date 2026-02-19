# dmgagent.ps1 — Contractors Showdown raid damage monitor and logging
# built iteratively with my powershell interest and too much free time,  releasing for the mass to enjoy and to show my potential employers. english/Norwegian variables, English output

# Paths — auto-configured, no editing needed
if ($IsWindows) {
    $outputDir = Join-Path $env:USERPROFILE "Documents\DamageAgent"
} else {
    $outputDir = Join-Path $HOME ".local/share/DamageAgent"
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$loggFil        = "${env:ProgramFiles(x86)}\Steam\steamapps\common\Contractors Showdown\Contractors_Showdown\ExfilZone\ExfilZone.log"
$overlayFil     = Join-Path $outputDir "damage.txt"
$mistenkeligFil = Join-Path $outputDir "suspicious-damage.log"

# === Damage thresholds ===
$maks    = 80    # max realistic single hit — flag as "Possible mod" above this
$modMaks = 150   # upper bound before flagging "Exploit suspected"

# === Variables===
$totalSkade        = 0
$mikroSkadeTotal   = 0
$vaapen            = "Unknown"
$startVaapen       = "Unknown"
$ammo              = "Unknown"
$secondary         = "None"
$vest              = "Unknown"
$hjelm             = "Unknown"
$map               = "Unknown"
$killedBy          = "Unknown"
$raidNr            = 0
$raidStartTid      = ""
$raidSluttTid      = ""
$raidSkadeLogg     = @()
$raidMistLogg      = @()

# === Create output files if missing ===
if (-not (Test-Path $overlayFil))     { New-Item -Path $overlayFil     -ItemType File -Force | Out-Null }
if (-not (Test-Path $mistenkeligFil)) { New-Item -Path $mistenkeligFil -ItemType File -Force | Out-Null }

# Wait for log file to exist (if the game is not running yet) - Just launch the damageagent before or after raiding
while (-not (Test-Path $loggFil)) {
    Write-Host "Waiting for log file..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 3
}

Write-Host "`nDamage agent started - monitoring log file..." -ForegroundColor Cyan
Write-Host "Reports will be saved to: $outputDir" -ForegroundColor DarkGray

Get-Content $loggFil -Wait | ForEach-Object {
    $linje = $_
    if (-not $linje) { return }
    $tid = ($linje -split "\]")[0].TrimStart('[')

    # --- Weapon / gear parsing ---
    if ($linje -match "Raid Primary\s*:\s*(.+)") {
        $startVaapen = $matches[1].Trim()
        $vaapen      = $startVaapen
        return
    }
    elseif ($linje -match "Raid Primary2\s*:\s*(.+)") {
        $secondary = $matches[1].Trim()
        return
    }
    elseif ($linje -match "Primary\s*:\s*(.+)") {
        $vaapen = $matches[1].Trim()
        return
    }
    elseif ($linje -match "Left Hand:\s*(.+)") {
        $ammo = $matches[1].Trim()
        return
    }
    elseif ($linje -match "^.+\] Left Hand:\s*$") {
        # blank Left Hand line — ammo unknown this raid
        return
    }
    elseif ($linje -match "Raid Vest\s*:\s*(.+)") {
        $vest = $matches[1].Trim()
        return
    }
    elseif ($linje -match "Vest\s*:\s*(.+)") {
        $vest = $matches[1].Trim()
        return
    }
    elseif ($linje -match "Raid Helmet\s*:\s*(.+)") {
        $hjelm = $matches[1].Trim()
        return
    }
    elseif ($linje -match "Helmet\s*:\s*(.+)") {
        $hjelm = $matches[1].Trim()
        return
    }

    # --- Killed by ---
    elseif ($linje -match "Killed by\s+(.+)") {
        $killedBy = $matches[1].Trim()
        Write-Host "[$tid] Killed by: $killedBy" -ForegroundColor DarkRed
        return
    }

    # --- Damage lines ---
    elseif ($linje -match "Took\s+(\d+(?:\.\d+)?)\s+damage") {
        $skade = [double]$matches[1]

        if ($skade -lt 2) {
            $mikroSkadeTotal += $skade
            return
        }

        $totalSkade += $skade
        $vurdering  = "Realistic damage"
        $kommentar  = ""

        if ($skade -gt $modMaks) {
            $vurdering = "Exploit suspected"
            $kommentar = "Damage exceeds modified max ($modMaks)"
        }
        elseif ($skade -gt $maks) {
            $vurdering = "Possible mod"
            $kommentar = "Damage exceeds standard max ($maks)"
        }

        $raidSkadeLogg += "$tid - $skade HP ($vurdering) $kommentar"

        if ($vurdering -ne "Realistic damage") {
            $raidMistLogg += "$tid - $skade HP ($vurdering) $kommentar"
            Add-Content -Path $mistenkeligFil -Value "[$tid] $skade HP ($vurdering) $kommentar" -Encoding UTF8
            Write-Host "[$tid] ${vurdering}: $skade HP" -ForegroundColor Red
        } else {
            Write-Host "[$tid] Realistic damage: $skade HP" -ForegroundColor Green
        }

        $overlay = @"
Damage: $skade HP
Total:  $totalSkade HP
Weapon: $vaapen
Ammo:   $ammo
Secondary: $secondary
Evaluation: $vurdering
"@
        Set-Content -Path $overlayFil -Value $overlay -Encoding UTF8
        return
    }

    # --- Raid start ---
    elseif ($linje -match "Raid Start, map:\s*\*([^*]+)\*") {
        $map             = $matches[1].Trim()
        $raidNr++
        $totalSkade      = 0
        $mikroSkadeTotal = 0
        $killedBy        = "Unknown"
        $vaapen          = "Unknown"
        $ammo            = "Unknown"
        $secondary       = "None"
        $raidStartTid    = $tid
        $raidSkadeLogg   = @()
        $raidMistLogg    = @()
        Write-Host "[$tid] RAID #$raidNr started on map: $map" -ForegroundColor Cyan
        Set-Content -Path $overlayFil -Value "New raid started on $map`nTotal damage: 0 HP" -Encoding UTF8
        return
    }

    # --- Raid end ---
    elseif ($linje -match "Raid End") {
        $raidSluttTid = $tid
        $tidFormatert = $raidStartTid -replace "[: ]", "-"
        $rapportFil   = Join-Path $outputDir "#${raidNr}raid-report_$tidFormatert.log"

        $oppsummering = if ($raidMistLogg.Count -gt 0) {
            "Hits exceed weapon profile - check gear or ammo"
        } else {
            "Kit OK - no suspicious hits"
        }

        $rapport = @"
=== RAID #$raidNr ===
Map:           $map
Start time:    $raidStartTid
End time:      $raidSluttTid
Start weapon:  $startVaapen
Final weapon:  $vaapen
Secondary:     $secondary
Vest:          $vest
Helmet:        $hjelm
Killed by:     $killedBy
Total damage:  $totalSkade HP

--- Damage events ---
$($raidSkadeLogg -join "`n")

--- Suspicious hits ---
$($raidMistLogg -join "`n")

Total micro-damage (bleed/passive drain): $([Math]::Round($mikroSkadeTotal, 2)) HP

--- Summary ---
$oppsummering

=== RAID END ===
"@
        Set-Content -Path $rapportFil -Value $rapport -Encoding UTF8
        Write-Host "[$tid] RAID #$raidNr logged to $rapportFil" -ForegroundColor Magenta
        return
    }

}

