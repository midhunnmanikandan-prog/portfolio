# Image Compression Script for Archsol Portfolio
# Uses .NET System.Drawing to resize and compress images
# Keeps originals in a backup folder, replaces with optimized versions

Add-Type -AssemblyName System.Drawing

$imageRoot = "c:\Promline\Archsol\images"
$maxWidth = 1920    # Max width in pixels (Full HD)
$jpegQuality = 75   # JPEG quality (1-100), 75 is a good balance

# Create encoder parameters for JPEG quality
$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$jpegQuality)

# Create backup folder
$backupRoot = "$imageRoot\_originals_backup"
if (!(Test-Path $backupRoot)) {
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
}

# Get all image files
$imageFiles = Get-ChildItem -Path $imageRoot -Recurse -Include *.jpg, *.jpeg, *.png -File | Where-Object { $_.FullName -notlike "*_originals_backup*" }

$totalSaved = 0
$processedCount = 0

foreach ($file in $imageFiles) {
    $relativePath = $file.FullName.Substring($imageRoot.Length)
    $backupPath = Join-Path $backupRoot $relativePath
    $backupDir = Split-Path $backupPath -Parent

    # Create backup directory structure
    if (!(Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    # Backup original
    Copy-Item $file.FullName $backupPath -Force

    $originalSize = $file.Length
    $originalSizeMB = [math]::Round($originalSize / 1MB, 2)

    try {
        # Load image
        $image = [System.Drawing.Image]::FromFile($file.FullName)
        $width = $image.Width
        $height = $image.Height

        # Calculate new dimensions (maintain aspect ratio)
        if ($width -gt $maxWidth) {
            $ratio = $maxWidth / $width
            $newWidth = $maxWidth
            $newHeight = [int]($height * $ratio)
        } else {
            $newWidth = $width
            $newHeight = $height
        }

        # Create resized bitmap
        $bitmap = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.DrawImage($image, 0, 0, $newWidth, $newHeight)

        # Dispose original before saving
        $image.Dispose()

        # Save as JPEG (convert PNGs to JPG for smaller size)
        $outputPath = $file.FullName
        if ($file.Extension -eq ".png") {
            $outputPath = [System.IO.Path]::ChangeExtension($file.FullName, ".jpg")
        }
        $bitmap.Save($outputPath, $jpegCodec, $encoderParams)
        $bitmap.Dispose()
        $graphics.Dispose()

        # Remove original PNG if converted to JPG
        if ($file.Extension -eq ".png" -and $outputPath -ne $file.FullName) {
            Remove-Item $file.FullName -Force
        }

        $newSize = (Get-Item $outputPath).Length
        $newSizeMB = [math]::Round($newSize / 1MB, 2)
        $saved = $originalSize - $newSize
        $totalSaved += $saved
        $processedCount++

        $pctReduction = [math]::Round(($saved / $originalSize) * 100, 1)
        Write-Host "OK: $relativePath | ${originalSizeMB}MB -> ${newSizeMB}MB (-${pctReduction}%)" -ForegroundColor Green

    } catch {
        Write-Host "SKIP: $relativePath - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$totalSavedMB = [math]::Round($totalSaved / 1MB, 2)
Write-Host ""
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "Processed: $processedCount images" -ForegroundColor Cyan
Write-Host "Total saved: ${totalSavedMB} MB" -ForegroundColor Cyan
Write-Host "Originals backed up to: $backupRoot" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTE: PNG files were converted to JPG. Update your HTML references:" -ForegroundColor Yellow
Write-Host "  - .png -> .jpg for any converted files" -ForegroundColor Yellow
