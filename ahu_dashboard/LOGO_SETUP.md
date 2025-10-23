# Logo Setup Instructions

## Step 1: Save the Logo Images

You need to save **2 complete logo images** to the following location:

```
ahu_dashboard/assets/images/
```

### Required Files:

Both images contain the **complete logo** (green badge + ALMED text), just with different text colors:

1. **logo_dark.png** - Complete logo with **DARK TEXT**
   - Used in **LIGHT MODE** (dark text shows well on light background)
   
2. **logo_light.png** - Complete logo with **LIGHT TEXT**
   - Used in **DARK MODE** (light text shows well on dark background)

### File Structure:

```
ahu_dashboard/
└── assets/
    └── images/
        ├── logo_dark.png     (Badge + ALMED with dark text)
        └── logo_light.png    (Badge + ALMED with light text)
```

### How to Save:

**Option 1: Using the file manager**
1. Right-click on each image and save them
2. Navigate to: `/home/almedproto/Documents/almed_ahu/ahu_dashboard/assets/images/`
3. Name them exactly as shown above:
   - Dark text version → `logo_dark.png`
   - Light text version → `logo_light.png`

**Option 2: Using terminal**
```bash
cd /home/almedproto/Documents/almed_ahu/ahu_dashboard/assets/images/

# If you have the images in your Downloads folder:
cp ~/Downloads/logo_with_dark_text.png ./logo_dark.png
cp ~/Downloads/logo_with_light_text.png ./logo_light.png
```

## Step 2: Verify the Setup

After saving the images, run:

```bash
cd /home/almedproto/Documents/almed_ahu/ahu_dashboard
flutter pub get
flutter run -d linux
```

## What's Been Updated:

1. ✅ Created `assets/images/` directory
2. ✅ Updated `pubspec.yaml` to include assets
3. ✅ Modified `login_screen.dart` to display logo with **theme awareness**:
   - Logo switches automatically based on theme
   - **Light Mode** → Dark text logo
   - **Dark Mode** → Light text logo
   - Max width 350px, maintains aspect ratio
   - Fallback displays if images are not found

## Theme-Aware Logo Switching:

The app intelligently switches between the two logo versions:

| Theme Mode | Background | Logo Used |
|------------|------------|-----------|
| Light Mode | White/Blue gradient | `logo_dark.png` (dark text) |
| Dark Mode | Black/Blue gradient | `logo_light.png` (light text) |

This ensures perfect contrast and readability in both themes!

## Fallback Behavior:

If the images are not found, the app will display:
- A blue icon with air symbol
- "ALMED" text styled according to theme

This ensures the app works even without the images.

## Logo Display:

The complete logo will appear at the top of the login page:
- Max width: 350px (maintains aspect ratio)
- Centered with proper spacing
- Smooth transitions when switching themes

## Testing Theme Switching:

1. Run the app: `flutter run -d linux`
2. Click the theme toggle button (sun/moon icon) in the top-right
3. Watch the logo automatically switch between dark and light versions!
