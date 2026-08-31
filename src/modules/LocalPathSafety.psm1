Set-StrictMode -Version Latest

function Test-IsLocalFixedPath {
    param([AllowNull()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if ($Path.StartsWith('\\') -or $Path.StartsWith('//')) { return $false }
    try { if (-not [IO.Path]::IsPathRooted($Path)) { return $false } } catch { return $false }

    if ([IO.Path]::DirectorySeparatorChar -eq '/') {
        return $Path.StartsWith('/') -and -not $Path.StartsWith('//')
    }

    try {
        $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
        if (-not $root -or $root.StartsWith('\\')) { return $false }
        $driveName = $root.Substring(0, 1)
        $psDrive = Get-PSDrive -Name $driveName -PSProvider FileSystem -ErrorAction SilentlyContinue
        if ($psDrive -and $psDrive.DisplayRoot -and ([string]$psDrive.DisplayRoot).StartsWith('\\')) { return $false }
        $driveInfo = [IO.DriveInfo]::GetDrives() | Where-Object { $_.Name.Equals($root, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if ($null -eq $driveInfo -or $driveInfo.DriveType -ne [IO.DriveType]::Fixed) { return $false }
        $probe = $Path
        while ($probe -and -not (Test-Path -LiteralPath $probe)) { $probe = Split-Path -Parent $probe }
        while ($probe -and $probe.Length -ge $root.Length) {
            $item = Get-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
            if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
            if ($probe.Equals($root, [StringComparison]::OrdinalIgnoreCase)) { break }
            $next = Split-Path -Parent $probe
            if ($next -eq $probe) { break }
            $probe = $next
        }
        return $true
    } catch { return $false }
}

function Assert-LocalFixedPath {
    param([string]$Path, [string]$Purpose = 'operação')
    if (-not (Test-IsLocalFixedPath $Path)) { throw "Caminho recusado para ${Purpose}: somente disco local fixo é permitido." }
    return $true
}

Export-ModuleMember -Function Test-IsLocalFixedPath,Assert-LocalFixedPath
