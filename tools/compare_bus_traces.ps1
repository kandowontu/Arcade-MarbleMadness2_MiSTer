param(
	[string]$FpgaTrace = '',
	[string]$MameTrace = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($FpgaTrace)) {
	$FpgaTrace = Join-Path $projectRoot 'roms\mm2_bus_trace.csv'
}
if ([string]::IsNullOrWhiteSpace($MameTrace)) {
	$MameTrace = Join-Path $projectRoot 'roms\mm2_mame_bus_trace.log'
}

function Format-Access {
	param(
		[string]$Type,
		[string]$Address,
		[string]$Data
	)

	$addressValue = [Convert]::ToUInt32($Address, 16)
	if ($Type -eq 'R') {
		return ('R,{0:X6}' -f $addressValue)
	}

	$dataValue = [Convert]::ToUInt32($Data, 16)
	return ('W,{0:X6},{1:X}' -f $addressValue, $dataValue)
}

if (-not (Test-Path -LiteralPath $FpgaTrace -PathType Leaf)) {
	throw "FPGA trace was not found: $FpgaTrace"
}
if (-not (Test-Path -LiteralPath $MameTrace -PathType Leaf)) {
	throw "MAME trace was not found: $MameTrace"
}

$fpga = @(
	Import-Csv -LiteralPath $FpgaTrace | ForEach-Object {
		$type = if ($_.rw -eq '1') { 'R' } else { 'W' }
		Format-Access -Type $type -Address $_.address -Data $_.write_data
	}
)

$mame = @(
	Get-Content -LiteralPath $MameTrace | ForEach-Object {
		if ($_ -match '^R,([0-9A-Fa-f]+)$') {
			Format-Access -Type 'R' -Address $Matches[1] -Data '0'
		}
		elseif ($_ -match '^W,([0-9A-Fa-f]+),([0-9A-Fa-f]+)$') {
			Format-Access -Type 'W' -Address $Matches[1] -Data $Matches[2]
		}
	}
)

if (($fpga.Count -lt 128) -or ($mame.Count -lt 128)) {
	throw 'Both traces must contain at least 128 bus accesses.'
}

$alignment = -1
for ($candidate = 0; $candidate -le 32; $candidate++) {
	$matches = $true
	for ($index = 0; $index -lt 128; $index++) {
		if ($fpga[$candidate + $index] -cne $mame[$index]) {
			$matches = $false
			break
		}
	}
	if ($matches) {
		$alignment = $candidate
		break
	}
}

if ($alignment -lt 0) {
	throw 'Unable to align the FPGA and MAME trace prefixes.'
}

$compareCount = [Math]::Min($fpga.Count - $alignment, $mame.Count)
for ($index = 0; $index -lt $compareCount; $index++) {
	$fpgaAccess = $fpga[$alignment + $index]
	$mameAccess = $mame[$index]
	if ($fpgaAccess -cne $mameAccess) {
		throw ("Bus mismatch at aligned cycle {0}: FPGA={1}, MAME={2}" -f
			($index + 1), $fpgaAccess, $mameAccess)
	}
}

Write-Output ('FPGA_BUS_CYCLES=' + $fpga.Count)
Write-Output ('MAME_BUS_CYCLES=' + $mame.Count)
Write-Output ('ALIGNMENT_SKIPPED_FPGA_CYCLES=' + $alignment)
Write-Output ('COMPARED_BUS_CYCLES=' + $compareCount)
Write-Output 'BUS_TRACE_COMPARISON=PASS'
