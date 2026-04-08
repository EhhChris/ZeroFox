> **Note:** This project and its scaffolding were built with AI assistance (Claude, Anthropic).

# ZeroFox Branding

To use custom branding (app name, icons, colors), you need to create a branding directory
inside the Firefox source tree before building.

## Setup

1. Copy Firefox's nightly branding as a starting point:
   ```
   cp -r <firefox-src>/browser/branding/nightly <firefox-src>/browser/branding/zerofox
   ```

2. Replace assets in `<firefox-src>/browser/branding/zerofox/`:
   - `default16.png`, `default32.png`, `default48.png`, `default64.png`, `default128.png` — app icon sizes
   - `default256.png` — high-res icon (Linux)
   - `firefox.icns` (macOS) / `firefox.ico` (Windows) — platform icon bundles
   - `aboutDialog.css` — colors for the About dialog
   - `branding.nsi` — Windows installer branding strings

3. Edit `<firefox-src>/browser/branding/zerofox/locales/en-US/brand.dtd`:
   ```xml
   <!ENTITY brandShortName "ZeroFox">
   <!ENTITY brandFullName "ZeroFox">
   <!ENTITY vendorShortName "ZeroFox">
   ```

4. Edit `<firefox-src>/browser/branding/zerofox/locales/en-US/brand.properties`:
   ```
   brandShortName=ZeroFox
   brandFullName=ZeroFox
   ```

5. Uncomment the branding line in `config/mozconfig`:
   ```
   ac_add_options --with-branding=browser/branding/zerofox
   ```

## Icon dimensions required

| File | Size |
|------|------|
| default16.png | 16×16 |
| default32.png | 32×32 |
| default48.png | 48×48 |
| default64.png | 64×64 |
| default128.png | 128×128 |
| default256.png | 256×256 |
| firefox.icns | Multi-resolution ICNS (macOS) |
| firefox.ico | Multi-resolution ICO (Windows) |

To generate an ICNS from a 1024×1024 PNG on macOS:
```bash
mkdir ZeroFox.iconset
sips -z 16 16   icon1024.png --out ZeroFox.iconset/icon_16x16.png
sips -z 32 32   icon1024.png --out ZeroFox.iconset/icon_16x16@2x.png
sips -z 32 32   icon1024.png --out ZeroFox.iconset/icon_32x32.png
sips -z 64 64   icon1024.png --out ZeroFox.iconset/icon_32x32@2x.png
sips -z 128 128 icon1024.png --out ZeroFox.iconset/icon_128x128.png
sips -z 256 256 icon1024.png --out ZeroFox.iconset/icon_128x128@2x.png
sips -z 256 256 icon1024.png --out ZeroFox.iconset/icon_256x256.png
sips -z 512 512 icon1024.png --out ZeroFox.iconset/icon_256x256@2x.png
cp icon1024.png ZeroFox.iconset/icon_512x512@2x.png
iconutil -c icns ZeroFox.iconset
```
