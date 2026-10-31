#Requires -Version 7.0
<#
.SYNOPSIS
    MP4-Repair-Tool - Riparatore di file MP4 con supporto Untrunc per video X/Twitter.
.DESCRIPTION
    Verifica la presenza di FFmpeg e Untrunc. Se manca Untrunc, lo scarica 
    automaticamente dal repository ufficiale. Offre due modalità: riparazione 
    standard con FFmpeg e recupero video X/Twitter con Untrunc (richiede un file 
    di riferimento sano e verifica la dimensione finale).
.NOTES
    Prerequisiti: PowerShell 7+, FFmpeg (per modalità standard), Untrunc.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Palette Colori Matrix ---
$BgColor = [System.Drawing.Color]::Black
$FgColor = [System.Drawing.Color]::Lime
$InputBgColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$BtnColor = [System.Drawing.Color]::FromArgb(0, 50, 0)

# ============================================================
# FUNZIONE: Controllo e Download Prerequisiti
# ============================================================
function Ensure-Tools {
    # Controllo FFmpeg
    $ffmpegPath = (Get-Command "ffmpeg.exe" -ErrorAction SilentlyContinue).Source
    if (-not $ffmpegPath) { $ffmpegPath = Join-Path (Get-Location) "ffmpeg.exe" }
    if (-not (Test-Path $ffmpegPath)) {
        [System.Windows.Forms.MessageBox]::Show(
            "FFmpeg non trovato!`n`nScarica la build per Windows da:`nhttps://www.gyan.dev/ffmpeg/builds/`n`nEstrai ffmpeg.exe e mettilo in questa cartella.", 
            "FFmpeg Mancante", "OK", "Warning"
        )
        return $false
    }

    # Controllo e Download Untrunc
    $untruncPath = (Get-Command "untrunc.exe" -ErrorAction SilentlyContinue).Source
    
    if (-not $untruncPath) { 
        $existing = Get-ChildItem -Path (Get-Location) -Filter "*untrunc*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($existing) { $untruncPath = $existing.FullName }
    }
    
    # Controllo di sicurezza: se il percorso esiste ed è valido, siamo a posto
    if ($untruncPath -and (Test-Path $untruncPath)) {
        return $true
    }

    # Se arriviamo qui, Untrunc non c'è. Chiediamo se scaricarlo.
    $choice = [System.Windows.Forms.MessageBox]::Show(
        "Untrunc non trovato!`n`nVuoi scaricarlo automaticamente da GitHub? (Circa 11 MB)", 
        "Untrunc Mancante", "YesNo", "Question"
    )
    
    if ($choice -eq "Yes") {
        try {
            Write-Host "Download di Untrunc in corso..." -ForegroundColor Yellow
            $zipPath = Join-Path $env:TEMP "untrunc_x64.zip"
            $downloadUrl = "https://github.com/anthwlock/untrunc/releases/download/latest/untrunc_x64.zip"
            
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
            
            $tempExtract = Join-Path $env:TEMP "untrunc_extract"
            if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force }
            Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force
            Remove-Item -Path $zipPath -Force
            
            $foundExe = Get-ChildItem -Path $tempExtract -Filter "*untrunc*.exe" -Recurse | Select-Object -First 1
            
            if ($foundExe) {
                $sourceFolder = $foundExe.Directory.FullName
                Get-ChildItem -Path $sourceFolder -File | Move-Item -Destination (Get-Location) -Force
                Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
                
                $finalExe = Join-Path (Get-Location) $foundExe.Name
                if ($foundExe.Name -ne "untrunc.exe") {
                    Rename-Item -Path $finalExe -NewName "untrunc.exe" -Force
                }
                
                Write-Host "Untrunc scaricato, installato e rinominato con successo!" -ForegroundColor Green
                return $true
            } else {
                throw "Estrazione fallita: nessun file .exe trovato."
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Errore durante il download di Untrunc: $_`n`nScaricalo manualmente da: https://github.com/anthwlock/untrunc/releases/latest", 
                "Errore Download", "OK", "Error"
            )
            return $false
        }
    } else { return $false }
}

