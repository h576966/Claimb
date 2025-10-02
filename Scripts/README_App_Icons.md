# App Icon Generator for Claimb

This script generates all required iOS app icon sizes from a single source image.

## Requirements

- Python 3.6+
- Pillow (PIL) library
- Source image: 1024x1024 pixels, PNG format

## Installation

```bash
pip install Pillow
```

## Usage

### Basic Usage
```bash
python3 Scripts/generate_app_icons.py path/to/your/source/1024x1024.png
```

### With Custom Output Directory
```bash
python3 Scripts/generate_app_icons.py path/to/your/source/1024x1024.png --output Assets.xcassets/AppIcon.appiconset
```

## What It Does

1. **Opens your source image** (1024x1024)
2. **Removes transparency** (converts to RGB with white background)
3. **Generates all required sizes**:
   - 20@2x.png (40x40)
   - 20@3x.png (60x60)
   - 29@2x.png (58x58)
   - 29@3x.png (87x87)
   - 40@2x.png (80x80)
   - 40@3x.png (120x120)
   - 60@2x.png (120x120)
   - 60@3x.png (180x180)
   - 1024.png (1024x1024)
4. **Saves to Assets.xcassets/AppIcon.appiconset/**

## Tips for Best Results

1. **Start with high-quality source** - 1024x1024 or larger
2. **Use vector graphics** if possible (export as PNG)
3. **Ensure sharp edges** - avoid blurry source images
4. **Test on device** - check how icons look on actual iPhone

## Troubleshooting

- **"Source file not found"** - Check the path to your image
- **"PIL not found"** - Install Pillow: `pip install Pillow`
- **Blurry results** - Use a higher quality source image
