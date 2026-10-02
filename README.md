# QR Master — Tarayıcı & Oluşturucu (Godot 4 · Android · Tek APK)

**Silvia Games** için tam kapsamlı, yayınlamaya hazır QR uygulaması. Godot 4.7 ile
yazılmış tek kod tabanı, tek Android çıktısı: **tek APK** (`build/qrmaster.apk`).

- 4 sekme: **Tara · Oluştur · Geçmiş · Ayarlar**
- Kamera taraması CameraX + ML Kit ile **cihaz üzerinde, çevrimdışı** (15+ barkod biçimi)
- QR üretimi **saf GDScript** ile: sürüm 1–40, L/M/Q/H hata düzeltme, 6 renk paleti
- **URL güvenlik önizlemesi** (açmadan önce hedef adres + risk uyarıları)
- Geçmiş: arama, filtreler, favoriler, **CSV dışa aktarma**, tek tek/Toplu silme
- AdMob (banner + ara reklam) — varsayılan **Google test birimleri**, geçiş README > AdMob
- Tüm veriler cihazda; hesap, sunucu, izleme yok

---

## 1 · Rakip araştırması ve özellik eşlemesi

2026 itibarıyla Google Play'in öne çıkan QR uygulamaları incelendi
(Gamma Play QR & Barcode Scanner ~500M indirme / 4.8★, TeaCapps QR Code Reader,
QR SCAN Team, Simple Design Scanner, Binary Eye, TrendMicro Safe QR, NeoReader).
Ortak beklentiler ve bu projedeki karşılığı:

