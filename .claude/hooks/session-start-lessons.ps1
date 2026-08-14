# SessionStart hook: injects this machine's lessons file into the session context.
# Fails open — any error yields no context rather than a broken session start.
# MUST stay UTF-8 *with BOM*: Windows PowerShell 5.1 reads a BOM-less script as ANSI,
# which mangles every accented string and breaks the parse.

$ErrorActionPreference = 'Stop'

try {
    $repoRoot     = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $machine      = $env:COMPUTERNAME
    $relativePath = ".claude/lessons/workspaces/$machine.md"
    $workspaceFile = Join-Path $repoRoot ".claude\lessons\workspaces\$machine.md"

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("## Cross-session lessons — automatikus betöltés (claude-rules)")
    $lines.Add("")
    $lines.Add("Gép: ``$machine``. A gép-független tanulságok (``.claude/lessons/general.md``) eager importtal már betöltődtek.")
    $lines.Add("")

    if (Test-Path -LiteralPath $workspaceFile) {
        $lines.Add("Ennek a gépnek a tanulságai (``$relativePath``):")
        $lines.Add("")
        $lines.Add((Get-Content -LiteralPath $workspaceFile -Raw -Encoding UTF8).TrimEnd())
    }
    else {
        $lines.Add("Ehhez a géphez még nincs workspace-fájl. Ha gép-specifikus tanulság keletkezik, ide kerül: ``$relativePath``.")
    }

    $lines.Add("")
    $lines.Add("A session végén futó ellenőrzés emlékeztet a rögzítésre; a szabályok a ``lessons-learned`` rule-ban vannak.")

    $payload = @{
        hookSpecificOutput = @{
            hookEventName     = 'SessionStart'
            additionalContext = ($lines -join "`n")
        }
    }

    # Write the bytes directly: a redirected stdout does not honour [Console]::OutputEncoding.
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 5 -Compress))
    $stdout = [System.Console]::OpenStandardOutput()
    $stdout.Write($bytes, 0, $bytes.Length)
    $stdout.Flush()
}
catch {
    # Never block a session start over a lessons lookup.
}

exit 0
