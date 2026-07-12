#!/bin/bash
set -e

# Generate AppIcon.icns from logo.svg
# IMPORTANT: The output icon MUST have a transparent background outside the rounded rect.
# If you see a white square behind the icon, the conversion tool added an opaque background — redo it.

SVG_FILE="${1:-logo.svg}"
OUTPUT_ICNS="NetBar/NetBar.app/Contents/Resources/AppIcon.icns"
ICONSET_DIR="/tmp/NetBar.iconset"

if [ ! -f "$SVG_FILE" ]; then
    echo "Error: $SVG_FILE not found"
    exit 1
fi

echo "Generating icon from $SVG_FILE..."

# Step 1: Convert SVG to 1024x1024 PNG
# Using qlmanage (built into macOS) — renders with transparency
mkdir -p /tmp/icon-gen
qlmanage -t -s 1024 -o /tmp/icon-gen "$SVG_FILE" 2>/dev/null
# qlmanage appends .png to the filename
SVG_BASE=$(basename "$SVG_FILE" .svg)
PNG_1024="/tmp/icon-gen/${SVG_BASE}.png.png"
if [ ! -f "$PNG_1024" ]; then
    PNG_1024="/tmp/icon-gen/${SVG_BASE}.png"
fi

if [ ! -f "$PNG_1024" ]; then
    echo "Error: Failed to render SVG. Try one of:"
    echo "  1. Open logo.svg in Safari, right-click > Export As PNG at 1024x1024"
    echo "  2. Use https://svg2png.com to convert, ensuring transparent background"
    echo "  3. Open in Figma/Inkscape and export as PNG with transparency"
    exit 1
fi

# Step 2: Verify transparency (check corner pixel)
python3 -c "
import struct, zlib
def check_transparency(path):
    with open(path, 'rb') as f:
        sig = f.read(8)
        chunks = []
        while True:
            raw = f.read(8)
            if len(raw) < 8: break
            length = struct.unpack('>I', raw[:4])[0]
            ctype = raw[4:8]
            data = f.read(length)
            f.read(4)
            chunks.append((ctype, data))
        ihdr = chunks[0][1]
        w, h = struct.unpack('>II', ihdr[:8])
        idat_data = b''
        for ct, data in chunks:
            if ct == b'IDAT': idat_data += data
        decompressed = zlib.decompress(idat_data)
        stride = 1 + 4 * w
        for (x, y, label) in [(0,0,'top-left'), (w-1,0,'top-right'), (0,h-1,'bottom-left'), (w-1,h-1,'bottom-right')]:
            row = decompressed[y * stride : (y+1) * stride]
            r, g, b, a = struct.unpack('BBBB', row[1+x*4:5+x*4])
            if a > 0:
                print(f'WARNING: {label} pixel is opaque (alpha={a}). Icon will have white corners!')
                print('Use a tool that preserves transparency (Figma, Safari export, svg2png.com)')
                return False
    print('Transparency verified: all corners are transparent.')
    return True
check_transparency('$PNG_1024')
"

# Step 3: Generate all required sizes for .iconset
mkdir -p "$ICONSET_DIR"
for size in 16 32 64 128 256 512; do
    sips -z $size $size "$PNG_1024" --out "$ICONSET_DIR/icon_${size}x${size}.png" 2>/dev/null
    double=$((size * 2))
    if [ $double -le 1024 ]; then
        sips -z $double $double "$PNG_1024" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" 2>/dev/null
    fi
done
# 1024x1024 is the 512@2x
cp "$PNG_1024" "$ICONSET_DIR/icon_512x512@2x.png"

# Step 4: Build .icns
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

# Cleanup
rm -rf "$ICONSET_DIR" /tmp/icon-gen

echo "Done: $OUTPUT_ICNS"
echo "Run 'open NetBar/NetBar.app' to verify the icon in your menu bar."
