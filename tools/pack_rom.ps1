param(
	[Parameter(Mandatory = $true)]
	[string]$ZipPath,

	[string]$OutputPath
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectRoot = Split-Path -Parent $PSScriptRoot
$mraPath = Join-Path $projectRoot 'mra\Marble Madness II (prototype).mra'

if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
	throw "ROM archive was not found: $ZipPath"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	$OutputPath = Join-Path $projectRoot 'roms\MarbleMadness2.rom'
}

function Get-Crc32 {
	param([byte[]]$Bytes)

	[uint32]$crc = [uint32]::MaxValue
	[uint32]$polynomial = [Convert]::ToUInt32('EDB88320', 16)

	foreach ($byte in $Bytes) {
		$crc = $crc -bxor [uint32]$byte
		for ($bit = 0; $bit -lt 8; $bit++) {
			if (($crc -band 1) -ne 0) {
				$crc = [uint32](($crc -shr 1) -bxor $polynomial)
			}
			else {
				$crc = [uint32]($crc -shr 1)
			}
		}
	}

	return [uint32](-bnot $crc)
}

function Get-EntryBytes {
	param(
		[System.IO.Compression.ZipArchiveEntry]$Entry,
		[hashtable]$Cache
	)

	if ($Cache.ContainsKey($Entry.FullName)) {
		return [byte[]]$Cache[$Entry.FullName]
	}

	$entryStream = $Entry.Open()
	$copy = [System.IO.MemoryStream]::new()
	try {
		$entryStream.CopyTo($copy)
		[byte[]]$bytes = $copy.ToArray()
		$Cache[$Entry.FullName] = $bytes
		return $bytes
	}
	finally {
		$copy.Dispose()
		$entryStream.Dispose()
	}
}

[xml]$mra = Get-Content -LiteralPath $mraPath -Raw
$romNode = $mra.SelectSingleNode('/misterromdescription/rom[@index="0"]')
if ($null -eq $romNode) {
	throw 'The MRA has no index-0 ROM stream.'
}

$archive = [System.IO.Compression.ZipFile]::OpenRead(
	(Resolve-Path -LiteralPath $ZipPath).Path)
$packed = [System.IO.MemoryStream]::new()

try {
	$entries = @{}
	foreach ($entry in $archive.Entries) {
		if (-not [string]::IsNullOrEmpty($entry.Name)) {
			$entries[$entry.FullName] = $entry
		}
	}

	$cache = @{}

	foreach ($part in $romNode.SelectNodes('.//part')) {
		$name = [string]$part.GetAttribute('name')
		$expectedCrc = ([string]$part.GetAttribute('crc')).ToLowerInvariant()

		if (-not $entries.ContainsKey($name)) {
			throw "Missing ROM member: $name"
		}

		[byte[]]$bytes = Get-EntryBytes -Entry $entries[$name] -Cache $cache
		$actualCrc = '{0:x8}' -f (Get-Crc32 -Bytes $bytes)
		if ($actualCrc -ne $expectedCrc) {
			throw "CRC mismatch for $name`: expected $expectedCrc, got $actualCrc"
		}

		Write-Output ('CRC OK  {0,-12} {1,8} bytes  {2}' -f
			$name, $bytes.Length, $actualCrc)
	}

	foreach ($node in $romNode.ChildNodes) {
		if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) {
			continue
		}

		if ($node.LocalName -eq 'part') {
			$name = [string]$node.GetAttribute('name')
			[byte[]]$bytes = Get-EntryBytes -Entry $entries[$name] -Cache $cache
			$packed.Write($bytes, 0, $bytes.Length)
		}
		elseif ($node.LocalName -eq 'interleave') {
			if ($node.GetAttribute('output') -ne '16') {
				throw "Unsupported interleave width: $($node.GetAttribute('output'))"
			}

			# MiSTer's MRA map string is ordered from the lowest output byte
			# upward. For output=16, map=01 supplies the first (68000 high)
			# byte and map=10 supplies the second (68000 low) byte.
			$highNode = $node.SelectSingleNode('./part[@map="01"]')
			$lowNode = $node.SelectSingleNode('./part[@map="10"]')
			if (($null -eq $highNode) -or ($null -eq $lowNode)) {
				throw 'A 16-bit interleave must contain map=10 and map=01 parts.'
			}

			[byte[]]$high = Get-EntryBytes `
				-Entry $entries[[string]$highNode.GetAttribute('name')] `
				-Cache $cache
			[byte[]]$low = Get-EntryBytes `
				-Entry $entries[[string]$lowNode.GetAttribute('name')] `
				-Cache $cache

			if ($high.Length -ne $low.Length) {
				throw 'Interleaved ROM halves have different lengths.'
			}

			for ($offset = 0; $offset -lt $high.Length; $offset++) {
				$packed.WriteByte($high[$offset])
				$packed.WriteByte($low[$offset])
			}
		}
		else {
			throw "Unsupported MRA ROM element: $($node.LocalName)"
		}
	}

	if ($packed.Length -ne 0x250000) {
		throw ('Packed stream has length 0x{0:X}, expected 0x250000.' -f
			$packed.Length)
	}

	$outputDirectory = Split-Path -Parent $OutputPath
	if (-not (Test-Path -LiteralPath $outputDirectory)) {
		New-Item -ItemType Directory -Path $outputDirectory | Out-Null
	}

	[System.IO.File]::WriteAllBytes(
		[System.IO.Path]::GetFullPath($OutputPath),
		$packed.ToArray())
}
finally {
	$packed.Dispose()
	$archive.Dispose()
}

$outputItem = Get-Item -LiteralPath $OutputPath
$outputHash = Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256
Write-Output ('PACKED   0x{0:X6} bytes' -f $outputItem.Length)
Write-Output ('SHA-256  ' + $outputHash.Hash)
Write-Output ('OUTPUT   ' + $outputItem.FullName)
