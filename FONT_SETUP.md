# Font Setup Instructions

## Steps to complete the BYekan font setup:

1. **Add Font Files**: Copy your font files to the assets folder:
   ```
   assets/fonts/BYekan.ttf
   assets/fonts/BYekanBold.ttf
   ```

2. **Run Flutter Commands**:
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Hot Restart**: Restart your app completely (not just hot reload) to see the font changes.

## What has been configured:

✅ **pubspec.yaml**: Added BYekan font family configuration
✅ **App Theme**: Created comprehensive theme with BYekan font
✅ **Main App**: Updated to use the new theme
✅ **All Screens**: Updated text styles to use BYekan font
✅ **PDF Export**: Excluded from font changes (as requested)

## Font Usage:
- **Regular text**: Uses BYekan.ttf
- **Bold text**: Uses BYekanBold.ttf (weight: 700)
- **All UI elements**: Buttons, cards, lists, dialogs, etc.

The font will be applied throughout the entire app except for PDF exports.
