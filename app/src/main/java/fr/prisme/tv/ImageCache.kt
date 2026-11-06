package fr.prisme.tv

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.webkit.WebResourceResponse
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

/**
 * Affiches, logos et fonds : téléchargés une fois, réduits à la taille d'affichage et gardés sur l'appareil.
 * Les images des fournisseurs IPTV font souvent 500 Ko à 2 Mo : les décoder en plein format ralentit fortement
 * le Fire TV Stick. Ici elles sont ré-encodées en JPEG de quelques dizaines de Ko.
 */
class ImageCache(private val dir: File) {
    private val locks = ConcurrentHashMap<String, Any>()
    private val bad: MutableSet<String> = ConcurrentHashMap.newKeySet()

    init {
        dir.mkdirs()
        thread(isDaemon = true) { trim(180L * 1024 * 1024) }
    }

    fun get(url: String, width: Int): WebResourceResponse {
        val w = width.coerceIn(48, 1280)
        val headers = mapOf("Access-Control-Allow-Origin" to "*", "Cache-Control" to "max-age=2592000")
        if (!url.startsWith("http")) return WebResourceResponse("image/jpeg", null, 404, "Not Found", headers, "".byteInputStream())
        val f = File(dir, sha1(url) + "_" + w + ".img")
        if (f.name in bad) return WebResourceResponse("image/jpeg", null, 404, "Not Found", headers, "".byteInputStream())
        try {
            if (!f.exists()) synchronized(locks.getOrPut(f.name) { Any() }) { if (!f.exists()) fetch(url, w, f) }
            locks.remove(f.name)
            if (f.exists() && f.length() > 0) {
                f.setLastModified(System.currentTimeMillis())
                return WebResourceResponse("image/jpeg", null, 200, "OK", headers, f.inputStream())
            }
        } catch (_: Throwable) { }
        bad.add(f.name)
        return WebResourceResponse("image/jpeg", null, 404, "Not Found", headers, "".byteInputStream())
    }

    private fun fetch(url: String, w: Int, out: File) {
        val conn = MainActivity.openFollow(url, 10000, 20000)
        if (conn.responseCode >= 300) { conn.disconnect(); return }
        if (conn.contentLengthLong > 15L * 1024 * 1024) { conn.disconnect(); return }
        val bytes = conn.inputStream.use { it.readBytes() }
        val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, o)
        if (o.outWidth <= 0) return
        var sample = 1
        while (o.outWidth / (sample * 2) >= w) sample *= 2
        // les logos PNG transparents restent en PNG pour garder la transparence
        val png = o.outMimeType == "image/png" && w <= 400
        val opts = BitmapFactory.Options().apply {
            inSampleSize = sample; inPreferredConfig = if (png) Bitmap.Config.ARGB_8888 else Bitmap.Config.RGB_565
        }
        var bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts) ?: return
        if (bmp.width > w) {
            val h = (bmp.height.toLong() * w / bmp.width).toInt().coerceAtLeast(1)
            val sc = Bitmap.createScaledBitmap(bmp, w, h, true)
            if (sc !== bmp) bmp.recycle()
            bmp = sc
        }
        val buf = ByteArrayOutputStream()
        bmp.compress(if (png) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG, if (png) 100 else 82, buf)
        bmp.recycle()
        val tmp = File(out.path + ".tmp")
        tmp.writeBytes(buf.toByteArray())
        tmp.renameTo(out)
    }

    private fun trim(max: Long) {
        val files = dir.listFiles() ?: return
        var total = files.sumOf { it.length() }
        if (total <= max) return
        for (f in files.sortedBy { it.lastModified() }) {
            total -= f.length(); f.delete()
            if (total <= max * 3 / 4) break
        }
    }

    private fun sha1(s: String): String =
        MessageDigest.getInstance("SHA-1").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }
}
