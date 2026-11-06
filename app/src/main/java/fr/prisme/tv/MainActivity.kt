package fr.prisme.tv

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.core.content.FileProvider
import androidx.webkit.WebViewAssetLoader
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * prisme : l'interface est une page web locale (assets/web), affichée dans une WebView
 * transparente posée au-dessus du lecteur natif ExoPlayer (Media3).
 * Le pont JavaScript "Prisme" donne à l'interface :
 *  - un proxy HTTP sans CORS pour l'API Xtream, TMDB et les mises à jour
 *  - le contrôle du lecteur (lecture, pistes, format, position)
 *  - le téléchargement et l'installation des mises à jour (APK)
 */
class MainActivity : Activity() {

    private lateinit var web: WebView
    private lateinit var player: Player
    private val main = Handler(Looper.getMainLooper())
    private val host = "appassets.androidplatform.net"
    @Volatile private var typing = false

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val root = FrameLayout(this)
        root.setBackgroundColor(Color.BLACK)
        player = Player(this)
        root.addView(player.view, FrameLayout.LayoutParams(-1, -1))

        WebView.setWebContentsDebuggingEnabled(true)
        web = WebView(this)
        web.setBackgroundColor(Color.TRANSPARENT)
        web.setLayerType(View.LAYER_TYPE_HARDWARE, null)
        with(web.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            mediaPlaybackRequiresUserGesture = false
            mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            cacheMode = WebSettings.LOAD_DEFAULT
            loadWithOverviewMode = false
            useWideViewPort = false
            textZoom = 100
        }
        val assets = WebViewAssetLoader.Builder()
            .setDomain(host)
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this))
            .build()
        web.webChromeClient = WebChromeClient()
        web.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(view: WebView, req: WebResourceRequest): WebResourceResponse? {
                val u = req.url
                if (u.host == host && u.path == "/proxy") return proxy(u.getQueryParameter("u") ?: "")
                return assets.shouldInterceptRequest(u)
            }
        }
        web.addJavascriptInterface(Bridge(), "Prisme")
        root.addView(web, FrameLayout.LayoutParams(-1, -1))
        setContentView(root)
        web.isFocusable = true
        web.requestFocus()
        web.loadUrl("https://$host/assets/web/index.html")
    }

    /** Proxy HTTP : l'interface appelle /proxy?u=<url> et reçoit la réponse sans contrainte CORS. */
    private fun proxy(target: String): WebResourceResponse {
        return try {
            val conn = openFollow(target, 15000, 60000)
            var code = conn.responseCode
            if (code in 300..399) code = 502
            val stream = if (code >= 400) (conn.errorStream ?: "".byteInputStream()) else conn.inputStream
            val type = (conn.contentType ?: "application/octet-stream").substringBefore(";").trim()
            val headers = mapOf("Access-Control-Allow-Origin" to "*", "Cache-Control" to "no-store")
            val reason = conn.responseMessage?.takeIf { it.isNotBlank() } ?: "OK"
            WebResourceResponse(type, "utf-8", code, reason, headers, stream)
        } catch (e: Exception) {
            WebResourceResponse("application/json", "utf-8", 502, "Bad Gateway",
                mapOf("Access-Control-Allow-Origin" to "*"),
                JSONObject().put("error", e.toString()).toString().byteInputStream())
        }
    }

    /** Touches de la télécommande transmises à l'interface (les flèches restent gérées par la page). */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val name = when (event.keyCode) {
            KeyEvent.KEYCODE_BACK -> "back"
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER ->
                if (typing) return super.dispatchKeyEvent(event) else "ok"
            KeyEvent.KEYCODE_MENU -> "menu"
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_MEDIA_PLAY, KeyEvent.KEYCODE_MEDIA_PAUSE -> "play"
            KeyEvent.KEYCODE_MEDIA_REWIND -> "rw"
            KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> "ff"
            KeyEvent.KEYCODE_CHANNEL_UP -> "chup"
            KeyEvent.KEYCODE_CHANNEL_DOWN -> "chdown"
            else -> null
        } ?: return super.dispatchKeyEvent(event)
        if (event.action == KeyEvent.ACTION_DOWN) {
            web.evaluateJavascript("window.nativeKey?String(nativeKey('$name')):'false'") { r ->
                if (name == "back" && r != null && r.contains("exit")) moveTaskToBack(true)
            }
        }
        return true
    }

    override fun onPause() { super.onPause(); player.onPause() }
    override fun onDestroy() { player.release(); web.destroy(); super.onDestroy() }

    // ---------------------------------------------------------------- Pont JavaScript
    inner class Bridge {
        @JavascriptInterface fun appVersion(): String {
            val pi = packageManager.getPackageInfo(packageName, 0)
            @Suppress("DEPRECATION")
            val code = if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else pi.versionCode.toLong()
            return JSONObject().put("name", pi.versionName).put("code", code).toString()
        }
        @JavascriptInterface fun device(): String = JSONObject()
            .put("model", Build.MODEL).put("manufacturer", Build.MANUFACTURER)
            .put("sdk", Build.VERSION.SDK_INT).put("display", Build.DISPLAY).toString()

        // Lecteur
        @JavascriptInterface fun play(url: String, startMs: Long, live: Boolean) = main.post { player.play(url, startMs, live) }
        @JavascriptInterface fun pause() = main.post { player.pause() }
        @JavascriptInterface fun resume() = main.post { player.resume() }
        @JavascriptInterface fun seekTo(ms: Long) = main.post { player.seekTo(ms) }
        @JavascriptInterface fun stop() = main.post { player.stop() }
        @JavascriptInterface fun setAudio(index: Int) = main.post { player.selectTrack(androidx.media3.common.C.TRACK_TYPE_AUDIO, index) }
        @JavascriptInterface fun setSub(index: Int) = main.post { player.selectTrack(androidx.media3.common.C.TRACK_TYPE_TEXT, index) }
        @JavascriptInterface fun setFormat(mode: String) = main.post { player.setFormat(mode) }
        @JavascriptInterface fun state(): String = player.stateJson

        // Mises à jour
        @JavascriptInterface fun canInstall(): Boolean =
            Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls()
        @JavascriptInterface fun openInstallSettings() = main.post {
            try {
                startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
            } catch (e: Exception) {
                try { startActivity(Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)) } catch (_: Exception) {}
            }
        }
        @Volatile private var dl = JSONObject().put("pct", 0).put("done", false).toString()
        @JavascriptInterface fun download(apkUrl: String) {
            dl = JSONObject().put("pct", 0).put("done", false).toString()
            thread {
                try {
                    val dir = File(cacheDir, "updates").apply { mkdirs() }
                    val out = File(dir, "prisme.apk")
                    val conn = openFollow(apkUrl, 15000, 60000)
                    val total = conn.contentLengthLong
                    var read = 0L
                    conn.inputStream.use { inp ->
                        FileOutputStream(out).use { fo ->
                            val buf = ByteArray(64 * 1024)
                            while (true) {
                                val n = inp.read(buf); if (n < 0) break
                                fo.write(buf, 0, n); read += n
                                val pct = if (total > 0) (read * 100 / total).toInt() else 0
                                dl = JSONObject().put("pct", pct).put("read", read).put("total", total).put("done", false).toString()
                            }
                        }
                    }
                    dl = JSONObject().put("pct", 100).put("read", read).put("total", total).put("done", true).toString()
                } catch (e: Exception) {
                    dl = JSONObject().put("pct", 0).put("done", false).put("error", e.message ?: e.toString()).toString()
                }
            }
        }
        @JavascriptInterface fun downloadState(): String = dl
        @JavascriptInterface fun install() = main.post {
            val f = File(File(cacheDir, "updates"), "prisme.apk")
            if (!f.exists()) return@post
            val uri = FileProvider.getUriForFile(this@MainActivity, "$packageName.files", f)
            val i = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(i)
        }
        @JavascriptInterface fun setTyping(on: Boolean) { typing = on }
        @JavascriptInterface fun exit() = main.post { moveTaskToBack(true) }
    }

    companion object {
        const val UA = "prisme/1.0 (Fire TV; Android)"

        /** Ouvre une connexion HTTP en suivant les redirections (y compris http ↔ https). */
        fun openFollow(target: String, connectMs: Int, readMs: Int): HttpURLConnection {
            var url = URL(target)
            var hops = 0
            while (true) {
                val conn = url.openConnection() as HttpURLConnection
                conn.connectTimeout = connectMs
                conn.readTimeout = readMs
                conn.instanceFollowRedirects = false
                conn.setRequestProperty("User-Agent", UA)
                conn.setRequestProperty("Accept", "*/*")
                val code = conn.responseCode
                val loc = conn.getHeaderField("Location")
                if (code in 300..399 && loc != null && hops < 8) {
                    url = URL(url, loc); hops++; conn.disconnect()
                } else {
                    return conn
                }
            }
        }
    }
}
