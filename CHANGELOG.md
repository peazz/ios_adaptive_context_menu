## 0.1.5

- Added Flutter `IconData` support for fallback menu icons.
- Added Flutter popup fallback behavior for web and desktop instead of returning the child unchanged.
- Removed the Android fallback requirement that every action provide an SVG `iconAssetPath`.

## 0.1.4

- Added README notes explaining the temporary native anchor approach that avoids persistent UIKit embedding issues in Flutter layouts.
- Refined release metadata and screenshots for clearer pub.dev package presentation.

## 0.1.1

- Fixed iOS ghost-tap issue where a disposed tab could still open the context menu.
- Improved native anchor cleanup on widget dispose for more reliable tab/view switching.
- Updated package documentation and screenshots.

## 0.1.0

- Initial release.
- iOS single-tap native context menu support.
