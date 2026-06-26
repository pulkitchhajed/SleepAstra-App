param(
  [Parameter(Mandatory = $false)]
  [string]$SourceDir = "C:\Users\pulki\OneDrive\Desktop\snore clinic doc",

  [Parameter(Mandatory = $false)]
  [string]$OutFile = "tools\blogs_from_docx.json",

  [Parameter(Mandatory = $false)]
  [string]$Author = "SnoreClinics Team",

  [Parameter(Mandatory = $false)]
  [string]$Category = "Sleep Health",

  [Parameter(Mandatory = $false)]
  [string]$CoverImageUrl = "",

  [Parameter(Mandatory = $false)]
  [string]$UploadedBy = "docx-import"
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

function ConvertTo-Slug([string]$Text) {
  $slug = $Text.ToLowerInvariant()
  $slug = $slug -replace "[^\p{L}\p{Nd}]+", "-"
  $slug = $slug.Trim("-")
  if ([string]::IsNullOrWhiteSpace($slug)) {
    return [guid]::NewGuid().ToString("N")
  }
  return $slug
}

function Get-CleanTitle([string]$FileName) {
  $title = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
  return ($title -replace "[-\s]+$", "").Trim()
}

function Get-DocxParagraphs([string]$Path) {
  $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $entry = $zip.GetEntry("word/document.xml")
    if ($null -eq $entry) {
      throw "word/document.xml was not found"
    }

    $stream = $entry.Open()
    try {
      $reader = New-Object System.IO.StreamReader($stream)
      $xmlText = $reader.ReadToEnd()
    } finally {
      if ($reader) { $reader.Dispose() }
      $stream.Dispose()
    }

    [xml]$xml = $xmlText
    $namespace = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $namespace.AddNamespace("w", "http://schemas.openxmlformats.org/wordprocessingml/2006/main")

    $paragraphs = New-Object System.Collections.Generic.List[string]
    foreach ($paragraph in $xml.SelectNodes("//w:body/w:p", $namespace)) {
      $parts = New-Object System.Collections.Generic.List[string]
      foreach ($textNode in $paragraph.SelectNodes(".//w:t", $namespace)) {
        $parts.Add($textNode.InnerText)
      }

      $text = (($parts -join "") -replace "\s+", " ").Trim()
      if (-not [string]::IsNullOrWhiteSpace($text)) {
        $paragraphs.Add($text)
      }
    }

    return @($paragraphs)
  } finally {
    $zip.Dispose()
  }
}

function Get-Summary([string[]]$Paragraphs, [string]$Title) {
  $candidate = $Paragraphs |
    Where-Object { $_.Trim() -and $_.Trim().ToLowerInvariant() -ne $Title.ToLowerInvariant() } |
    Select-Object -First 1

  if ([string]::IsNullOrWhiteSpace($candidate)) {
    return "Learn practical sleep-health insights from SnoreClinics."
  }

  if ($candidate.Length -gt 220) {
    return $candidate.Substring(0, 217).TrimEnd() + "..."
  }
  return $candidate
}

function Get-ReadTime([string]$Content) {
  $wordCount = ([regex]::Matches($Content, "\S+")).Count
  return [Math]::Max(1, [Math]::Ceiling($wordCount / 220))
}

if (-not (Test-Path -LiteralPath $SourceDir)) {
  throw "Source directory not found: $SourceDir"
}

$blogs = New-Object System.Collections.Generic.List[object]
$files = Get-ChildItem -LiteralPath $SourceDir -Filter "*.docx" | Sort-Object Name

foreach ($file in $files) {
  $title = Get-CleanTitle $file.Name
  $paragraphs = Get-DocxParagraphs $file.FullName

  if ($paragraphs.Count -eq 0) {
    Write-Warning "Skipping empty document: $($file.Name)"
    continue
  }

  $contentParagraphs = @($paragraphs | Where-Object {
    $_.Trim().ToLowerInvariant() -ne $title.ToLowerInvariant()
  })
  if ($contentParagraphs.Count -eq 0) {
    $contentParagraphs = $paragraphs
  }

  $content = "# $title`n`n" + ($contentParagraphs -join "`n`n")
  $blog = [ordered]@{
    id = ConvertTo-Slug $title
    title = $title
    summary = Get-Summary $paragraphs $title
    content = $content
    coverImageUrl = $CoverImageUrl
    category = $Category
    author = $Author
    readTimeMinutes = Get-ReadTime $content
    tags = @("sleep", "snoring", "health")
    uploadedBy = $UploadedBy
    createdAt = (Get-Date).ToUniversalTime().ToString("o")
  }

  $blogs.Add($blog)
}

$payload = [ordered]@{
  blogs = $blogs
  videos = @()
}

$outPath = Join-Path (Get-Location) $OutFile
$outDir = Split-Path -Parent $outPath
if (-not (Test-Path -LiteralPath $outDir)) {
  New-Item -ItemType Directory -Path $outDir | Out-Null
}

$json = $payload | ConvertTo-Json -Depth 12
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $json, $utf8NoBom)
Write-Output "Created $outPath with $($blogs.Count) blog documents."
