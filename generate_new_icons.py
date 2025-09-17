#!/usr/bin/env python3
"""
Generate iOS app icon sizes from a source image
"""

from PIL import Image
import os

def generate_icons():
    # Source image path (you'll need to provide this)
    source_path = "new_icon_source.png"  # You'll need to save your source image as this
    
    # Check if source exists
    if not os.path.exists(source_path):
        print(f"❌ Source image not found: {source_path}")
        print("Please save your source image as 'new_icon_source.png' in the current directory")
        return
    
    try:
        # Open the source image
        source = Image.open(source_path)
        print(f"✅ Loaded source image: {source.size}")
        
        # Define the required sizes for iOS app icons
        sizes = [
            (40, "20@2x.png"),      # 20pt @2x
            (60, "20@3x.png"),      # 20pt @3x
            (58, "29@2x.png"),      # 29pt @2x
            (87, "29@3x.png"),      # 29pt @3x
            (80, "40@2x.png"),      # 40pt @2x
            (120, "40@3x.png"),     # 40pt @3x
            (120, "60@2x.png"),     # 60pt @2x
            (180, "60@3x.png"),     # 60pt @3x
            (1024, "1024.png")      # App Store
        ]
        
        # Generate each size
        for size, filename in sizes:
            # Resize the image
            resized = source.resize((size, size), Image.Resampling.LANCZOS)
            
            # Save the resized image
            resized.save(filename)
            print(f"✅ Generated {filename} ({size}x{size})")
        
        print("\n🎉 All app icon sizes generated successfully!")
        print("The new icons are ready to replace the existing ones.")
        
    except Exception as e:
        print(f"❌ Error generating icons: {e}")

if __name__ == "__main__":
    generate_icons()
