# Builds the home-screen app icons: Jae chugging on a cream/amber sunburst badge with a thick ink ring.
# Writes docs/icon-512.png (transparent corners) and docs/icon-180.png (Apple touch icon, dark backdrop).
# Run from the project root:  powershell -ExecutionPolicy Bypass -File tools/make_icons.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot

$cream = [Drawing.Color]::FromArgb(245, 232, 199)
$amber = [Drawing.Color]::FromArgb(242, 158, 31)
$ink = [Drawing.Color]::FromArgb(26, 18, 11)
$backdrop = [Drawing.Color]::FromArgb(26, 18, 11)     # #1a120b, matches the manifest background

function New-Badge([int]$size, [bool]$opaque) {
    $bmp = New-Object Drawing.Bitmap $size, $size, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'
    if ($opaque) { $g.Clear($backdrop) } else { $g.Clear([Drawing.Color]::Transparent) }

    $s = $size / 512.0
    $pad = 10 * $s
    $circle = New-Object Drawing.RectangleF $pad, $pad, ($size - 2 * $pad), ($size - 2 * $pad)
    $clip = New-Object Drawing.Drawing2D.GraphicsPath
    $clip.AddEllipse($circle)

    # sunburst rays inside the circle
    $g.SetClip($clip)
    $g.Clear($cream)
    $c = New-Object Drawing.PointF ($size / 2), ($size / 2)
    $rays = 24
    $brush = New-Object Drawing.SolidBrush $amber
    for ($i = 0; $i -lt $rays; $i += 2) {
        $a0 = 2 * [Math]::PI * $i / $rays
        $a1 = 2 * [Math]::PI * ($i + 1) / $rays
        $r = $size
        $pts = @(
            $c,
            (New-Object Drawing.PointF ($c.X + [Math]::Cos($a0) * $r), ($c.Y + [Math]::Sin($a0) * $r)),
            (New-Object Drawing.PointF ($c.X + [Math]::Cos($a1) * $r), ($c.Y + [Math]::Sin($a1) * $r))
        )
        $g.FillPolygon($brush, [Drawing.PointF[]]$pts)
    }
    # soft cream glow in the middle so the character pops
    $glow = New-Object Drawing.Drawing2D.GraphicsPath
    $gr = 150 * $s
    $glow.AddEllipse($c.X - $gr, $c.Y - $gr, 2 * $gr, 2 * $gr)
    $pgb = New-Object Drawing.Drawing2D.PathGradientBrush $glow
    $pgb.CenterColor = [Drawing.Color]::FromArgb(230, $cream)
    $pgb.SurroundColors = [Drawing.Color[]]@([Drawing.Color]::FromArgb(0, $cream))
    $g.FillPath($pgb, $glow)

    # Jae chugging, centered
    $sprite = [Drawing.Image]::FromFile((Join-Path $root 'assets\sprites\char1_chug.png'))
    $box = 360 * $s
    $k = [Math]::Min($box / $sprite.Width, $box / $sprite.Height)
    $w = $sprite.Width * $k; $h = $sprite.Height * $k
    $g.DrawImage($sprite, [single]($c.X - $w / 2), [single]($c.Y - $h / 2 + 8 * $s), [single]$w, [single]$h)
    $sprite.Dispose()
    $g.ResetClip()

    # thick black ink ring + thin amber inner line
    $ringW = 22 * $s
    $pen = New-Object Drawing.Pen $ink, $ringW
    $inset = $pad + $ringW / 2
    $g.DrawEllipse($pen, $inset, $inset, $size - 2 * $inset, $size - 2 * $inset)
    $pen2 = New-Object Drawing.Pen $amber, (5 * $s)
    $inset2 = $pad + $ringW + 3 * $s
    $g.DrawEllipse($pen2, $inset2, $inset2, $size - 2 * $inset2, $size - 2 * $inset2)
    $g.Dispose()
    return $bmp
}

$docs = Join-Path $root 'docs'
$b512 = New-Badge 512 $false
$b512.Save((Join-Path $docs 'icon-512.png'), [Drawing.Imaging.ImageFormat]::Png)
$b512.Dispose()
$b180 = New-Badge 180 $true
$b180.Save((Join-Path $docs 'icon-180.png'), [Drawing.Imaging.ImageFormat]::Png)
$b180.Dispose()
Write-Host "wrote docs/icon-512.png and docs/icon-180.png"
