param(
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

# A MiSTer MRA begins ROM #0 while its ordinary core reset is still asserted.
# Guard the storage-path wiring that prevents ioctl_wait from deadlocking on
# the first byte: both the loader and its arbiter must use storage_reset.
$coreText = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'rtl\mm2_core.sv')
$loaderBlock = [regex]::Match(
	$coreText,
	'(?s)mm2_rom_loader\s+rom_loader\s*\((.*?)\);'
)
$arbiterBlock = [regex]::Match(
	$coreText,
	'(?s)mm2_memory_arbiter\s+memory_arbiter\s*\((.*?)\);'
)
if (-not $loaderBlock.Success -or
	$loaderBlock.Groups[1].Value -notmatch '\.reset\(storage_reset\)' -or
	-not $arbiterBlock.Success -or
	$arbiterBlock.Groups[1].Value -notmatch '\.reset\(storage_reset\)') {
	throw 'ROM loader and memory arbiter must remain on storage_reset'
}
Write-Host 'mm2_storage_reset_wiring: PASS'

$tests = @(
	@{
		Name = 'mm2_address_decode_tb'
		Files = @(
			'sim\mm2_address_decode_tb.sv',
			'rtl\mm2_address_decode.sv'
		)
	},
	@{
		Name = 'mm2_rom_layout_tb'
		Files = @(
			'sim\mm2_rom_layout_tb.sv',
			'rtl\mm2_rom_layout.sv'
		)
	},
	@{
		Name = 'mm2_rom_loader_tb'
		Files = @(
			'sim\mm2_rom_loader_tb.sv',
			'rtl\mm2_rom_layout.sv',
			'rtl\mm2_rom_loader.sv'
		)
	},
	@{
		Name = 'mm2_memory_arbiter_tb'
		Files = @(
			'sim\mm2_memory_arbiter_tb.sv',
			'rtl\mm2_memory_arbiter.sv'
		)
	},
	@{
		Name = 'mm2_vad_tb'
		Files = @(
			'sim\mm2_vad_tb.sv',
			'rtl\mm2_vad.sv'
		)
	},
	@{
		Name = 'mm2_playfield_tb'
		Files = @(
			'sim\mm2_playfield_tb.sv',
			'rtl\mm2_playfield.sv'
		)
	},
	@{
		Name = 'mm2_motion_objects_tb'
		Files = @(
			'sim\mm2_motion_objects_tb.sv',
			'rtl\mm2_line_buffer.sv',
			'rtl\mm2_motion_objects.sv'
		)
	},
	@{
		Name = 'mm2_sdram_tb'
		Files = @(
			'sim\mm2_sdram_tb.sv',
			'rtl\mm2_sdram.sv'
		)
	},
	@{
		Name = 'mm2_sound_comm_tb'
		Files = @(
			'sim\mm2_sound_comm_tb.sv',
			'rtl\mm2_sound_comm.sv'
		)
	},
	@{
		Name = 'mm2_jsa_inputs_tb'
		Files = @(
			'sim\mm2_jsa_inputs_tb.sv',
			'rtl\mm2_jsa_inputs.sv'
		)
	},
	@{
		Name = 'mm2_trackball_to_joystick_tb'
		Files = @(
			'sim\mm2_trackball_to_joystick_tb.sv',
			'rtl\mm2_trackball_to_joystick.sv'
		)
	},
	@{
		Name = 'mm2_cpu_reset_tb'
		Files = @(
			'sim\mm2_cpu_reset_tb.sv',
			'rtl\mm2_address_decode.sv',
			'rtl\fx68k\hdl\verilator\fx68k.sv',
			'rtl\fx68k\hdl\verilator\fx68kAlu.sv',
			'rtl\fx68k\hdl\verilator\uaddrPla.sv',
			'rtl\mm2_m68k_ram.sv',
			'rtl\mm2_sound_comm.sv',
			'rtl\mm2_vad.sv',
			'rtl\mm2_cpu_subsystem.sv'
		)
		RunDirectory = 'rtl\fx68k\hdl'
	}
)

foreach ($test in $tests) {
	$output = Join-Path $projectRoot "sim\$($test.Name).vvp"
	$sourceFiles = @($test.Files | ForEach-Object {
		Join-Path $projectRoot $_
	})

	& $iverilog -g2012 -s $test.Name -o $output @sourceFiles
	if ($LASTEXITCODE -ne 0) {
		throw "$($test.Name) compilation failed"
	}

	$runDirectory = $projectRoot
	if ($test.ContainsKey('RunDirectory')) {
		$runDirectory = Join-Path $projectRoot $test.RunDirectory
	}

	Push-Location $runDirectory
	try {
		& $vvp $output
		if ($LASTEXITCODE -ne 0) {
			throw "$($test.Name) failed"
		}
	}
	finally {
		Pop-Location
	}
}
