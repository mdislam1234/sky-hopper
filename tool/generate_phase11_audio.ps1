# Generates Sky Hopper's original Phase 11 audio assets from simple waveforms.
# No external samples or music are used.
Set-StrictMode -Version Latest

$SampleRate = 16000
$OutputDirectory = Join-Path $PSScriptRoot '..\assets\audio'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function Write-Wave {
    param([string]$Name, [double[]]$Samples)
    $path = Join-Path $OutputDirectory $Name
    $stream = [System.IO.File]::Create($path)
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([int](36 + $Samples.Count * 2))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
        $writer.Write([int]16)
        $writer.Write([int16]1)
        $writer.Write([int16]1)
        $writer.Write([int]$SampleRate)
        $writer.Write([int]($SampleRate * 2))
        $writer.Write([int16]2)
        $writer.Write([int16]16)
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
        $writer.Write([int]($Samples.Count * 2))
        foreach ($sample in $Samples) {
            $clamped = [Math]::Max(-1.0, [Math]::Min(1.0, $sample))
            $writer.Write([int16][Math]::Round($clamped * 32767))
        }
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function New-Tone {
    param(
        [string]$Name,
        [double]$Duration,
        [double]$StartFrequency,
        [double]$EndFrequency,
        [double]$Volume = 0.42,
        [double]$Noise = 0.0,
        [double]$SecondHarmonic = 0.0,
        [int]$Seed = 11
    )
    $count = [int][Math]::Round($Duration * $SampleRate)
    $samples = [double[]]::new($count)
    $random = [Random]::new($Seed)
    $phase = 0.0
    for ($index = 0; $index -lt $count; $index++) {
        $progress = $index / [Math]::Max(1, $count - 1)
        $frequency = $StartFrequency + ($EndFrequency - $StartFrequency) * $progress
        $phase += 2 * [Math]::PI * $frequency / $SampleRate
        $attack = [Math]::Min(1.0, $progress / 0.035)
        $release = [Math]::Min(1.0, (1.0 - $progress) / 0.12)
        $value = [Math]::Sin($phase)
        if ($SecondHarmonic -ne 0) {
            $value += $SecondHarmonic * [Math]::Sin($phase * 2)
        }
        $value += $Noise * ($random.NextDouble() * 2 - 1)
        $samples[$index] = $value * $Volume * $attack * $release
    }
    Write-Wave -Name $Name -Samples $samples
}

function New-Music {
    param(
        [string]$Name,
        [double[]]$Notes,
        [double]$Bass,
        [double]$Shimmer,
        [double]$Tension = 0.0
    )
    $duration = 6.0
    $count = [int]($duration * $SampleRate)
    $samples = [double[]]::new($count)
    for ($index = 0; $index -lt $count; $index++) {
        $time = $index / $SampleRate
        $beat = [int][Math]::Floor($time * 2) % $Notes.Count
        $within = ($time * 2) % 1
        $note = $Notes[$beat]
        $envelope = 0.38 + 0.62 * [Math]::Exp(-$within * 4.2)
        $melody = [Math]::Sin(2 * [Math]::PI * $note * $time)
        $melody += 0.22 * [Math]::Sin(2 * [Math]::PI * $note * 2 * $time)
        $bassLine = [Math]::Sin(2 * [Math]::PI * $Bass * $time) * 0.48
        $air = [Math]::Sin(2 * [Math]::PI * $Shimmer * $time) * 0.12
        $pulse = [Math]::Sin(2 * [Math]::PI * 4 * $time) * $Tension
        $samples[$index] = ($melody * $envelope + $bassLine + $air + $pulse) * 0.23
    }
    Write-Wave -Name $Name -Samples $samples
}

New-Tone bounce.wav 0.12 300 470 -SecondHarmonic 0.18
New-Tone coin.wav 0.16 740 1120 -SecondHarmonic 0.25
New-Tone perfect.wav 0.28 520 960 -SecondHarmonic 0.30
New-Tone crumble.wav 0.30 150 72 -Volume 0.34 -Noise 0.65
New-Tone hazard_impact.wav 0.28 180 55 -Volume 0.50 -Noise 0.32
New-Tone wind.wav 0.24 240 420 -Volume 0.25 -Noise 0.42
New-Tone cloud.wav 0.30 110 72 -SecondHarmonic 0.24
New-Tone lightning_warning.wav 0.42 260 980 -SecondHarmonic 0.20
New-Tone lightning_strike.wav 0.34 820 65 -Volume 0.52 -Noise 0.72
New-Tone near_miss.wav 0.22 620 330 -SecondHarmonic 0.16
New-Tone new_best.wav 0.62 520 1320 -SecondHarmonic 0.32
New-Tone game_over.wav 0.72 330 92 -SecondHarmonic 0.20
New-Tone ui_tap.wav 0.07 540 620 -Volume 0.22

New-Music music_sunny.wav @(261.625, 329.625, 392, 523.25) 65.5 784
New-Music music_sunset.wav @(220, 277.125, 329.625, 440) 55 659.25
New-Music music_storm.wav @(146.875, 174.625, 220, 196) 36.75 293.75 -Tension 0.08
New-Music music_night.wav @(196, 246.875, 293.75, 392) 49 587.375
New-Music music_space.wav @(164.8, 220, 246.875, 329.625) 41.2 493.875 -Tension 0.035
