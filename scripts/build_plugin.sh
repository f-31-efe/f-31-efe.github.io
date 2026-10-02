#!/bin/sh
# SvQrScanner Android eklentisini derler ve AAR'ları Godot addons/ altına kopyalar.
# Kullanım:  sh scripts/build_plugin.sh
# Gereksinim: JDK 17 + Android SDK (ANDROID_HOME) + Gradle 8.14+ (veya Android Studio)
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJ="$ROOT/android/sv-qr-scanner"
cd "$PROJ"

echo "== SvQrScanner derleniyor (debug + release AAR) =="
if [ -f ./gradlew ]; then
    ./gradlew --no-daemon :plugin:assembleDebug :plugin:assembleRelease
elif command -v gradle >/dev/null 2>&1; then
    gradle --no-daemon :plugin:assembleDebug :plugin:assembleRelease
else
    echo "HATA: Gradle bulunamadı." >&2
    echo "  • Android Studio ile android/sv-qr-scanner klasörünü açın (Gradle indirir)," >&2
    echo "  • veya Gradle 8.14+ kurun: https://gradle.org/install/" >&2
    exit 1
fi

OUT="$PROJ/plugin/build/outputs/aar"
DEST="$ROOT/addons/sv_qr_scanner/bin"
mkdir -p "$DEST/debug" "$DEST/release"

if [ ! -f "$OUT/sv_qr_scanner-debug.aar" ] || [ ! -f "$OUT/sv_qr_scanner-release.aar" ]; then
    echo "HATA: Beklenen AAR çıktıları bulunamadı: $OUT" >&2
    exit 1
fi

cp "$OUT/sv_qr_scanner-debug.aar" "$DEST/debug/"
cp "$OUT/sv_qr_scanner-release.aar" "$DEST/release/"

echo ""
echo "OK — AAR'lar kopyalandı:"
echo "  addons/sv_qr_scanner/bin/debug/sv_qr_scanner-debug.aar"
echo "  addons/sv_qr_scanner/bin/release/sv_qr_scanner-release.aar"
echo ""
echo "Sonraki adım: Godot > Proje > Dışa Aktar > Android (Gradle Build açık) > Dışa Aktar"
