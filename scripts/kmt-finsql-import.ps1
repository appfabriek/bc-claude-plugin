# KMT finsql import/compile. One finsql at a time. Never pass one comma-string (opens GUI).
# Use -Id 50062 instead of -Filter "Type=Codeunit;ID=50062" (semicolon breaks callers).
param(
  [string]$ObjectFile = '',
  [int]$Id = 0,
  [string]$Database = 'kmt-test',
  [string]$Server = '.',
  [string]$Filter = '',
  [switch]$CompileOnly,
  [int]$TimeoutSec = 90
)
$ErrorActionPreference = 'Stop'
function Say([string]$Msg) { Write-Output $Msg; [Console]::Out.Flush() }
function Resolve-ShortPath([string]$Path) {
  if (-not (Test-Path $Path)) { return $Path }
  if ($Path -notmatch '\s') { return $Path }
  $short = cmd /c "for %I in (`"$Path`") do @echo %~sI"
  if ($short) { return ($short | Select-Object -First 1).ToString().Trim() }
  return $Path
}
function Get-ObjectHeader([string]$Path) {
  $line = Get-Content $Path -TotalCount 1
  if ($line -match '^OBJECT\s+(\w+)\s+(\d+)') { return @{ Type = $Matches[1]; Id = [int]$Matches[2] } }
  throw "No OBJECT header in $Path"
}
function Enter-FinsqlLock([string]$LockPath) {
  $deadline = (Get-Date).AddSeconds(30)
  while ((Get-Date) -lt $deadline) {
    if (-not (Test-Path $LockPath)) {
      Set-Content -Path $LockPath -Value $PID -Encoding ascii
      return
    }
    $owner = 0
    [void][int]::TryParse((Get-Content $LockPath -TotalCount 1), [ref]$owner)
    if ($owner -gt 0 -and -not (Get-Process -Id $owner -ErrorAction SilentlyContinue)) {
      Set-Content -Path $LockPath -Value $PID -Encoding ascii
      return
    }
    Start-Sleep -Seconds 2
  }
  throw "Another finsql job holds $LockPath"
}
function Exit-FinsqlLock([string]$LockPath) {
  if (Test-Path $LockPath) { Remove-Item $LockPath -Force -ErrorAction SilentlyContinue }
}
function Invoke-FinSql([string]$Log, [string[]]$ArgList) {
  $existing = @(Get-Process finsql -ErrorAction SilentlyContinue)
  if ($existing.Count -gt 0) { throw "finsql already running pid=$($existing.Id -join ',')" }
  New-Item $Log -ItemType File -Force | Out-Null
  $p = Start-Process -FilePath $FinSql -ArgumentList $ArgList -PassThru -WindowStyle Hidden
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while (-not $p.HasExited) {
    if ((Get-Date) -gt $deadline) {
      $size = (Get-Item $Log).Length
      Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
      throw "finsql timeout ${TimeoutSec}s pid=$($p.Id) logBytes=$size log=$Log"
    }
    Start-Sleep -Seconds 1
  }
  $code = $p.ExitCode
  if ($code -ne 0) { $detail = (Get-Content $Log -ErrorAction SilentlyContinue | Select-Object -First 8) -join " | "; throw "finsql exit $code log=$Log $detail" }
}

$FinSql = 'C:\Program Files (x86)\Microsoft Dynamics 365 Business Central\140\RoleTailored Client\finsql.exe'
$work = 'C:\NAVServices\CRT'
$lock = Join-Path $work 'kmt-finsql.lock'
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
if (-not (Test-Path $FinSql)) { throw "Missing $FinSql" }

Enter-FinsqlLock $lock
try {
  if (-not $CompileOnly) {
    if (-not $ObjectFile) { throw 'ObjectFile is required unless -CompileOnly' }
    if (-not (Test-Path $ObjectFile)) { throw "Missing $ObjectFile" }
    $header = Get-ObjectHeader $ObjectFile
    if (-not $Id) { $Id = $header.Id }
    $dest = Join-Path $work ("import-$stamp.txt")
    Copy-Item $ObjectFile $dest -Force
    $log = Join-Path $work ("import-$stamp.finsql.log")
    $argsImport = @(
      'command=importobjects,',
      "file=$(Resolve-ShortPath $dest),",
      'importaction=overwrite,',
      'synchronizeschemachanges=no,',
      "servername=$Server,",
      "database=$Database,",
      'ntauthentication=1,',
      "logfile=$(Resolve-ShortPath $log)"
    )
    Say "IMPORT $($argsImport -join ' ')"
    Invoke-FinSql $log $argsImport
    Say "IMPORT_OK id=$Id"
  }

  if (-not $Filter -and $Id) { $Filter = "Type=Codeunit;ID=$Id" }
  if (-not $Filter) { throw 'No compile filter. Pass -Id or -Filter.' }

  $clog = Join-Path $work ("compile-$stamp.finsql.log")
  $argsCompile = @(
    'command=compileobjects,',
    "filter=$Filter,",
    "servername=$Server,",
    "database=$Database,",
    'ntauthentication=1,',
    "logfile=$(Resolve-ShortPath $clog)"
  )
  Say "COMPILE $($argsCompile -join ' ')"
  Invoke-FinSql $clog $argsCompile
  Say "COMPILE_OK filter=$Filter"
}
finally {
  Exit-FinsqlLock $lock
}
