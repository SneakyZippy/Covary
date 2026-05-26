$code = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;

public class WebIconGenerator {
    // Generates an icon with a transparent background
    public static void GenerateTransparent(string srcPath, string destPath, int size, float scaleFactor) {
        using (Bitmap srcBmp = new Bitmap(srcPath)) {
            using (Bitmap destBmp = new Bitmap(size, size)) {
                using (Graphics g = Graphics.FromImage(destBmp)) {
                    g.Clear(Color.Transparent);
                    g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                    g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.HighQuality;
                    g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                    
                    int targetSize = (int)(size * scaleFactor);
                    int offset = (size - targetSize) / 2;
                    
                    g.DrawImage(srcBmp, offset, offset, targetSize, targetSize);
                }
                destBmp.Save(destPath, ImageFormat.Png);
            }
        }
    }
    
    // Generates an icon with a solid background color
    public static void GenerateWithBackground(string srcPath, string destPath, int size, float scaleFactor, string hexColor) {
        Color bgColor = ColorTranslator.FromHtml(hexColor);
        using (Bitmap srcBmp = new Bitmap(srcPath)) {
            using (Bitmap destBmp = new Bitmap(size, size)) {
                using (Graphics g = Graphics.FromImage(destBmp)) {
                    g.Clear(bgColor);
                    g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                    g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.HighQuality;
                    g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                    
                    int targetSize = (int)(size * scaleFactor);
                    int offset = (size - targetSize) / 2;
                    
                    g.DrawImage(srcBmp, offset, offset, targetSize, targetSize);
                }
                destBmp.Save(destPath, ImageFormat.Png);
            }
        }
    }
}
"@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing

$src = "c:\Covary\assets\icon\app_icon.png"
$webDir = "c:\Covary\web"
$iconsDir = "c:\Covary\web\icons"

# Ensure directories exist
if (-not (Test-Path $iconsDir)) {
    New-Item -ItemType Directory -Path $iconsDir -Force | Out-Null
}

# 1. Favicon (32x32, transparent, slightly padded)
[WebIconGenerator]::GenerateTransparent($src, "$webDir\favicon.png", 32, 0.9)
Write-Host "Generated favicon.png"

# 2. Icon-192.png (192x192, transparent, slightly padded)
[WebIconGenerator]::GenerateTransparent($src, "$iconsDir\Icon-192.png", 192, 0.85)
Write-Host "Generated Icon-192.png"

# 3. Icon-512.png (512x512, transparent, slightly padded)
[WebIconGenerator]::GenerateTransparent($src, "$iconsDir\Icon-512.png", 512, 0.85)
Write-Host "Generated Icon-512.png"

# 4. Icon-maskable-192.png (192x192, background #0B1120, padded more for safe zone)
[WebIconGenerator]::GenerateWithBackground($src, "$iconsDir\Icon-maskable-192.png", 192, 0.70, "#0B1120")
Write-Host "Generated Icon-maskable-192.png"

# 5. Icon-maskable-512.png (512x512, background #0B1120, padded more for safe zone)
[WebIconGenerator]::GenerateWithBackground($src, "$iconsDir\Icon-maskable-512.png", 512, 0.70, "#0B1120")
Write-Host "Generated Icon-maskable-512.png"

# 6. Icon-180.png (180x180, background #0B1120, apple-touch-icon, padded for beautiful crop)
[WebIconGenerator]::GenerateWithBackground($src, "$iconsDir\Icon-180.png", 180, 0.75, "#0B1120")
Write-Host "Generated Icon-180.png"

Write-Host "Web icons generation complete!"
