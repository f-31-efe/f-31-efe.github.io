package com.silviagames.qrscanner

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.core.content.FileProvider
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * QR Master — Godot v2 Android eklentisi.
 *
 * GDScript'ten çağrılan yöntemler (@UsedByGodot):
 *  pollEvents(), startScan(), stopScan(), openUri(), shareText(), shareFile(),
 *  saveImageToGallery(), playBeep(), initAds(), showBanner(), hideBanner(),
 *  bannerHeightPx(), loadInterstitial(), showInterstitial()
 *
 * Kamera taraması [ScannerActivity] içinde CameraX + ML Kit ile yapılır;
 * olaylar [eventQueue] kuyruğuna yazılır ve GDScript tarayıcı tarafından periyodik
 * olarak pollEvents() ile çekilir (sinyal yerine polling — daha sağlam).
 */
class QrScannerPlugin(godot: Godot) : GodotPlugin(godot) {

    companion object {
        private const val TAG = "SvQrScanner"

        /** Godot kütüphanesinin FileProvider yetkisi: ${applicationId}.fileprovider */
        private fun fileProviderAuthority(pkg: String): String = "$pkg.fileprovider"

        private val eventQueue = ConcurrentLinkedQueue<String>()

        /** ScannerActivity ve eklenti tarafından çağrılır; iş parçacığı güvenlidir. */
        fun post(type: String, extra: JSONObject = JSONObject()) {
            try {
                val out = JSONObject()
                out.put("type", type)
                val keys = extra.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    out.put(k, extra.get(k))
                }
                eventQueue.add(out.toString())
            } catch (e: Exception) {
                Log.w(TAG, "olay gönderilemedi: $e")
            }
        }

        private val mainHandler = Handler(Looper.getMainLooper())

