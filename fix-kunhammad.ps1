Add-Type -AssemblyName System.Drawing

$srcPath = 'c:\Promline\Archsol\images\_originals_backup\EXTERIOR\RESIDENTIAL\KUNHAMMAD  RENOVATION PROJECT  MALAPPURAM.jpeg'
$destPath = 'c:\Promline\Archsol\images\EXTERIOR\RESIDENTIAL\KUNHAMMAD  RENOVATION PROJECT  MALAPPURAM.jpeg'

Write-Host "Loading original image..."
$img = [System.Drawing.Image]::FromFile($srcPath)
Write-Host "Original size: $($img.Width) x $($img.Height)"

# Check and apply EXIF orientation
$orientProp = $img.PropertyItems | Where-Object { $_.Id -eq 0x0112 }
if ($orientProp) {
    $orient = $orientProp.Value[0]
    Write-Host "EXIF Orientation: $orient"
    switch ($orient) {
        3 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone); Write-Host "Rotating 180 degrees" }
        6 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone); Write-Host "Rotating 90 degrees clockwise" }
        8 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone); Write-Host "Rotating 270 degrees clockwise" }
    }
} else {
    Write-Host "No EXIF orientation tag found. Rotating 90 degrees clockwise as default fix."
    $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone)
}

# Resize
$maxW = 1920
if ($img.Width -gt $maxW) {
    $r = $maxW / $img.Width
    $nw = $maxW
    $nh = [int]($img.Height * $r)
} else {
    $nw = $img.Width
    $nh = $img.Height
}

Write-Host "Resizing to: $nw x $nh"
$bmp = New-Object System.Drawing.Bitmap($nw, $nh)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.DrawImage($img, 0, 0, $nw, $nh)
$img.Dispose()

# Save as JPEG
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]75)
$bmp.Save($destPath, $codec, $ep)
$bmp.Dispose()
$g.Dispose()

$newSize = [math]::Round((Get-Item $destPath).Length / 1MB, 2)
Write-Host "Done! Saved ($newSize MB) to: $destPath"
