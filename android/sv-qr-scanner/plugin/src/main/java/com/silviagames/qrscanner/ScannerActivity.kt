package com.silviagames.qrscanner

import android.Manifest
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import org.json.JSONObject
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Canlı QR/barkod tarama ekranı.
 *
 * - CameraX önizlemesi + ML Kit (cihaz üzerinde, çevrimdışı)
 * - Fener (torç), galeriden kod seçme, sürekli/toplu tarama
 * - Sonuçlar Godot'a olay kuyruğu üzerinden iletilir; [finish] her durumda
 *   tek bir "scan_closed" olayı yayınlar.
 *
 * Manifest tanımı AAR manifestindedir; aktivite kendi izin istem döngüsüne sahiptir.
 */
class ScannerActivity : ComponentActivity() {

    companion object {
        const val EXTRA_CONTINUOUS = "continuous"
        const val EXTRA_AUTO_GALLERY = "auto_gallery"
        const val EXTRA_GALLERY_BUTTON = "gallery_button"
        private const val RC_CAMERA = 4101
        private const val RC_GALLERY = 4102
        private const val TAG = "SvQrScanner"
        private const val DEBOUNCE_MS = 1500L

        @JvmStatic
        var instance: ScannerActivity? = null
    }

    private var continuous = false
    private var autoGallery = false
    private var showGalleryButton = true
    private var torchOn = false
    private var finishingOnce = false
    private var lastText = ""
    private var lastAt = 0L

    private lateinit var previewView: PreviewView
    private lateinit var overlay: ScanOverlayView
    private lateinit var torchButton: TextView
    private lateinit var galleryButton: TextView

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: androidx.camera.core.Camera? = null
    private var analysis: ImageAnalysis? = null
    private var executor: ExecutorService? = null
    private val detector = BarcodeScanning.getClient()
    private val mainHandler = Handler(Looper.getMainLooper())