| Rakip feature (kategori lideri) | QR Master'da var mı? |
| --- | --- |
| Hızlı kamera tarama, çoklu format (Gamma Play) | ✅ CameraX + ML Kit, QR öncelikli, 15+ format |
| Aranabilir tarama geçmişi (Gamma Play) | ✅ Yerel geçmiş + anlık arama |
| **CSV dışa aktarma** (TeaCapps) | ✅ Geçmiş > CSV Dışa Aktar → paylaşım menüsü |
| **Sürekli/toplu tarama + auto-redirect anahtarı** (QR SCAN Team) | ✅ Sürekli tarama aç/kapa, otomatik açma ayarı |
| Fener + galeriden kod okuma (Simple Design) | ✅ Fener düğmesi, Galeriden Kod Seç |
| Pinch/zoom beklentisi | ⚠️ v1'de yok; nişangah + otomatik odak ile telafi (v1.1 planlı) |
| **URL önizlemesi / quishing koruması** (TrendMicro — tek rakip) | ✅ Hedef adres + riskli bağlantı uyarıları, "Yine de Aç" ikinci onay |
| Çevrimdışı, izleme yok (Binary Eye) | ✅ Tarama/üretim tamamen çevrimdışı; hesap yok |
| QR üretme (tüm üreticiler) | ✅ 9 tür: Bağlantı, Metin, Wi‑Fi, Kişi, Telefon, SMS, E‑posta, Konum, Etkinlik |
| Barkod format genişliği (NeoReader) | ✅ ML Kit: QR, Aztec, DataMatrix, PDF417, Code39/93/128, EAN, UPC… |
| Reklamla desteklenen ücretsiz model (Gamma Play) | ✅ AdMob banner + ara reklam (test ID'leri ile hazır) |
| Bildirim/otomatik açma güvenliği (rakiplerin çoğu anında açar) | ✅ Varsayılan: önizleme açık, otomatik kapalı |

Eksik/bilinçli sınırlar: dinamik (sunucu tabanlı) QR analitiği, hesap senkronu ve
kısa bağlantı servisi yok — bilerek yerel ve gizli tutuldu.

---

## 2 · Proje yapısı

```
project.godot                 # Godot 4.7 projesi (autoload: Store, Native)
main.tscn / src/app.gd        # kabuk: sekmeler, tema, modal, tarama akışı
src/qr/qr_gen.gd              # QR encoder (Nayuki qrcodegen portu, MIT)
src/qr/payload.gd             # tür sınıflandırma + yük üreticileri + URL risk analizi
src/screens/*.gd              # Tara / Oluştur / Geçmiş / Ayarlar
src/ui/                       # tema (AppTheme) + widget yardımcıları (W)
src/store.gd, src/native.gd   # ayarlar+geçmiş / Android köprüsü
addons/sv_qr_scanner/         # Godot eklentisi: export_plugin.gd + bin/*.aar
android/sv-qr-scanner/        # AAR kaynağı (Gradle + Kotlin: CameraX, ML Kit, AdMob)
scripts/build_plugin.sh       # AAR derleyip addons altına kopyalar
export_presets.cfg            # Android preset: tek APK, com.silviagames.qrmaster
qrmaster/privacy.html         # Play Console için gizlilik sayfası
tests/                        # headless doğrulama (smoke + API probe)
```

---

## 3 · APK üretmek (tek çıktı)

Gereksinimler: **Godot 4.7.x**, **JDK 17**, **Android SDK** (platform 36),
**Gradle 8.14+** (veya Android Studio).

1. **Eklentiyi derle** (AAR — repo içinde hazır gelirse adımı atlayın):
   ```sh
   sh scripts/build_plugin.sh
   ```
   Çıktı: `addons/sv_qr_scanner/bin/{debug,release}/sv_qr_scanner-*.aar`
   > Bu depo AAR ile birlikte gelir; Godot yalnızca eklenti etkinken (Proje >
   > Eklentiler) ve AAR mevcutken tarama özelliğiyle dışa aktarır.

2. **Android build template'i kur**: Godot'da *Proje > Android Build Template'i Kur…*
   (`android/build/` oluşur).

3. **SDK ve keystore ayarla**: *Düzenleyici > Ayarlar > Export > Android*
   - Android SDK Path: SDK kökünüz
   - Debug Keystore: ilk açılışta otomatik üretilir

4. **Dışa aktar**: *Proje > Dışa Aktar… > Android* (preset hazır: **Android**)
   - Gradle Build: **Açık** (preset `use_gradle_build=true`)
   - Çıktı biçimi: **APK** (`export_format=0`)
   - Mimari: `arm64-v8a` + `armeabi-v7a` → **tek APK, iki mimari**
   - *Dışa Aktar* → `build/qrmaster.apk`

5. **Yayın imzası**: release keystore üretip Proje Ayarları'na girin:
   ```sh
   keytool -genkeypair -v -keystore qrmaster.keystore -alias qrmaster \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
   *Proje > Proje Ayarları > Export > Android* alanları:
   `Release Keystore / User / Password`. (`*.keystore` .gitignore'da.)

Sürüm yükseltirken `export_presets.cfg` içinde `version/code` (her yayında +1)
ve `version/name` değerlerini güncelleyin.

> **Doğrulama:** Bu depo baştan sona otomatik sınanmıştır — AAR derlemesi,
> `godot --headless --export-debug "Android"` ile Gradle inşası, manifest
> birleştirme ve **imzalı debug APK** üretimi (173 MB, arm64 + armeabi-v7a,
> paket `com.silviagames.qrmaster`) başarıyla tamamlanmıştır.

---

## 4 · AdMob'ı kendi hesabınıza alın

Depo **test kimlikleriyle** gelir (çalışır, gelir üretmez). Üç adım:

1. `addons/sv_qr_scanner/export_plugin.gd` → `_get_android_manifest_application_element_contents`
   içindeki `ca-app-pub-3940256099942544~3347511713` değerini **AdMob uygulama ID'nizle**
   değiştirin (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`).
2. `src/native.gd` içindeki `TEST_BANNER` ve `TEST_INTERSTITIAL` sabitlerini
   **reklam birimi ID'lerinizle** (`ca-app-pub-…/…`) değiştirin.
