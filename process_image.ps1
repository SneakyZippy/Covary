$code = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class ImageProcessor {
    public static void Process(string inPath, string outPath) {
        using (Bitmap bmp = new Bitmap(inPath)) {
            int width = bmp.Width;
            int height = bmp.Height;
            
            int minX = width;
            int minY = height;
            int maxX = 0;
            int maxY = 0;
            
            Rectangle rect = new Rectangle(0, 0, width, height);
            BitmapData bmpData = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            
            int bytes = Math.Abs(bmpData.Stride) * height;
            byte[] rgbValues = new byte[bytes];
            
            Marshal.Copy(bmpData.Scan0, rgbValues, 0, bytes);
            
            for (int y = 0; y < height; y++) {
                int rowStart = y * bmpData.Stride;
                for (int x = 0; x < width; x++) {
                    int offset = rowStart + (x * 4);
                    int b = rgbValues[offset];
                    int g = rgbValues[offset + 1];
                    int r = rgbValues[offset + 2];
                    int a = rgbValues[offset + 3];
                    
                    if (r > 240 && g > 240 && b > 240) {
                        rgbValues[offset + 3] = 0;
                        rgbValues[offset + 0] = 0;
                        rgbValues[offset + 1] = 0;
                        rgbValues[offset + 2] = 0;
                    } else {
                        if (x < minX) minX = x;
                        if (x > maxX) maxX = x;
                        if (y < minY) minY = y;
                        if (y > maxY) maxY = y;
                    }
                }
            }
            
            Marshal.Copy(rgbValues, 0, bmpData.Scan0, bytes);
            bmp.UnlockBits(bmpData);
            
            int cropWidth = maxX - minX + 1;
            int cropHeight = maxY - minY + 1;
            
            if (cropWidth > 0 && cropHeight > 0) {
                Rectangle cropRect = new Rectangle(minX, minY, cropWidth, cropHeight);
                using (Bitmap cropped = bmp.Clone(cropRect, bmp.PixelFormat)) {
                    int size = Math.Max(cropWidth, cropHeight);
                    int pad = (int)(size * 0.1);
                    int finalSize = size + (pad * 2);
                    
                    using (Bitmap finalBmp = new Bitmap(finalSize, finalSize)) {
                        using (Graphics g = Graphics.FromImage(finalBmp)) {
                            g.Clear(Color.Transparent);
                            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                            int offsetX = (finalSize - cropWidth) / 2;
                            int offsetY = (finalSize - cropHeight) / 2;
                            g.DrawImage(cropped, offsetX, offsetY, cropWidth, cropHeight);
                        }
                        finalBmp.Save(outPath, ImageFormat.Png);
                    }
                }
            } else {
                bmp.Save(outPath, ImageFormat.Png);
            }
        }
    }
}
"@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing
[ImageProcessor]::Process("c:\Covary\CovaryLogo.png", "c:\Covary\assets\icon\app_icon.png")
Write-Host "Image processed successfully!"
