#!/usr/bin/env python3
"""
Generate all required app icon sizes from a single source PNG.

Usage:
    python3 gen-app-icon.py path/to/source-icon.png

Generates:
    - iOS app icons (all required sizes)
    - SideStore feed icon (icon-1024.png in source/worker/)

Requirements:
    pip install Pillow
"""

import sys
import os
from pathlib import Path
from PIL import Image

# iOS app icon sizes (all @1x, @2x, @3x are handled)
IOS_SIZES = [
    20, 29, 40, 60,  # iPhone
    76, 83.5,         # iPad
    1024              # App Store
]

def generate_icons(source_path):
    """Generate all icon sizes from source image."""
    
    if not os.path.exists(source_path):
        print(f"❌ Error: Source image not found: {source_path}")
        sys.exit(1)
    
    # Open and validate source image
    try:
        img = Image.open(source_path)
    except Exception as e:
        print(f"❌ Error opening image: {e}")
        sys.exit(1)
    
    # Validate it's square
    if img.width != img.height:
        print(f"❌ Error: Source image must be square (got {img.width}x{img.height})")
        sys.exit(1)
    
    # Validate minimum size
    if img.width < 1024:
        print(f"⚠️  Warning: Source image is {img.width}px, recommended 1024px or higher")
    
    print(f"✅ Source image: {img.width}x{img.height} px")
    
    # Determine output directory (assume script is in repo root or scripts/)
    script_dir = Path(__file__).parent
    if script_dir.name == "scripts":
        repo_root = script_dir.parent
    else:
        repo_root = script_dir
    
    # iOS app icons go to AYS2-tvOS/Assets.xcassets/AppIcon.appiconset/
    ios_icon_dir = repo_root / "AYS2-tvOS" / "Assets.xcassets" / "AppIcon.appiconset"
    
    # SideStore feed icon goes to source/worker/
    feed_icon_dir = repo_root / "source" / "worker"
    
    if not ios_icon_dir.exists():
        print(f"⚠️  iOS icon directory not found: {ios_icon_dir}")
        print(f"   Skipping iOS icons (run this from AYS2 repo root)")
        ios_icon_dir = None
    
    if not feed_icon_dir.exists():
        print(f"⚠️  Feed icon directory not found: {feed_icon_dir}")
        print(f"   Skipping SideStore feed icon")
        feed_icon_dir = None
    
    generated = 0
    
    # Generate iOS app icons
    if ios_icon_dir:
        print(f"\n📱 Generating iOS app icons...")
        for base_size in IOS_SIZES:
            for scale in [1, 2, 3]:
                size = int(base_size * scale)
                output_name = f"icon-{base_size}@{scale}x.png" if scale > 1 else f"icon-{base_size}.png"
                output_path = ios_icon_dir / output_name
                
                # Resize with high-quality Lanczos resampling
                resized = img.resize((size, size), Image.Resampling.LANCZOS)
                resized.save(output_path, "PNG", optimize=True)
                
                print(f"   ✓ {output_name} ({size}x{size})")
                generated += 1
    
    # Generate SideStore feed icon (always 1024x1024)
    if feed_icon_dir:
        print(f"\n📦 Generating SideStore feed icon...")
        feed_icon_path = feed_icon_dir / "icon-1024.png"
        feed_icon = img.resize((1024, 1024), Image.Resampling.LANCZOS)
        feed_icon.save(feed_icon_path, "PNG", optimize=True)
        print(f"   ✓ icon-1024.png (1024x1024)")
        generated += 1
    
    print(f"\n✅ Generated {generated} icon files")
    print(f"\nNext steps:")
    print(f"   1. Commit the generated icons")
    print(f"   2. Push to trigger a new build")
    print(f"   3. The new icon will appear in the next release")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 gen-app-icon.py path/to/source-icon.png")
        print("\nSource image requirements:")
        print("   - Square (1:1 aspect ratio)")
        print("   - PNG format")
        print("   - Minimum 1024x1024 px (higher is better)")
        print("   - No transparency (solid background)")
        sys.exit(1)
    
    generate_icons(sys.argv[1])