# --- Esecuzione Controllo ---
if (-not (Ensure-Tools)) { exit }

# ============================================================
# SELEZIONE CARTELLA INPUT
# ============================================================
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Seleziona la cartella con i video MP4 da riparare"
if ($folderBrowser.ShowDialog() -ne "OK") { exit }
$cartellaInput = $folderBrowser.SelectedPath

# ============================================================
# SCELTA MODALITÀ
# ============================================================
$modalita = [System.Windows.Forms.MessageBox]::Show(
    "Scegli la modalità di riparazione:`n`n[Sì] = Riparazione Standard (FFmpeg)`n[No] = Recupero X/Twitter (Untrunc)", 
    "Metodo di Riparazione", 
    "YesNoCancel", 
    "Question"
)

if ($modalita -eq "Cancel") { exit }
$isTwitterMode = ($modalita -eq "No")

# ============================================================
# SETUP CARTELLA OUTPUT
# ============================================================
$cartellaOutput = Join-Path $cartellaInput "corretti"
if (-not (Test-Path -Path $cartellaOutput)) {
    New-Item -ItemType Directory -Path $cartellaOutput | Out-Null
}

# ============================================================
# VARIABILI SPECIFICHE PER MODALITÀ
# ============================================================
$untruncExe = (Get-Command "untrunc.exe" -ErrorAction SilentlyContinue).Source
if (-not $untruncExe) { 
    $found = Get-ChildItem -Path (Get-Location) -Filter "*untrunc*.exe" | Select-Object -First 1
    if ($found) { $untruncExe = $found.FullName }
}
$ffmpegExe = (Get-Command "ffmpeg.exe" -ErrorAction SilentlyContinue).Source
if (-not $ffmpegExe) { $ffmpegExe = Join-Path (Get-Location) "ffmpeg.exe" }

$refFile = ""
$rimuoviAudio = $false

if ($isTwitterMode) {
    $refBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $refBrowser.Title = "Seleziona un video MP4 SANO di X (Twitter) come riferimento"
    $refBrowser.Filter = "Video MP4|*.mp4"
    if ($refBrowser.ShowDialog() -ne "OK") { exit }
    $refFile = $refBrowser.FileName
} else {
    $audioChoice = [System.Windows.Forms.MessageBox]::Show("Vuoi RIMUOVERE l'audio dai video riparati?", "Gestione Audio", "YesNo", "Question")
    $rimuoviAudio = ($audioChoice -eq "Yes")
}

# ============================================================
# RICERCA FILE
# ============================================================
$videoFiles = Get-ChildItem -Path $cartellaInput -Filter "*.mp4" -File | Where-Object { 
    $_.FullName -notlike "*\corretti\*" -and 
    $_.FullName -ne $refFile -and 
    $_.Name -notlike "*_fixed*" 
}
if ($videoFiles.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("Nessun file .mp4 trovato nella cartella.", "Info", "OK", "Information")
    exit
}

$logSummary = @()
$successiUntrunc = 0
$successiFfmpeg = 0
$errori = 0

