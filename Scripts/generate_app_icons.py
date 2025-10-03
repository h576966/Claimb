#!/usr/bin/env python3
"""
App Icon Generator for Claimb
Generates all required iOS app icon sizes from a source 1024x1024 image
"""

import os
import sys
from PIL import Image, ImageOps
import argparse

def generate_app_icons(source_path, output_dir="Assets.xcassets/AppIcon.appiconset"):
    """Generate all required iOS app icon sizes from source image"""
    
    # Required sizes for iOS app icons
    sizes = {
        "20@2x.png": 40,
        "20@3x.png": 60,
        "29@2x.png": 58,
        "29@3x.png": 87,
        "40@2x.png": 80,
        "40@3x.png": 120,
        "60@2x.png": 120,
        "60@3x.png": 180,
        "1024.png": 1024
    }
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    try:
        # Open source image
        with Image.open(source_path) as source:
            print(f"Source image: {source.size} pixels, mode: {source.mode}")
            
            # Convert to RGB if necessary (remove alpha channel)
            if source.mode in ('RGBA', 'LA', 'P'):
                # Create black background for better contrast
                background = Image.new('RGB', source.size, (0, 0, 0))
                if source.mode == 'P':
                    source = source.convert('RGBA')
                background.paste(source, mask=source.split()[-1] if source.mode == 'RGBA' else None)
                source = background
            elif source.mode != 'RGB':
                source = source.convert('RGB')
            
            # Generate each size
            for filename, size in sizes.items():
                print(f"Generating {filename} ({size}x{size})...")
                
                # Resize with high-quality resampling
                resized = source.resize((size, size), Image.Resampling.LANCZOS)
                
                # Save as PNG
                output_path = os.path.join(output_dir, filename)
                resized.save(output_path, 'PNG', optimize=True)
                
                print(f"  ✓ Saved to {output_path}")
            
            print(f"\n✅ Successfully generated {len(sizes)} app icon sizes!")
            print(f"📁 Output directory: {output_dir}")
            
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Generate iOS app icons from source image')
    parser.add_argument('source', help='Path to source 1024x1024 image')
    parser.add_argument('--output', '-o', default='Assets.xcassets/AppIcon.appiconset', 
                       help='Output directory (default: Assets.xcassets/AppIcon.appiconset)')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.source):
        print(f"❌ Source file not found: {args.source}")
        sys.exit(1)
    
    generate_app_icons(args.source, args.output)

if __name__ == "__main__":
    main()