    // ------------------------------------------------------------ yaşam döngüsü

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        continuous = intent.getBooleanExtra(EXTRA_CONTINUOUS, false)
        autoGallery = intent.getBooleanExtra(EXTRA_AUTO_GALLERY, false)
        showGalleryButton = intent.getBooleanExtra(EXTRA_GALLERY_BUTTON, true)

        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        window.addFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )
        hideSystemBars()
        setContentView(buildLayout())

        if (autoGallery) {
            galleryButton.visibility = View.GONE
            pickImage()
        } else {
            ensureCameraPermission()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            analysis?.clearAnalyzer()
            cameraProvider?.unbindAll()
        } catch (_: Exception) {
        }
        executor?.shutdown()
        try {
            detector.close()
        } catch (_: Exception) {
        }
        if (instance === this) instance = null
    }

    override fun finish() {
        if (!finishingOnce) {
            finishingOnce = true
            QrScannerPlugin.post("scan_closed")
        }
        super.finish()
    }

    // -------------------------------------------------------------------- arayüz

    private fun hideSystemBars() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.systemBars())
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                    View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                )
        }
    }

    private fun buildLayout(): View {
        val root = FrameLayout(this)
        root.setBackgroundColor(Color.rgb(3, 6, 14))

        previewView = PreviewView(this)
        root.addView(
            previewView,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        )

        overlay = ScanOverlayView(this)
        root.addView(
            overlay,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        )

        // Üst bar: Kapat ↔ Fener
        val top = LinearLayout(this)
        top.orientation = LinearLayout.HORIZONTAL
        val topLp = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.TOP
        )
        topLp.topMargin = dp(30)
        topLp.leftMargin = dp(16)
        topLp.rightMargin = dp(16)
        root.addView(top, topLp)

        val closeBtn = chipButton("Kapat") { finish() }
        top.addView(closeBtn)
        val spacer = View(this)
        spacer.layoutParams = LinearLayout.LayoutParams(0, 1, 1f)
        top.addView(spacer)
        torchButton = chipButton("Fener") { toggleTorch() }
        torchButton.alpha = 0.55f
        top.addView(torchButton)

        // Alt bar: ipucu + galeri
        val bottom = LinearLayout(this)
        bottom.orientation = LinearLayout.VERTICAL
        bottom.gravity = Gravity.CENTER_HORIZONTAL
        val bottomLp = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM
        )
        bottomLp.bottomMargin = dp(26)
        root.addView(bottom, bottomLp)

        val hint = TextView(this)
        hint.text = if (autoGallery) "Görseldeki kod çözümleniyor…" else "Kareyi kodun üzerine hizalayın"
        hint.setTextColor(Color.argb(230, 235, 240, 250))
        hint.textSize = 15f
        hint.gravity = Gravity.CENTER
        hint.setPadding(dp(16), 0, dp(16), dp(14))
        bottom.addView(hint)

        galleryButton = chipButton("Galeriden seç") { pickImage() }
        if (!showGalleryButton) galleryButton.visibility = View.GONE
        bottom.addView(galleryButton)

        return root
    }

    private fun chipButton(text: String, onClick: () -> Unit): TextView {
        val tv = TextView(this)
        tv.text = text
        tv.setTextColor(Color.WHITE)
        tv.textSize = 15f
        tv.typeface = Typeface.DEFAULT_BOLD
        tv.gravity = Gravity.CENTER
        tv.setPadding(dp(18), dp(11), dp(18), dp(11))
        val bg = android.graphics.drawable.GradientDrawable()
        bg.cornerRadius = dp(22).toFloat()
        bg.setColor(Color.argb(170, 8, 14, 30))
        bg.setStroke(dp(1), Color.argb(130, 79, 209, 197))
        tv.background = bg
        tv.setOnClickListener { onClick() }
        return tv
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density + 0.5f).toInt()

    // -------------------------------------------------------------------- izinler

    private fun ensureCameraPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            startCamera()
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), RC_CAMERA)
        }
    }	override fun onRequestPermissionsResult(
		requestCode: Int,
		permissions: Array<String>,
		grantResults: IntArray
	) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == RC_CAMERA) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startCamera()
            } else {
                QrScannerPlugin.post(
                    "scan_error",
                    JSONObject().put("message", "Kamera izni verilmedi")
                )
                finish()
            }
        }
    }

    // -------------------------------------------------------------------- kamera

    private fun startCamera() {
        executor = Executors.newSingleThreadExecutor()
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            try {
                cameraProvider = future.get()
                val preview = Preview.Builder().build()
                preview.setSurfaceProvider(previewView.surfaceProvider)

                val analyzer = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                analysis = analyzer
                analyzer.setAnalyzer(executor!!) { proxy -> analyze(proxy) }

                cameraProvider?.unbindAll()
                camera = cameraProvider?.bindToLifecycle(
                    this,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    analyzer
                )
                runOnUiThread { torchButton.alpha = 1f }
            } catch (e: Exception) {
                QrScannerPlugin.post(
                    "scan_error",
                    JSONObject().put("message", "Kamera başlatılamadı: ${e.message}")
                )
                finish()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun analyze(proxy: ImageProxy) {
        val media = proxy.image
        if (media == null) {
            proxy.close()
            return
        }
        val rotation = proxy.imageInfo.rotationDegrees
        val input = InputImage.fromMediaImage(media, rotation)
        detector.process(input)
            .addOnSuccessListener { barcodes -> onBarcodes(barcodes, "camera") }
            .addOnFailureListener { e -> android.util.Log.i(TAG, "analiz hatası: $e") }
            .addOnCompleteListener { proxy.close() }
    }

    private fun toggleTorch() {
        val c = camera ?: return
        torchOn = !torchOn
        c.cameraControl.enableTorch(torchOn)
        torchButton.text = if (torchOn) "Fener açık" else "Fener"
    }

    // ------------------------------------------------------------------ sonuçlar

    private fun onBarcodes(barcodes: List<Barcode>, source: String) {
        if (barcodes.isEmpty()) return
        var chosen: Barcode? = null
        for (b in barcodes) {
            if (b.format == Barcode.FORMAT_QR_CODE) {
                chosen = b
                break
            }
        }
        val bc = chosen ?: barcodes.first()
        val text = bc.rawValue ?: return

        val now = System.currentTimeMillis()
        if (text == lastText && now - lastAt < DEBOUNCE_MS) return
        lastText = text
        lastAt = now

        QrScannerPlugin.post(
            "scan_result",
            JSONObject().put("text", text).put("source", source)
        )
        if (!continuous) {
            // Sonucun Godot tarafınca işlenmesi için kısa gecikmeyle kapan.
            mainHandler.postDelayed({ finish() }, 250)
        }
    }

    // ------------------------------------------------------------------- galeri

    private fun pickImage() {
        try {
            val i = Intent(Intent.ACTION_GET_CONTENT)
            i.type = "image/*"
            i.addCategory(Intent.CATEGORY_OPENABLE)
            startActivityForResult(Intent.createChooser(i, "Görsel seç"), RC_GALLERY)
        } catch (e: Exception) {
            Toast.makeText(this, "Galeri açılamadı", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != RC_GALLERY) return
        if (resultCode != RESULT_OK || data?.data == null) {
            if (autoGallery) finish()
            return
        }
        val uri: Uri = data.data ?: return
        try {
            val input = InputImage.fromFilePath(this, uri)
            detector.process(input)
                .addOnSuccessListener { barcodes ->
                    if (barcodes.isEmpty()) {
                        Toast.makeText(this, "Karede okunabilir kod bulunamadı", Toast.LENGTH_LONG).show()
                        if (autoGallery) mainHandler.postDelayed({ finish() }, 1100)
                    } else {
                        onBarcodes(barcodes, "image")
                        if (autoGallery) mainHandler.postDelayed({ finish() }, 450)
                    }
                }
                .addOnFailureListener {
                    Toast.makeText(this, "Görsel okunamadı", Toast.LENGTH_LONG).show()
                    if (autoGallery) mainHandler.postDelayed({ finish() }, 1100)
                }
        } catch (e: Exception) {
            Toast.makeText(this, "Görsel açılamadı", Toast.LENGTH_LONG).show()
            if (autoGallery) finish()
        }
    }
}