3. Uygulamanızın sitesinde `app-ads.txt` yayınlayın (bu depoda kök dizinde mevcut ✓).

Ara reklam sıklığı: `src/store.gd` → `interstitial_every` (varsayılan: her 3 tarama oturumu).

---

## 5 · Play Console kontrol listesi

- [ ] Paket: `com.silviagames.qrmaster` (preset ile aynı)
- [ ] Sürüm kodu `version/code` > mevcut en yüksek kod
- [ ] **Gizlilik politikası URL'si**: `qrmaster/privacy.html` dosyasını kendi
      alan adınızda yayınlayın (ör. `https://<siteniz>/qrmaster/privacy.html`) ve
      Ayarlar > Gizlilik URL alanına girin
- [ ] Hedef API: Godot 4.7 şablonu güncel Android'i hedefler; *Google Play > Hedef
      API gereksinimlerini* yayın öncesi kontrol edin
- [ ] Depolama: izin istemiyoruz (MediaStore) — "İzinler" formunda yalnızca
      KAMERA + VİBRATE işaretleyin
- [ ] İçerik derecelendirmesi anketi: QR aracı, reklam var → "Reklamlar" işaretleyin
- [ ] Uygulama mağazası görselleri: 512×512 ikon, 1024×500 özellik grafiği
      (`icon.svg`'den üretebilirsiniz), en az 2 ekran görüntüsü
- [ ] Test cihazında son kontrol: tarama, fener, galeri, CSV paylaşım, PNG kaydetme

---

## 6 · Testler

```sh
# Tüm UI akışı + QR referans karşılaştırması (43 kontrol)
godot --headless -s res://tests/smoke.gd

# API keşif betiği
godot --headless -s res://tests/probe.gd
```

`tests/smoke.gd` içindeki `QRCASE|…` satırları, Project Nayuki'nin resmi
`qrcodegen.py` referans uygulamasıyla **bit bit** (sha256) karşılaştırılır —
üretilen her QR kodu spec'e uygundur.

---

## 7 · Sorun giderme

| Belirti | Çözüm |
| --- | --- |
| `SvQrScanner: AAR bulunamadı` uyarısı | `sh scripts/build_plugin.sh` çalıştırın |
| Tarama düğmesi "Android derlemesinde çalışır" diyor | Editördesiniz; APK'da çalışır |
| Kamera açılmıyor | Cihaz ayarlarından KAMERA izni; ilk açılışta istenir |
| ML Kit "Play services" uyarısı | Önemsiz; `barcode-scanning` çevrimdışı model kullanır |
| Banner görünmüyor | AdMob test/gerçek ID'lerini §4'e göre girin, APK'yı yeniden derleyin |
| Dışa aktarım Gradle hatası | `android/build` şablonu kurulu mu + `ANDROID_HOME` tanımlı mı |
| `Gradle build daemon disappeared` / OOM | Şablon `gradle.properties` içinde `-Xmx4536m` verir; 8 GB altı RAM'de `android/build/gradle.properties` dosyasında bu değeri `-Xmx1536m` yapın (bu klasör gitignore'ludur) |
| `Android build version mismatch` | `android/.build_version` silin ve şablonu *Proje > Android Build Template* ile yeniden kurun |
| CameraX sürümü AGP hatası verirse | `export_plugin.gd` bilinçli olarak CameraX **1.5.3** (AGP 8.6 uyumlu) tutar — yükseltmeyin |
| Storage/bildirim izni uyarısı | Biz yalnızca KAMERA + VİBRATE istiyoruz; Play izin formunu buna göre doldurun |

---

## 8 · Lisanslar / atıflar

- QR kodlama algoritması: [Project Nayuki — QR Code generator](https://github.com/nayuki/QR-Code-generator) (MIT)
- Android: CameraX (Apache-2.0), Google ML Kit Barcode (Google'su), Google Mobile Ads SDK
