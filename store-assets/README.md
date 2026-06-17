# Bottle of Colors — Play Store assets

All artifacts the Google Play Console will ask for, in one place.

## Identity

| Field | Value |
|---|---|
| App name | **Bottle of Colors** |
| Package name (applicationId) | **`uk.sadeq.bottleofcolors`** |
| Domain backing the package | sadeq.uk (reverse-DNS) |

The package name is what locks an app to your developer account on Google
Play forever — once published it cannot be changed. Make sure this is the
final form you want before the first release.

## Files in this folder

| Spec | File | Size |
|---|---|---|
| App icon (1024) | `../android/assets/icon/icon.png` | 1024×1024 PNG |
| App icon (512, Play Console field) | `icon-512.png` | 512×512 PNG |
| Source SVG for both icons | `../android/assets/icon/icon.svg` | vector |
| Feature graphic | `feature-graphic.png` | 1024×500 PNG |
| Feature graphic source | `feature-graphic.svg` | vector |
| Short description (80 char limit) | `short-description.txt` | 77 chars |
| Full description (4000 char limit) | `full-description.txt` | 2838 chars |
| Phone screenshots | `screenshots/01..07-*.png` | 1080×2400, see below |

### Screenshot inventory

Recommended upload order (the first one shows up in carousels):

| # | File | What it shows |
|---|---|---|
| 1 | `screenshots/02-home.png` | Home screen with player name and the big "Play · Level N" CTA |
| 2 | `screenshots/06-level-11.png` | A 6-bottle puzzle mid-difficulty (best gameplay shot) |
| 3 | `screenshots/04-selection.png` | Bottle selected for pouring (amber highlight + lift) |
| 4 | `screenshots/05-levels.png` | Levels grid with the next-level pill highlighted |
| 5 | `screenshots/07-custom.png` | Custom-puzzle screen with bottles/slots/empties dials |
| 6 | `screenshots/03-level-1.png` | Level 1, the gentle starting point |
| 7 | `screenshots/01-player-picker.png` | "Who is playing?" — multi-player support |

Google Play accepts 2–8 phone screenshots, JPEG or 24-bit PNG, between
320 px and 3840 px on the long side. These are 1080×2400, well inside
the range.

## Building the release artifact (.aab)

Play Store needs a signed `.aab`, not the debug `.apk` we've been
installing. One-time setup:

```bash
# 1. Generate a release keystore (KEEP THIS FILE SAFE — losing it means you
#    can never publish an update under this package name again).
keytool -genkey -v -keystore ~/upload-keystore.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# 2. Create android/key.properties (NOT checked into git):
cat > android/key.properties <<EOF
storePassword=<your store password>
keyPassword=<your key password>
keyAlias=upload
storeFile=/Users/sadeq.yazdi/upload-keystore.jks
EOF

# 3. Wire signingConfig into android/app/build.gradle.kts. See
#    https://docs.flutter.dev/deployment/android#signing-the-app

# 4. Build the bundle
cd android && flutter build appbundle --release
# Output: android/build/app/outputs/bundle/release/app-release.aab
```

Upload `app-release.aab` to the Play Console under **Production → Create
new release**.

## Play Console fields cheat-sheet

| Console field | Where to find it |
|---|---|
| App name | "Bottle of Colors" |
| Short description | `short-description.txt` |
| Full description | `full-description.txt` |
| App icon | `icon-512.png` |
| Feature graphic | `feature-graphic.png` |
| Phone screenshots | `screenshots/*.png` (upload 2–8 in the order above) |
| App category | Games → Puzzle |
| Tags | puzzle, casual, brain-teaser, sort, color |
| Content rating | Everyone (no violence, no IAP, no ads) |
| Target audience | 6+ |
| Data safety | App doesn't collect or share any data |
| Privacy policy URL | (required if you target 13- or use ads — currently we don't, so skip) |
| Contact email | your email |
| Website | https://sadeq.uk (or per-app subpage) |
