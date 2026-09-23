# PreToolUse gate: denies a domain's tool calls until the session has loaded its custom and official skills.
# The loads are read from the session transcript, so no other hook has to record them.
# Fails open, any error lets the call through rather than trapping the session.
# MUST stay UTF-8 *with BOM*: Windows PowerShell 5.1 reads a BOM-less script as ANSI.

$ErrorActionPreference = 'Stop'

# The settings `if` filters decide which calls reach this script, Tools and Command pick the domain.
$Domains = @(
    @{
        Name     = 'AWS'
        Tools    = '^mcp__plugin_aws-core_aws-mcp__'
        Command  = '(?m)(^|[;&|({=])\s*(\w+=\S*\s+)*aws(\.exe)?(\s|$)'
        Custom   = 'aws'
        Official = 'aws-core:'
        Examples = 'aws-core:aws-iam, aws-core:aws-containers, aws-core:aws-observability'
    }
)

# A Skill tool call, or a skill the user typed as /name. Both are anchored on raw JSON quotes,
# which text quoted inside a message or a tool call cannot produce.
$LoadPattern = '"name":"Skill","input":\{"skill":"(?<n>[^"]+)"|"content":"(?:<command-message>[^<]*</command-message>(?:\\n|\s)*)?<command-name>/(?<n>[^<]+)</command-name>'

try {
    $raw       = [Console]::In.ReadToEnd()
    $hookInput = if ([string]::IsNullOrWhiteSpace($raw)) { $null } else { $raw | ConvertFrom-Json }
    if (-not $hookInput -or -not $hookInput.transcript_path) { exit 0 }

    $toolName = [string]$hookInput.tool_name
    $command  = [string]$hookInput.tool_input.command
    $domain   = $Domains | Where-Object {
        ($toolName -match $_.Tools) -or (($toolName -in 'Bash', 'PowerShell') -and ($command -match $_.Command))
    } | Select-Object -First 1
    if (-not $domain) { exit 0 }
    if (-not (Test-Path -LiteralPath $hookInput.transcript_path)) { exit 0 }

    $loaded = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    # ReadWrite sharing: Claude Code keeps appending to the transcript while this reads it.
    $stream = New-Object System.IO.FileStream($hookInput.transcript_path, 'Open', 'Read', 'ReadWrite')
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            if (-not $line.Contains('"Skill"') -and -not $line.Contains('<command-name>')) { continue }
            foreach ($m in [regex]::Matches($line, $LoadPattern)) { [void]$loaded.Add($m.Groups['n'].Value) }
        }
    }
    finally {
        $reader.Dispose()
    }

    $missing = @()
    if (-not $loaded.Contains($domain.Custom)) {
        $missing += ('- `{0}` (saját)' -f $domain.Custom)
    }
    if (-not ($loaded | Where-Object { $_.StartsWith($domain.Official, [StringComparison]::OrdinalIgnoreCase) })) {
        $missing += ('- a feladathoz illő hivatalos `{0}` skill, pl. {1}' -f $domain.Official, $domain.Examples)
    }
    if ($missing.Count -eq 0) { exit 0 }

    $reason = "{0}-hívás előtt ezeket kell betölteni a Skill toollal:`n{1}`nUtána futtasd újra ugyanezt a hívást." -f $domain.Name, ($missing -join "`n")
    $output = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'deny'
            permissionDecisionReason = $reason
        }
    }

    # Write the bytes directly: a redirected stdout does not honour [Console]::OutputEncoding.
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes(($output | ConvertTo-Json -Depth 3 -Compress))
    $stdout = [System.Console]::OpenStandardOutput()
    $stdout.Write($bytes, 0, $bytes.Length)
    $stdout.Flush()
}
catch {
    # A broken gate must not trap the session, the call goes through.
}

exit 0