        @Volatile private var interstitialAd: InterstitialAd? = null
        @Volatile private var bannerAd: AdView? = null
        @Volatile private var adsReady = false
        @Volatile private var bannerUnitId = ""
        @Volatile private var interstitialUnitId = ""
    }

    override fun getPluginName(): String = "SvQrScanner"

    // ------------------------------------------------------------------ olaylar

    /** Kuyrukta biriken olay JSON'larını (dizi olarak) boşaltır. */
    @UsedByGodot
    fun pollEvents(): String {
        val arr = JSONArray()
        while (true) {
            val e = eventQueue.poll() ?: break
            arr.put(JSONObject(e))
        }
        return arr.toString()
    }

    // ------------------------------------------------------------------ tarama

    @UsedByGodot
    fun startScan(optionsJson: String) {
        val act: Activity = activity ?: return
        try {
            val opts = JSONObject(optionsJson.ifEmpty { "{}" })
            val intent = Intent(act, ScannerActivity::class.java)
            intent.putExtra(ScannerActivity.EXTRA_CONTINUOUS, opts.optBoolean("continuous", false))
            intent.putExtra(ScannerActivity.EXTRA_AUTO_GALLERY, opts.optBoolean("auto_gallery", false))
            intent.putExtra(ScannerActivity.EXTRA_GALLERY_BUTTON, opts.optBoolean("gallery_button", true))
            act.runOnUiThread {
                act.startActivity(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startScan başarısız", e)
            post("scan_error", JSONObject().put("message", e.message ?: "Tarama başlatılamadı"))
        }
    }

    @UsedByGodot
    fun stopScan() {
        mainHandler.post {
            ScannerActivity.instance?.finish()
        }
    }

    // ------------------------------------------------------------ sistem eylemleri

    @UsedByGodot
    fun openUri(uri: String): Boolean {
        val act: Activity = activity ?: return false
        return try {
            act.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(uri)))
            true
        } catch (e: Exception) {
            Log.w(TAG, "openUri ($uri) başarısız: $e")
            false
        }
    }

    @UsedByGodot
    fun shareText(text: String, mime: String) {
        val act: Activity = activity ?: return
        act.runOnUiThread {
            try {
                val i = Intent(Intent.ACTION_SEND)
                i.type = mime.ifEmpty { "text/plain" }
                i.putExtra(Intent.EXTRA_TEXT, text)
                act.startActivity(Intent.createChooser(i, "Paylaş"))
            } catch (e: Exception) {
                Log.w(TAG, "shareText başarısız: $e")
            }
        }
    }

    @UsedByGodot
    fun shareFile(path: String, mime: String) {
        shareFileInternal(path, mime)
    }

    private fun shareFileInternal(path: String, mime: String) {
        val act: Activity = activity ?: return
        act.runOnUiThread {
            try {
                val file = File(path)
                if (!file.exists()) {
                    post("file_shared", JSONObject().put("ok", false).put("message", "Dosya bulunamadı"))
                    return@runOnUiThread
                }
                val uri = FileProvider.getUriForFile(act, fileProviderAuthority(act.packageName), file)
                val i = Intent(Intent.ACTION_SEND)
                i.type = mime.ifEmpty { "*/*" }
                i.putExtra(Intent.EXTRA_STREAM, uri)
                i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                act.startActivity(Intent.createChooser(i, "Paylaş"))
            } catch (e: Exception) {
                Log.w(TAG, "shareFile başarısız: $e")
                post("file_shared", JSONObject().put("ok", false).put("message", e.message ?: "Paylaşılamadı"))
            }
        }
    }

    /**
     * PNG'yi galeriye kaydeder (Android 10+ MediaStore; daha eski sürümlerde
     * paylaşım menüsüne düşer — depolama izni gerekmez). Senkron JSON döner.
     */
    @UsedByGodot
    fun saveImageToGallery(path: String): String {
        val act: Activity = activity ?: return failJson("Aktivite yok")
        try {
            val file = File(path)
            if (!file.exists()) return failJson("Dosya bulunamadı")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues()
                values.put(
                    MediaStore.Images.Media.DISPLAY_NAME,
                    "qr_master_" + System.currentTimeMillis() + ".png"
                )
                values.put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                values.put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/QR Master"
                )
                values.put(MediaStore.Images.Media.IS_PENDING, 1)
                val resolver = act.contentResolver
                val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                    ?: return failJson("Galeriye yazılamadı")
                val stream = resolver.openOutputStream(uri)
                    ?: return failJson("Akış açılamadı")
                stream.use { out -> file.inputStream().use { input -> input.copyTo(out) } }
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                return okJson()
            }
            // Android 10 altı: doğrudan galeriye yazmak izin ister; paylaşım menüsü sun.
            shareFileInternal(path, "image/png")
            return okJson()
        } catch (e: Exception) {
            return failJson(e.message ?: "Kaydedilemedi")
        }
    }

    private fun okJson(): String = JSONObject().put("ok", true).toString()

    private fun failJson(message: String): String =
        JSONObject().put("ok", false).put("message", message).toString()

    @UsedByGodot
    fun playBeep() {
        val act: Activity = activity ?: return
        act.runOnUiThread {
            try {
                val tone = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 90)
                tone.startTone(ToneGenerator.TONE_PROP_BEEP, 120)
                mainHandler.postDelayed({ try { tone.release() } catch (_: Exception) {} }, 500)
            } catch (e: Exception) {
                Log.i(TAG, "beep atlanıyor: $e")
            }
        }
    }

    // ------------------------------------------------------------------ reklamlar

    @UsedByGodot
    fun initAds(bannerId: String, interstitialId: String) {
        bannerUnitId = bannerId
        interstitialUnitId = interstitialId
        if (!adsReady) {
            adsReady = true
            val act: Activity = activity ?: return
            act.runOnUiThread {
                try {
                    MobileAds.initialize(act) { }
                } catch (e: Exception) {
                    Log.w(TAG, "MobileAds init: $e")
                }
            }
        }
        loadInterstitialInternal()
    }

    @UsedByGodot
    fun showBanner() {
        val act: Activity = activity ?: return
        act.runOnUiThread { attachBanner() }
    }

    @UsedByGodot
    fun hideBanner() {
        val act: Activity = activity ?: return
        act.runOnUiThread {
            try {
                val v = bannerAd ?: return@runOnUiThread
                (v.parent as? ViewGroup)?.removeView(v)
            } catch (e: Exception) {
                Log.w(TAG, "hideBanner: $e")
            }
        }
    }

    /** bannerHeightPx()/loadInterstitial()/showInterstitial() tanıtım yerleşimi içindir. */
    @UsedByGodot
    fun bannerHeightPx(): Int {
        val act: Activity = activity ?: return 0
        return try {
            Math.ceil(50.0 * act.resources.displayMetrics.density).toInt()
        } catch (e: Exception) {
            0
        }
    }

    @UsedByGodot
    fun loadInterstitial() {
        loadInterstitialInternal()
    }

    @UsedByGodot
    fun showInterstitial(): Boolean {
        val act: Activity = activity ?: return false
        val ad = interstitialAd ?: return false
        interstitialAd = null
        act.runOnUiThread {
            try {
                ad.show(act)
            } catch (e: Exception) {
                Log.w(TAG, "showInterstitial: $e")
            }
        }
        loadInterstitialInternal()
        return true
    }

    private fun loadInterstitialInternal() {
        if (interstitialUnitId.isEmpty()) return
        val act: Activity = activity ?: return
        try {
            InterstitialAd.load(
                act,
                interstitialUnitId,
                AdRequest.Builder().build(),
                object : InterstitialAdLoadCallback() {
                    override fun onAdLoaded(ad: InterstitialAd) {
                        interstitialAd = ad
                    }

                    override fun onAdFailedToLoad(error: LoadAdError) {
                        Log.i(TAG, "Ara reklam yüklenemedi: ${error.message}")
                    }
                }
            )
        } catch (e: Exception) {
            Log.w(TAG, "loadInterstitial: $e")
        }
    }

    private fun attachBanner() {
        if (bannerUnitId.isEmpty()) return
        val act: Activity = activity ?: return
        try {
            var view = bannerAd
            if (view == null) {
                view = AdView(act)
                view.adUnitId = bannerUnitId
                view.setAdSize(AdSize.BANNER)
                view.loadAd(AdRequest.Builder().build())
                bannerAd = view
            }
            if (view.parent == null) {
                val content = act.findViewById<ViewGroup>(android.R.id.content)
                val lp = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    Gravity.BOTTOM
                )
                content.addView(view, lp)
            }
        } catch (e: Exception) {
            Log.w(TAG, "attachBanner: $e")
        }
    }
}
