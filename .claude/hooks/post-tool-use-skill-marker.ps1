# PostToolUse hook on the Skill tool: shows every skill load to the user as a harness message.
# Unlike the reply header line, this does not depend on the model remembering to write it.
# Fails open, any error yields no output rather than a broken tool call.
# MUST stay UTF-8 *with BOM*: Windows PowerShell 5.1 reads a BOM-less script as ANSI.

$ErrorActionPreference = 'Stop'

try {
    $raw       = [Console]::In.ReadToEnd()
    $hookInput = if ([string]::IsNullOrWhiteSpace($raw)) { $null } else { $raw | ConvertFrom-Json }
    $skill     = if ($hookInput) { ([string]$hookInput.tool_input.skill).Trim() } else { '' }
    if (-not $skill) { exit 0 }

    # Only a custom skill has its SKILL.md under a .claude/skills folder.
    $custom = ($skill -notmatch ':') -and (
        (Test-Path -LiteralPath (Join-Path $env:USERPROFILE ".claude\skills\$skill\SKILL.md")) -or
        ($hookInput.cwd -and (Test-Path -LiteralPath (Join-Path $hookInput.cwd ".claude\skills\$skill\SKILL.md"))))
    $kind = if ($custom) { 'saját' } else { 'telepített' }

    # Write the bytes directly: a redirected stdout does not honour [Console]::OutputEncoding.
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes((@{ systemMessage = "Skill betöltve: $skill ($kind)" } | ConvertTo-Json -Compress))
    $stdout = [System.Console]::OpenStandardOutput()
    $stdout.Write($bytes, 0, $bytes.Length)
    $stdout.Flush()
}
catch {
    # Never break a tool call over a marker.
}

exit 0
