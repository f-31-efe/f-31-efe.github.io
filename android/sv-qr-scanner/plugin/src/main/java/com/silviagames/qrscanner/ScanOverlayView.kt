package com.silviagames.qrscanner

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import android.view.View

/**
 * Tarama ekranının üst katmanı: karartma, köşe ayraçları ve hareketli tarama çizgisi.
 * Tamamen kod içinde çizilir (kaynak gerekmez).
 */
class ScanOverlayView(context: Context) : View(context) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val dimColor = Color.argb(150, 3, 6, 14)
    private val accent = Color.rgb(79, 209, 197)
    private val handler = Handler(Looper.getMainLooper())
    private var t = 0f

    private val ticker = object : Runnable {
        override fun run() {
            t += 0.05f
            invalidate()
            handler.postDelayed(this, 33L)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        handler.postDelayed(ticker, 33L)
    }

    override fun onDetachedFromWindow() {
        handler.removeCallbacks(ticker)
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val density = resources.displayMetrics.density
        val side = minOf(width, height) * 0.72f
        val cx = width / 2f
        val cy = height * 0.42f
        val left = cx - side / 2f
        val top = cy - side / 2f
        val right = cx + side / 2f
        val bottom = cy + side / 2f

        // Dış alan karartması
        paint.style = Paint.Style.FILL
        paint.color = dimColor
        canvas.drawRect(0f, 0f, width.toFloat(), top, paint)
        canvas.drawRect(0f, bottom, width.toFloat(), height.toFloat(), paint)
        canvas.drawRect(0f, top, left, bottom, paint)
        canvas.drawRect(right, top, width.toFloat(), bottom, paint)

        // Köşe ayraçları
        paint.color = accent
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 5f * density
        val arm = side * 0.16f
        canvas.drawLine(left, top, left + arm, top, paint)
        canvas.drawLine(left, top, left, top + arm, paint)
        canvas.drawLine(right, top, right - arm, top, paint)
        canvas.drawLine(right, top, right, top + arm, paint)
        canvas.drawLine(left, bottom, left + arm, bottom, paint)
        canvas.drawLine(left, bottom, left, bottom - arm, paint)
        canvas.drawLine(right, bottom, right - arm, bottom, paint)
        canvas.drawLine(right, bottom, right, bottom - arm, paint)

        // Hareketli tarama çizgisi
        val alpha = (150 + 90 * Math.sin(t.toDouble())).toInt()
        paint.color = Color.argb(alpha, 79, 209, 197)
        paint.strokeWidth = 2.5f * density
        val phase = (0.5f + 0.5f * Math.sin(t.toDouble() * 1.3f)).toFloat()
        val lineY = top + 14f * density + (side - 28f * density) * phase
        canvas.drawLine(left + 16f * density, lineY, right - 16f * density, lineY, paint)

        // İnce çerçeve
        paint.color = Color.argb(60, 79, 209, 197)
        paint.strokeWidth = 1f * density
        canvas.drawRect(left, top, right, bottom, paint)
    }
}
