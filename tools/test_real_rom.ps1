param(
	[string]$ZipPath = '',
	[int]$Cycles = 100000,
	[switch]$CaptureFrame,
	[string]$IverilogPath = '',
	[string]$VvpPath = ''
)

$ErrorActionPreference = 'Stop'

function Resolve-SimulationTool {
	param(
		[string]$Override,
		[string]$Name
	)

	if (-not [string]::IsNullOrWhiteSpace($Override)) {
		if (-not (Test-Path -LiteralPath $Override -PathType Leaf)) {
			throw "$Name was not found at $Override"
		}
		return (Resolve-Path -LiteralPath $Override).Path
	}

	$command = Get-Command $Name -ErrorAction SilentlyContinue
	if ($null -eq $command) {
		throw "$Name was not found on PATH; pass its path explicitly"
	}
	return $command.Source
}

$iverilog = Resolve-SimulationTool -Override $IverilogPath -Name 'iverilog'
$vvp = Resolve-SimulationTool -Override $VvpPath -Name 'vvp'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ZipPath)) {
	$ZipPath = Join-Path $projectRoot 'marblmd2.zip'
}
$packedRom = Join-Path $projectRoot 'roms\MarbleMadness2.rom'
$tracePath = Join-Path $projectRoot 'roms\mm2_bus_trace.csv'
$output = Join-Path $projectRoot 'sim\mm2_cpu_realrom_tb.vvp'
$soundOutput = Join-Path $projectRoot 'sim\mm2_sound_reset_realrom_tb.vvp'

& (Join-Path $PSScriptRoot 'pack_rom.ps1') `
	-ZipPath $ZipPath `
	-OutputPath $packedRom

$sourceFiles = @(
	'sim\mm2_cpu_realrom_tb.sv',
	'rtl\mm2_address_decode.sv',
	'rtl\mm2_video_timing.sv',
	'rtl\fx68k\hdl\verilator\fx68k.sv',
	'rtl\fx68k\hdl\verilator\fx68kAlu.sv',
	'rtl\fx68k\hdl\verilator\uaddrPla.sv',
	'rtl\mm2_m68k_ram.sv',
	'rtl\mm2_sound_comm.sv',
	'rtl\mm2_line_buffer.sv',
	'rtl\mm2_vad.sv',
	'rtl\mm2_playfield.sv',
	'rtl\mm2_motion_objects.sv',
	'rtl\mm2_cpu_subsystem.sv'
) | ForEach-Object {
	Join-Path $projectRoot $_
}

& $iverilog -g2012 -s mm2_cpu_realrom_tb -o $output @sourceFiles
if ($LASTEXITCODE -ne 0) {
	throw 'Real-ROM CPU test compilation failed'
}

$romArgument = (Resolve-Path -LiteralPath $packedRom).Path.Replace('\', '/')
$traceArgument = [System.IO.Path]::GetFullPath($tracePath).Replace('\', '/')
$frameArgument = [System.IO.Path]::GetFullPath(
	(Join-Path $projectRoot 'roms\mm2_fpga_frame.ppm')).Replace('\', '/')
$runDirectory = Join-Path $projectRoot 'rtl\fx68k\hdl'

Push-Location $runDirectory
try {
	$runArguments = @(
		"+ROM=$romArgument",
		"+TRACE=$traceArgument",
		"+CYCLES=$Cycles"
	)
	if ($CaptureFrame) {
		$runArguments += "+FRAME=$frameArgument"
	}
	& $vvp $output @runArguments
	if ($LASTEXITCODE -ne 0) {
		throw 'Real-ROM CPU test failed'
	}
}
finally {
	Pop-Location
}

# The 100,000-cycle trace intentionally ends before the game releases the
# JSA reset latch. Run the focused long-startup regression separately so the
# ordinary trace length remains stable for MAME comparison.
$soundSourceFiles = @(
	'sim\mm2_sound_reset_realrom_tb.sv',
	'rtl\mm2_address_decode.sv',
	'rtl\mm2_video_timing.sv',
	'rtl\fx68k\hdl\verilator\fx68k.sv',
	'rtl\fx68k\hdl\verilator\fx68kAlu.sv',
	'rtl\fx68k\hdl\verilator\uaddrPla.sv',
	'rtl\mm2_m68k_ram.sv',
	'rtl\mm2_sound_comm.sv',
	'rtl\mm2_line_buffer.sv',
	'rtl\mm2_vad.sv',
	'rtl\mm2_cpu_subsystem.sv'
) | ForEach-Object {
	Join-Path $projectRoot $_
}

& $iverilog -g2012 -s mm2_sound_reset_realrom_tb `
	-o $soundOutput @soundSourceFiles
if ($LASTEXITCODE -ne 0) {
	throw 'Real-ROM JSA reset test compilation failed'
}

Push-Location $runDirectory
try {
	& $vvp $soundOutput "+ROM=$romArgument"
	if ($LASTEXITCODE -ne 0) {
		throw 'Real-ROM JSA reset test failed'
	}
}
finally {
	Pop-Location
}

$traceItem = Get-Item -LiteralPath $tracePath
Write-Output ('TRACE_SIZE=' + $traceItem.Length)
Write-Output ('TRACE_SHA256=' +
	(Get-FileHash -LiteralPath $tracePath -Algorithm SHA256).Hash)