# ============================================================
# ELABORAZIONE
# ============================================================
foreach ($video in $videoFiles) {
    $fileInput = $video.FullName
    $baseName = $video.BaseName
    $fileOutput = Join-Path $cartellaOutput "$baseName.mp4"
    $originalSize = $video.Length

    Write-Host "Elaborazione: $($video.Name)..." -ForegroundColor Yellow -NoNewline

    $success = $false

    if ($isTwitterMode) {
        # --- MODALITÀ UNTRUNC PURA ---
        # Eseguiamo Untrunc nella cartella dei video
        Push-Location $cartellaInput
        try {
            $untruncArgs = @("-s", $refFile, $fileInput)
            & $untruncExe @untruncArgs 2>&1 | Out-Null
        } catch {
            Write-Host " [ERRORE UNTRUNC]" -ForegroundColor Red -NoNewline
        }
        Pop-Location

        # Cerchiamo il file generato (che avrà _fixed nel nome)
        $generatedFile = Get-ChildItem -Path $cartellaInput -Filter "*_fixed*" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1

        if ($generatedFile) {
            $newSize = $generatedFile.Length
            # Verifichiamo che il file sia grande almeno il 90% dell'originale
            if ($newSize -gt ($originalSize * 0.9)) {
                Move-Item -Path $generatedFile.FullName -Destination $fileOutput -Force
                Write-Host " -> [UNTRUNC] OK" -ForegroundColor Green
                $logSummary += "[UNTRUNC] $($video.Name)"
                $successiUntrunc++
                $success = $true
            } else {
                Write-Host " -> [INCOMPLETO]" -ForegroundColor Magenta
                $logSummary += "[INCOMPLETO] $($video.Name) - Recuperato solo $([math]::Round(($newSize/$originalSize)*100))%"
                Remove-Item -Path $generatedFile.FullName -Force
                $errori++
            }
        } else {
            Write-Host " -> [FALLITO]" -ForegroundColor Red
            $logSummary += "[FALLITO] $($video.Name)"
            $errori++
        }
    } else {
        # --- MODALITÀ FFMPEG STANDARD ---
        Write-Host " -> [FFMPEG]" -ForegroundColor Yellow -NoNewline
        try {
            $ffmpegArgs = @("-y", "-err_detect", "ignore_err", "-i", $fileInput)
            if ($rimuoviAudio) { $ffmpegArgs += "-an" }
            $ffmpegArgs += @("-c", "copy", "-movflags", "faststart", $fileOutput)
            
            & $ffmpegExe @ffmpegArgs 2>&1 | Out-Null
        } catch {
            Write-Host " [ERRORE FFMPEG]" -ForegroundColor Red -NoNewline
        }

        if ((Test-Path -Path $fileOutput) -and ((Get-Item $fileOutput).Length -gt 0)) {
            Write-Host " OK" -ForegroundColor Green
            $logSummary += "[FFMPEG] $($video.Name)"
            $successiFfmpeg++
        } else {
            Write-Host " ERRORE" -ForegroundColor Red
            $logSummary += "[ERRORE] $($video.Name)"
            $errori++
        }
    }
}

# ============================================================
# GUI MATRIX - RIEPILOGO FINALE
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Riparazione Completata - FabryToolbox"
$form.Size = New-Object System.Drawing.Size(700, 500)
$form.StartPosition = "CenterScreen"
$form.BackColor = $BgColor
$form.ForeColor = $FgColor
$form.Font = "Consolas, 10"

$modalitaNome = if ($isTwitterMode) { "Recupero X/Twitter (Untrunc)" } else { "Standard (FFmpeg)" }
$headerText = "Modalità: $modalitaNome`r`n" +
              "Recuperati con Untrunc: $successiUntrunc`r`n" +
              "Riparati con FFmpeg: $successiFfmpeg`r`n" +
              "Errori / Incompleti: $errori`r`n" +
              "Cartella Output: $cartellaOutput`r`n" +
              "--------------------------------------------------`r`n`r`n"

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.Dock = "Fill"
$textBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$textBox.ReadOnly = $true
$textBox.BackColor = $InputBgColor
$textBox.ForeColor = $FgColor
$textBox.Text = $headerText + ($logSummary -join "`r`n")
$form.Controls.Add($textBox)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "CHIUDI"
$btnClose.Dock = "Bottom"
$btnClose.Height = 40
$btnClose.BackColor = $BtnColor
$btnClose.ForeColor = $FgColor
$btnClose.FlatStyle = "Flat"
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

$form.ShowDialog() | Out-Null
