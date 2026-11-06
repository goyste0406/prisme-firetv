package fr.prisme.tv

import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.MetadataRetriever
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import android.media.MediaExtractor
import android.media.MediaFormat

/**
 * Analyse d'un flux AVANT lecture : résolution, codec, images/s, pistes audio et sous-titres.
 * Une seule analyse à la fois, pour ne pas dépasser le nombre de connexions autorisé par le fournisseur.
 */
@androidx.annotation.OptIn(UnstableApi::class)
class Prober {
    private val exec = Executors.newSingleThreadExecutor()
    private val results = ConcurrentHashMap<String, String>()
    private val factory = DefaultMediaSourceFactory(
        DefaultHttpDataSource.Factory()
            .setUserAgent(MainActivity.UA)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(10000)
            .setReadTimeoutMs(10000)
    )

    fun probe(id: String, url: String) {
        if (results.containsKey(id)) return
        results[id] = "pending"
        exec.execute {
            val t0 = System.currentTimeMillis()
            var res = try { retriever(url) } catch (e: Throwable) {
                JSONObject().put("ok", false).put("error", "ExoPlayer: " + (e.cause?.toString() ?: e.toString()))
            }
            if (!res.optBoolean("ok") || res.optInt("h") == 0) {
                val first = res.optString("error")
                res = try { extractor(url) } catch (e: Throwable) {
                    JSONObject().put("ok", false).put("error", first + " | MediaExtractor: " + e.toString())
                }
            }
            results[id] = res.put("ms", System.currentTimeMillis() - t0).toString()
        }
    }

    private fun retriever(url: String): JSONObject {
        val future = MetadataRetriever.retrieveMetadata(factory, MediaItem.fromUri(url))
        val groups = try { future.get(12, TimeUnit.SECONDS) } catch (e: Exception) { future.cancel(true); throw e }
        val audio = JSONArray(); val subs = JSONArray()
        var w = 0; var h = 0; var vc = ""; var fps = 0f; var hdr = false
        for (g in 0 until groups.length) {
            val tg = groups[g]
            for (t in 0 until tg.length) {
                val f = tg.getFormat(t)
                val mime = f.sampleMimeType ?: f.containerMimeType ?: ""
                when {
                    MimeTypes.isVideo(mime) -> if (f.width * f.height > w * h) {
                        w = f.width; h = f.height; vc = videoCodec(mime, f.codecs); fps = f.frameRate
                        hdr = f.colorInfo?.colorTransfer == C.COLOR_TRANSFER_ST2084 || f.colorInfo?.colorTransfer == C.COLOR_TRANSFER_HLG
                    }
                    MimeTypes.isAudio(mime) -> if (t == 0) audio.put(JSONObject()
                        .put("lang", lang(f.language, f.label)).put("codec", audioCodec(mime)).put("ch", channels(f.channelCount)))
                    MimeTypes.isText(mime) || mime.contains("subrip") || mime.contains("dvbsubs") || mime.contains("pgs") ->
                        if (t == 0) subs.put(JSONObject().put("lang", lang(f.language, f.label)))
                }
            }
        }
        return JSONObject().put("ok", h > 0).put("w", w).put("h", h).put("vc", vc).put("fps", if (fps > 0) Math.round(fps) else 0)
            .put("hdr", hdr).put("audio", audio).put("subs", subs).put("via", "exoplayer")
    }

    /** Solution de secours : extracteur Android, limité à 12 s. */
    private fun extractor(url: String): JSONObject {
        var out: JSONObject? = null
        var err: Throwable? = null
        val th = Thread {
            val ex = MediaExtractor()
            try {
                ex.setDataSource(url, mapOf("User-Agent" to MainActivity.UA))
                val audio = JSONArray(); val subs = JSONArray()
                var w = 0; var h = 0; var vc = ""; var fps = 0
                for (i in 0 until ex.trackCount) {
                    val f = ex.getTrackFormat(i)
                    val mime = f.getString(MediaFormat.KEY_MIME) ?: ""
                    val lg = if (f.containsKey(MediaFormat.KEY_LANGUAGE)) f.getString(MediaFormat.KEY_LANGUAGE) else null
                    when {
                        mime.startsWith("video/") -> {
                            val fw = if (f.containsKey(MediaFormat.KEY_WIDTH)) f.getInteger(MediaFormat.KEY_WIDTH) else 0
                            val fh = if (f.containsKey(MediaFormat.KEY_HEIGHT)) f.getInteger(MediaFormat.KEY_HEIGHT) else 0
                            if (fw * fh > w * h) {
                                w = fw; h = fh; vc = videoCodec(mime, null)
                                fps = try { if (f.containsKey(MediaFormat.KEY_FRAME_RATE)) f.getInteger(MediaFormat.KEY_FRAME_RATE) else 0 } catch (e: Exception) { 0 }
                            }
                        }
                        mime.startsWith("audio/") -> audio.put(JSONObject().put("lang", lang(lg, null)).put("codec", audioCodec(mime))
                            .put("ch", channels(if (f.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) f.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 0)))
                        mime.startsWith("text/") || mime.contains("subrip") -> subs.put(JSONObject().put("lang", lang(lg, null)))
                    }
                }
                out = JSONObject().put("ok", h > 0).put("w", w).put("h", h).put("vc", vc).put("fps", fps).put("hdr", false)
                    .put("audio", audio).put("subs", subs).put("via", "extractor")
            } catch (e: Throwable) { err = e } finally { try { ex.release() } catch (_: Throwable) {} }
        }
        th.start(); th.join(12000)
        out?.let { return it }
        throw err ?: java.util.concurrent.TimeoutException("délai de 12 s dépassé")
    }

    fun result(id: String): String = results[id] ?: ""
    fun forget(id: String) { results.remove(id) }

    private fun lang(code: String?, label: String?): String {
        if (!label.isNullOrBlank()) return label
        if (code.isNullOrBlank() || code == "und") return ""
        return Locale(code).getDisplayLanguage(Locale.FRENCH).replaceFirstChar { it.uppercase() }
    }
    private fun videoCodec(mime: String, codecs: String?): String = when {
        mime.contains("hevc") || codecs?.startsWith("hvc") == true || codecs?.startsWith("hev") == true -> "HEVC"
        mime.contains("avc") || codecs?.startsWith("avc") == true -> "H.264"
        mime.contains("vp9") -> "VP9"
        mime.contains("av01") -> "AV1"
        mime.contains("mpeg2") -> "MPEG-2"
        else -> mime.substringAfter("/").uppercase()
    }
    private fun audioCodec(mime: String): String = when {
        mime.contains("eac3") -> "E-AC3"
        mime.contains("ac3") -> "AC3"
        mime.contains("mp4a") || mime.contains("aac") -> "AAC"
        mime.contains("dts") -> "DTS"
        mime.contains("opus") -> "Opus"
        mime.contains("mpeg") -> "MP2"
        else -> mime.substringAfter("/").uppercase()
    }
    private fun channels(n: Int): String = when (n) { 1 -> "mono"; 2 -> "stéréo"; 6 -> "5.1"; 8 -> "7.1"; else -> "" }
}
