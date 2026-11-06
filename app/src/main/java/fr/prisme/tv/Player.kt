package fr.prisme.tv

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

/** Lecteur natif ExoPlayer (Media3), piloté depuis l'interface via le pont JavaScript. */
@androidx.annotation.OptIn(UnstableApi::class)
class Player(private val ctx: Context) {

    val view = PlayerView(ctx).apply {
        useController = false
        setKeepContentOnPlayerReset(false)
        setShutterBackgroundColor(android.graphics.Color.TRANSPARENT)
        visibility = View.INVISIBLE
        isFocusable = false
    }
    private var exo: ExoPlayer? = null
    private var live = false
    private var error: String? = null
    private var format = "auto"
    private val main = Handler(Looper.getMainLooper())
    @Volatile var stateJson: String = "{}"
    /** Appelé quand la première image de la vidéo est affichée (fin de l'écran de chargement natif) */
    var onFirstFrame: (() -> Unit)? = null
    private var preUrl: String? = null
    private var preStart = 0L

    private val tick = object : Runnable {
        override fun run() { update(); main.postDelayed(this, 250) }
    }

    private fun build(): ExoPlayer {
        val http = DefaultHttpDataSource.Factory()
            .setUserAgent(MainActivity.UA)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15000)
            .setReadTimeoutMs(30000)
        // Tampon modéré : le Fire TV Stick 3e génération n'a que 1 Go de RAM
        val load = DefaultLoadControl.Builder()
            .setBufferDurationsMs(15000, 40000, 1000, 3000)
            .build()
        val renderers = DefaultRenderersFactory(ctx).setEnableDecoderFallback(true)
        return ExoPlayer.Builder(ctx, renderers)
            .setMediaSourceFactory(DefaultMediaSourceFactory(http))
            .setLoadControl(load)
            .build().also { p ->
                p.addListener(object : androidx.media3.common.Player.Listener {
                    override fun onPlayerError(e: PlaybackException) { error = "${e.errorCodeName}: ${e.message}" }
                    override fun onVideoSizeChanged(v: VideoSize) { applyFormat() }
                    override fun onRenderedFirstFrame() { if (p.playWhenReady) main.post { onFirstFrame?.invoke() } }
                })
            }
    }

    /** Préchargement depuis la fiche : connexion ouverte et mise en mémoire tampon, sans afficher */
    fun preload(url: String, startMs: Long) {
        if (exo?.playWhenReady == true && exo?.playbackState != androidx.media3.common.Player.STATE_IDLE) return
        val p = exo ?: build().also { exo = it; view.player = it }
        error = null; preUrl = url; preStart = startMs; stateJson = "{}"
        p.setMediaItem(MediaItem.fromUri(url), if (startMs > 0) startMs else C.TIME_UNSET)
        p.prepare(); p.playWhenReady = false
    }

    fun unpreload() {
        if (preUrl == null) return
        preUrl = null
        if (exo?.playWhenReady != true) { exo?.stop(); exo?.clearMediaItems() }
    }

    fun play(url: String, startMs: Long, isLive: Boolean) {
        val p = exo ?: build().also { exo = it; view.player = it }
        stateJson = "{}"
        if (url == preUrl && p.playbackState != androidx.media3.common.Player.STATE_IDLE && error == null) {
            preUrl = null; live = isLive
            if (startMs > 0 && Math.abs(startMs - preStart) > 3000) p.seekTo(startMs)
            p.playWhenReady = true
            view.visibility = View.VISIBLE
            main.removeCallbacks(tick); main.post(tick)
            return
        }
        preUrl = null
        error = null; live = isLive
        p.setMediaItem(MediaItem.fromUri(url), if (startMs > 0) startMs else C.TIME_UNSET)
        p.prepare(); p.playWhenReady = true
        view.visibility = View.VISIBLE
        main.removeCallbacks(tick); main.post(tick)
    }
    fun pause() { exo?.pause() }
    fun resume() { exo?.play() }
    fun seekTo(ms: Long) { exo?.seekTo(ms.coerceAtLeast(0)) }
    fun stop() {
        preUrl = null
        exo?.stop(); exo?.clearMediaItems()
        view.visibility = View.INVISIBLE
        main.removeCallbacks(tick); stateJson = "{}"
    }
    fun onPause() { exo?.pause() }
    fun release() { main.removeCallbacks(tick); exo?.release(); exo = null }

    /** index = position dans la liste envoyée à l'interface ; -1 = désactiver (sous-titres). */
    fun selectTrack(type: Int, index: Int) {
        val p = exo ?: return
        val groups = p.currentTracks.groups.filter { it.type == type }
        val b = p.trackSelectionParameters.buildUpon()
        if (index < 0) {
            b.setTrackTypeDisabled(type, true)
        } else {
            var n = 0
            for (g in groups) for (i in 0 until g.length) {
                if (n == index) {
                    b.setTrackTypeDisabled(type, false)
                    b.setOverrideForType(TrackSelectionOverride(g.mediaTrackGroup, i))
                }
                n++
            }
        }
        p.trackSelectionParameters = b.build()
    }

    fun setFormat(mode: String) { format = mode; applyFormat() }

    private fun applyFormat() {
        val p = exo
        val vs = p?.videoSize
        val va = if (vs != null && vs.width > 0 && vs.height > 0) vs.width * vs.pixelWidthHeightRatio / vs.height else 16f / 9f
        view.scaleX = 1f; view.scaleY = 1f
        view.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        when (format) {
            "fill" -> view.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_ZOOM
            "stretch" -> view.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FILL
            "zoom" -> { view.scaleX = 1.33f; view.scaleY = 1.33f }
            "169" -> view.scaleX = (16f / 9f) / va
            "43" -> view.scaleX = (4f / 3f) / va
            "219" -> { view.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT; view.scaleY = va / (21f / 9f) }
            "fit" -> view.scaleX = 0.96f.also { view.scaleY = 0.96f }
        }
    }

    private fun label(f: androidx.media3.common.Format): JSONObject {
        val lang = f.language?.let { Locale(it).getDisplayLanguage(Locale.FRENCH).replaceFirstChar { c -> c.uppercase() } }
        val codec = when {
            f.sampleMimeType?.contains("eac3") == true -> "E-AC3"
            f.sampleMimeType?.contains("ac3") == true -> "AC3"
            f.sampleMimeType?.contains("mp4a") == true || f.sampleMimeType?.contains("aac") == true -> "AAC"
            f.sampleMimeType?.contains("dts") == true -> "DTS"
            f.sampleMimeType?.contains("opus") == true -> "Opus"
            else -> f.sampleMimeType?.substringAfter("/")?.uppercase()
        }
        val ch = when (f.channelCount) { 1 -> "mono"; 2 -> "stéréo"; 6 -> "5.1"; 8 -> "7.1"; else -> "" }
        return JSONObject().put("name", f.label ?: lang ?: "Piste").put("lang", lang ?: "")
            .put("codec", listOfNotNull(codec, ch.ifEmpty { null }).joinToString(" "))
    }

    private fun update() {
        val p = exo ?: return
        val audio = JSONArray(); val subs = JSONArray()
        var aSel = -1; var sSel = -1
        var vName = ""
        var an = 0; var sn = 0
        val tracks: Tracks = p.currentTracks
        for (g in tracks.groups) for (i in 0 until g.length) {
            val f = g.getTrackFormat(i)
            when (g.type) {
                C.TRACK_TYPE_AUDIO -> { audio.put(label(f)); if (g.isTrackSelected(i)) aSel = an; an++ }
                C.TRACK_TYPE_TEXT -> { subs.put(label(f)); if (g.isTrackSelected(i)) sSel = sn; sn++ }
                C.TRACK_TYPE_VIDEO -> if (g.isTrackSelected(i)) {
                    val codec = f.sampleMimeType?.substringAfter("/")?.uppercase() ?: ""
                    vName = "$codec · ${f.width}×${f.height}" + (if (f.frameRate > 0) " · ${f.frameRate.toInt()} i/s" else "")
                }
            }
        }
        stateJson = JSONObject()
            .put("pos", p.currentPosition).put("dur", if (p.duration == C.TIME_UNSET) -1 else p.duration)
            .put("playing", p.isPlaying).put("buffering", p.playbackState == androidx.media3.common.Player.STATE_BUFFERING)
            .put("ended", p.playbackState == androidx.media3.common.Player.STATE_ENDED)
            .put("live", live).put("error", error ?: JSONObject.NULL)
            .put("video", vName).put("audio", audio).put("subs", subs).put("aSel", aSel).put("sSel", sSel)
            .toString()
    }
}
