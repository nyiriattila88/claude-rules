# Starts the local Azure DevOps MCP server with the PAT that `az devops login` keeps in Windows Credential Manager.
# The token lives only in the child process environment, never in a config file or on a command line.
# The child inherits this process's stdin/stdout directly, so PowerShell never sits in the MCP stream.

param(
    [Parameter(Mandatory = $true)] [string] $Organization,
    [string[]] $Domains = @('core', 'work-items', 'repositories', 'pipelines', 'wiki', 'search'),
    [string] $Version = '2.10.0'
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class AdoMcpCredential
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct Credential
    {
        public int Flags;
        public int Type;
        public string TargetName;
        public string Comment;
        public long LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredRead(string target, int type, int flags, out IntPtr credential);

    [DllImport("advapi32.dll")]
    private static extern void CredFree(IntPtr credential);

    public static string ReadGeneric(string target)
    {
        IntPtr pointer;
        if (!CredRead(target, 1, 0, out pointer)) { return null; }
        try
        {
            var credential = (Credential)Marshal.PtrToStructure(pointer, typeof(Credential));
            return Marshal.PtrToStringUni(credential.CredentialBlob, credential.CredentialBlobSize / 2);
        }
        finally { CredFree(pointer); }
    }
}
'@

$target = "azdevops-cli:https://dev.azure.com/$Organization"
$pat = [AdoMcpCredential]::ReadGeneric($target)
if (-not $pat) {
    [Console]::Error.WriteLine("azure-devops mcp: no '$target' credential in Windows Credential Manager, run az devops login first.")
    exit 1
}

$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = (Get-Command npx.cmd).Source
$startInfo.Arguments = "-y @azure-devops/mcp@$Version $Organization --authentication pat -d $($Domains -join ' ')"
$startInfo.UseShellExecute = $false
# Any user name works, the server only needs the base64 of "<name>:<pat>".
$startInfo.EnvironmentVariables['PERSONAL_ACCESS_TOKEN'] = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("mcp:$pat"))

$process = [System.Diagnostics.Process]::Start($startInfo)
$process.WaitForExit()
exit $process.ExitCode
