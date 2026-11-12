# Slices the character sheets in raw_art/ into transparent sprites in assets/sprites/.
# No Python needed: uses Windows' built-in .NET imaging.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File tools/slice_sprites.ps1
param(
    [int]$TargetHeight = 240,
    [int]$Pad = 10,
    [int]$BgThreshold = 232   # a pixel is "background white" if all channels are above this
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class Slicer
{
    class Comp { public int Area, MinX, MinY, MaxX, MaxY; public List<int> Px = new List<int>(); }

    public static string Process(string sheet, int cols, int rows, string[] names, string outDir,
                                 int targetH, int pad, int thr)
    {
        var log = new System.Text.StringBuilder();
        Bitmap bmp = new Bitmap(sheet);
        int W = bmp.Width, H = bmp.Height;
        var rect = new Rectangle(0, 0, W, H);
        BitmapData bd = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        byte[] px = new byte[W * H * 4];
        Marshal.Copy(bd.Scan0, px, 0, px.Length);
        bmp.UnlockBits(bd); bmp.Dispose();

        Func<int, int> minC = i => Math.Min(px[i * 4], Math.Min(px[i * 4 + 1], px[i * 4 + 2]));

        // 1) Flood-fill background from the image edges (keeps enclosed whites: gloves, eyes, foam).
        bool[] bg = new bool[W * H];
        var q = new Queue<int>();
        Action<int> seed = i => { if (!bg[i] && minC(i) > thr) { bg[i] = true; q.Enqueue(i); } };
        for (int x = 0; x < W; x++) { seed(x); seed((H - 1) * W + x); }
        for (int y = 0; y < H; y++) { seed(y * W); seed(y * W + W - 1); }
        while (q.Count > 0)
        {
            int i = q.Dequeue(), x = i % W, y = i / W;
            if (x > 0) seed(i - 1); if (x < W - 1) seed(i + 1);
            if (y > 0) seed(i - W); if (y < H - 1) seed(i + W);
        }

        // 2) Enclosed pockets of pure paper white (e.g. the gap between an arm and the body) are
        //    background too. Cream gloves/foam have a warmer (lower blue) tint, so they survive.
        bool[] seen = new bool[W * H];
        for (int s = 0; s < W * H; s++)
        {
            if (bg[s] || seen[s] || minC(s) <= thr) continue;
            var region = new List<int>(); int pure = 0;
            q.Enqueue(s); seen[s] = true;
            while (q.Count > 0)
            {
                int i = q.Dequeue(), x = i % W, y = i / W; region.Add(i);
                if (minC(i) >= 248) pure++;
                int[] nb = { x > 0 ? i - 1 : -1, x < W - 1 ? i + 1 : -1, y > 0 ? i - W : -1, y < H - 1 ? i + W : -1 };
                foreach (int n in nb) if (n >= 0 && !seen[n] && !bg[n] && minC(n) > thr) { seen[n] = true; q.Enqueue(n); }
            }
            if (region.Count > 150 && pure > region.Count * 0.85) foreach (int i in region) bg[i] = true;
        }

        // 3) Alpha + defringe: pixels touching the background that are light grey are
        //    anti-aliased ink, so turn them into semi-transparent ink instead of a white halo.
        byte[] outPx = (byte[])px.Clone();
        for (int i = 0; i < W * H; i++)
        {
            if (bg[i]) { outPx[i * 4 + 3] = 0; continue; }
            int x = i % W, y = i / W; bool edge = false;
            for (int dy = -2; dy <= 2 && !edge; dy++) for (int dx = -2; dx <= 2; dx++)
            {
                int nx = x + dx, ny = y + dy;
                if (nx >= 0 && nx < W && ny >= 0 && ny < H && bg[ny * W + nx]) { edge = true; break; }
            }
            if (!edge) continue;
            int lum = (px[i * 4] + px[i * 4 + 1] + px[i * 4 + 2]) / 3;
            if (lum > 110)
            {
                int a = (int)Math.Round((255 - lum) * 255.0 / (255 - 25));
                outPx[i * 4] = outPx[i * 4 + 1] = outPx[i * 4 + 2] = 25;
                outPx[i * 4 + 3] = (byte)Math.Max(0, Math.Min(255, a));
            }
        }

        // 4) Connected components of visible pixels.
        int[] lab = new int[W * H]; for (int i = 0; i < lab.Length; i++) lab[i] = -1;
        var comps = new List<Comp>();
        for (int s = 0; s < W * H; s++)
        {
            if (outPx[s * 4 + 3] < 40 || lab[s] >= 0) continue;
            var c = new Comp { MinX = int.MaxValue, MinY = int.MaxValue, MaxX = -1, MaxY = -1 };
            int id = comps.Count; comps.Add(c);
            q.Enqueue(s); lab[s] = id;
            while (q.Count > 0)
            {
                int i = q.Dequeue(), x = i % W, y = i / W;
                c.Area++; c.Px.Add(i);
                if (x < c.MinX) c.MinX = x; if (x > c.MaxX) c.MaxX = x;
                if (y < c.MinY) c.MinY = y; if (y > c.MaxY) c.MaxY = y;
                for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++)
                {
                    int nx = x + dx, ny = y + dy;
                    if (nx < 0 || nx >= W || ny < 0 || ny >= H) continue;
                    int n = ny * W + nx;
                    if (lab[n] < 0 && outPx[n * 4 + 3] >= 40) { lab[n] = id; q.Enqueue(n); }
                }
            }
        }

        // 5) Per grid cell: the biggest blob is the character; attach nearby decorations
        //    (stars, splashes, sweat) but drop thin speed-lines and far-away bits.
        int cw = W / cols, ch = H / rows;
        var owner = new int[comps.Count];
        var mains = new int[cols * rows];
        for (int k = 0; k < mains.Length; k++) mains[k] = -1;
        for (int ci = 0; ci < comps.Count; ci++)
        {
            var c = comps[ci];
            int cx = Math.Min(cols - 1, ((c.MinX + c.MaxX) / 2) / cw), cy = Math.Min(rows - 1, ((c.MinY + c.MaxY) / 2) / ch);
            int cell = cy * cols + cx;
            if (mains[cell] < 0 || comps[mains[cell]].Area < c.Area) mains[cell] = ci;
        }
        for (int ci = 0; ci < comps.Count; ci++)
        {
            owner[ci] = -1;
            var c = comps[ci];
            int w = c.MaxX - c.MinX + 1, h = c.MaxY - c.MinY + 1;
            if (Array.IndexOf(mains, ci) >= 0) { owner[ci] = Array.IndexOf(mains, ci); continue; }
            if (c.Area < 25) continue;
            if (h <= 14 && w >= 3 * h) continue;                 // speed lines
            double best = double.MaxValue; int bestCell = -1;
            for (int k = 0; k < mains.Length; k++)
            {
                if (mains[k] < 0) continue;
                var m = comps[mains[k]];
                double dx = Math.Max(0, Math.Max(m.MinX - c.MaxX, c.MinX - m.MaxX));
                double dy = Math.Max(0, Math.Max(m.MinY - c.MaxY, c.MinY - m.MaxY));
                double d = Math.Sqrt(dx * dx + dy * dy);
                if (d < best) { best = d; bestCell = k; }
            }
            if (best <= 70) owner[ci] = bestCell;
        }

        for (int k = 0; k < mains.Length && k < names.Length; k++)
        {
            if (mains[k] < 0) { log.AppendLine("no character in cell " + k); continue; }
            int x0 = int.MaxValue, y0 = int.MaxValue, x1 = -1, y1 = -1;
            for (int ci = 0; ci < comps.Count; ci++) if (owner[ci] == k)
            {
                var c = comps[ci];
                x0 = Math.Min(x0, c.MinX); y0 = Math.Min(y0, c.MinY); x1 = Math.Max(x1, c.MaxX); y1 = Math.Max(y1, c.MaxY);
            }
            int cwid = x1 - x0 + 1 + pad * 2, chei = y1 - y0 + 1 + pad * 2;
            var crop = new Bitmap(cwid, chei, PixelFormat.Format32bppArgb);
            var cd = crop.LockBits(new Rectangle(0, 0, cwid, chei), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            byte[] cp = new byte[cwid * chei * 4];
            // copy every pixel inside the box that belongs to a kept component or is faint fringe next to one
            for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++)
            {
                int i = y * W + x; int l = lab[i];
                bool keep = l >= 0 ? owner[l] == k : outPx[i * 4 + 3] > 0;
                if (!keep) continue;
                int o = ((y - y0 + pad) * cwid + (x - x0 + pad)) * 4;
                cp[o] = outPx[i * 4]; cp[o + 1] = outPx[i * 4 + 1]; cp[o + 2] = outPx[i * 4 + 2]; cp[o + 3] = outPx[i * 4 + 3];
            }
            Marshal.Copy(cp, 0, cd.Scan0, cp.Length); crop.UnlockBits(cd);

            int nh = targetH, nw = (int)Math.Round(cwid * (double)targetH / chei);
            var outBmp = new Bitmap(nw, nh, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(outBmp))
            {
                g.CompositingMode = CompositingMode.SourceCopy;
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                using (var ia = new ImageAttributes()) { ia.SetWrapMode(WrapMode.TileFlipXY);
                    g.DrawImage(crop, new Rectangle(0, 0, nw, nh), 0, 0, cwid, chei, GraphicsUnit.Pixel, ia); }
            }
            string path = System.IO.Path.Combine(outDir, names[k] + ".png");
            outBmp.Save(path, ImageFormat.Png);
            log.AppendLine(string.Format("{0}: box {1},{2} {3}x{4} -> {5}x{6}", names[k], x0, y0, x1 - x0 + 1, y1 - y0 + 1, nw, nh));
            crop.Dispose(); outBmp.Dispose();
        }
        return log.ToString();
    }
}
'@

$out = Join-Path $root 'assets\sprites'
New-Item -ItemType Directory -Force $out | Out-Null

[Slicer]::Process((Join-Path $root 'raw_art\char1_sheet.png'), 2, 2,
    @('char1_run_left', 'char1_run_right', 'char1_chug', 'char1_dizzy'),
    $out, $TargetHeight, $Pad, $BgThreshold)

# Sheet 2 is 4 columns x 2 rows: columns 0-1 are char2, columns 2-3 are char3.
[Slicer]::Process((Join-Path $root 'raw_art\char2_3_sheet.png'), 4, 2,
    @('char2_run_left', 'char2_run_right', 'char3_run_left', 'char3_run_right',
      'char2_idle', 'char2_cheer', 'char3_idle', 'char3_cheer'),
    $out, $TargetHeight, $Pad, $BgThreshold)
