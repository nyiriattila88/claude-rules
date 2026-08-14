# Stop hook: asks for a lessons sweep once per session, then never again for that session.
# A per-session marker file prevents the block from looping; small sessions are skipped.
# Fails open — any error yields no block rather than a stuck session.
# MUST stay UTF-8 *with BOM*: Windows PowerShell 5.1 reads a BOM-less script as ANSI,
# which mangles every accented string and breaks the parse.

$ErrorActionPreference = 'Stop'

$MinTranscriptBytes = 30000   # below this the session is too small to have produced a lesson

try {
    # $input is a reserved automatic variable in PowerShell — never assign to it.
    $raw       = [Console]::In.ReadToEnd()
    $hookInput = if ([string]::IsNullOrWhiteSpace($raw)) { $null } else { $raw | ConvertFrom-Json }

    $sessionId      = if ($hookInput) { $hookInput.session_id } else { $null }
    $transcriptPath = if ($hookInput) { $hookInput.transcript_path } else { $null }

    if (-not $sessionId) { exit 0 }

    # Trivial sessions produce no lessons; don't spend a turn asking.
    if ($transcriptPath -and (Test-Path -LiteralPath $transcriptPath)) {
        if ((Get-Item -LiteralPath $transcriptPath).Length -lt $MinTranscriptBytes) { exit 0 }
    }

    $markerDir  = Join-Path $env:TEMP 'claude-lessons-sweep'
    $markerFile = Join-Path $markerDir "$sessionId.done"

    if (Test-Path -LiteralPath $markerFile) { exit 0 }

    if (-not (Test-Path -LiteralPath $markerDir)) {
        New-Item -ItemType Directory -Path $markerDir -Force | Out-Null
    }
    New-Item -ItemType File -Path $markerFile -Force | Out-Null

    $machine = $env:COMPUTERNAME
    $reason  = @"
Zárás előtti tanulság-ellenőrzés (sessiononként egyszer fut, a claude-rules lessons-learned rule alapján).

Volt ebben a sessionben olyan tanulság, amit egy későbbi session újratanulna? Ha igen, rögzítsd EGY dátumozott sorral:
- projekt- és gépfüggetlen tanulság: claude-rules/.claude/lessons/general.md
- csak erre a gépre ($machine) igaz tény: claude-rules/.claude/lessons/workspaces/$machine.md

Ha nem volt ilyen, NE írj semmit — csak zárd le egy rövid mondattal. A commit/push továbbra is engedélyköteles.
"@

    # Write the bytes directly: a redirected stdout does not honour [Console]::OutputEncoding.
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes((@{ decision = 'block'; reason = $reason } | ConvertTo-Json -Depth 3 -Compress))
    $stdout = [System.Console]::OpenStandardOutput()
    $stdout.Write($bytes, 0, $bytes.Length)
    $stdout.Flush()
}
catch {
    # Never trap a session over a lessons reminder.
}

exit 0
