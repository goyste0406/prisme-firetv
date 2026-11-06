package fr.prisme.tv.nat

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.animation.LinearInterpolator
import android.webkit.WebView
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.bumptech.glide.Glide
import com.bumptech.glide.load.DecodeFormat
import com.bumptech.glide.load.engine.DiskCacheStrategy
import com.bumptech.glide.load.resource.drawable.DrawableTransitionOptions
import com.bumptech.glide.request.transition.DrawableCrossFadeFactory
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.util.concurrent.Executors

fun JSONObject.objs(key: String): List<JSONObject> {
    val a = optJSONArray(key) ?: return emptyList()
    return (0 until a.length()).mapNotNull { a.optJSONObject(it) }
}

fun JSONArray?.strs(): List<String> {
    if (this == null) return emptyList()
    return (0 until length()).map { optString(it) }
}

/**
 * Interface native des films et séries. Les données (catalogue fusionné, qualité des sources, reprises,
 * favoris) restent gérées par la couche existante : l'interface native les demande via nativeApi (JavaScript)
 * et se contente de les afficher, ce qui garde un seul catalogue et un seul lecteur.
 */
class NativeUi(val host: Host, val web: WebView) {
    interface Host {
        fun nativeVisible(on: Boolean)
        fun exitApp()
    }

    val ctx: Context = web.context
    val main = Handler(Looper.getMainLooper())
    private val work = Executors.newSingleThreadExecutor()
    val root = FrameLayout(ctx)
    private val bgBase = View(ctx)
    private val bgImg = ImageView(ctx)
    private val scrim = View(ctx)
    private val layer = FrameLayout(ctx)
    private val toastV = K.text(ctx, 19f, Color.WHITE, 500, 2)
    val loading = LoadingOverlay(ctx)
    val stack = ArrayList<Screen>()
    var visible = false
        private set
    private var home: HomeScreen? = null
    private var bgUrl = ""
    private val bgRun = Runnable { applyBgImage() }

    init {
        K.init(ctx)
        root.setBackgroundColor(Color.BLACK)
        root.visibility = View.GONE
        root.clipChildren = false
        root.addView(bgBase, K.lp(K.MATCH, K.MATCH))
        bgImg.scaleType = ImageView.ScaleType.CENTER_CROP
        root.addView(bgImg, K.lp(K.MATCH, K.MATCH))
        scrim.background = LayerDrawable(arrayOf<Drawable>(
            GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(K.black(0.8f), K.black(0.38f), K.black(0.1f))),
            GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, intArrayOf(K.black(0.88f), K.black(0.3f), Color.TRANSPARENT))
        ))
        root.addView(scrim, K.lp(K.MATCH, K.MATCH))
        layer.clipChildren = false
        root.addView(layer, K.lp(K.MATCH, K.MATCH))
        loading.visibility = View.GONE
        root.addView(loading, K.lp(K.MATCH, K.MATCH))
        toastV.gravity = Gravity.CENTER
        toastV.setPadding(K.px(24), K.px(14), K.px(24), K.px(14))
        toastV.background = K.round(Color.argb(247, 36, 36, 44), 18f, 1, K.white(0.12f))
        toastV.alpha = 0f
        root.addView(toastV, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL).apply { bottomMargin = K.px(40) })
        setBg("#2b3245", "#0a0b10", null)
    }

    // ------------------------------------------------------------------ pont vers la couche de données
    fun js(expr: String, cb: ((String?) -> Unit)? = null) {
        web.evaluateJavascript(expr) { r ->
            if (cb == null) return@evaluateJavascript
            val s = try { if (r == null || r == "null") null else JSONTokener(r).nextValue() as? String } catch (e: Exception) { null }
            cb(s)
        }
    }

    /** Appelle nativeApi.<fn> ; la réponse JSON est décodée hors du fil principal (listes de plusieurs milliers de titres) */
    fun api(call: String, cb: (JSONObject?) -> Unit) {
        js("(function(){try{return window.nativeApi?nativeApi.$call:null}catch(e){return JSON.stringify({error:String(e)})}})()") { s ->
            if (s == null) { cb(null); return@js }
            work.execute {
                val o = try { JSONObject(s) } catch (e: Exception) { null }
                main.post { cb(o) }
            }
        }
    }

    fun q(s: String): String = JSONObject.quote(s)

    // ------------------------------------------------------------------ affichage
    fun show(tab: String) {
        val h = home ?: HomeScreen(this).also { home = it }
        if (tab == "films" || tab == "series") {
            while (stack.size > 1) popSilently()
            if (stack.isEmpty()) { stack.add(h); layer.addView(h, K.lp(K.MATCH, K.MATCH)) }
            h.visibility = View.VISIBLE
            setVisible(true)
            h.openTab(tab, focusTabs = true)
        } else {
            if (stack.isEmpty()) { stack.add(h); layer.addView(h, K.lp(K.MATCH, K.MATCH)); h.openTab("films", true) }
            setVisible(true)
            val t = stack.last()
            t.visibility = View.VISIBLE
            t.applyBackground()
            t.onShown()
            t.post { t.restoreFocus() }
        }
    }

    private fun setVisible(on: Boolean) {
        if (visible == on) return
        visible = on
        root.visibility = if (on) View.VISIBLE else View.GONE
        host.nativeVisible(on)
    }

    /** Passe à l'interface actuelle (TV en direct, recherche, réglages, lecteur) */
    fun toWeb() { setVisible(false) }

    fun webTab(key: String) {
        js("nativeApi.tab(${q(key)})")
        toWeb()
    }

    fun webScreen(kind: String, id: String) {
        js("nativeApi.web(${q(kind)},${q(id)})")
        toWeb()
    }

    fun push(s: Screen) {
        val top = stack.lastOrNull()
        if (top != null && !s.modal) { top.visibility = View.INVISIBLE; top.onHidden() }
        stack.add(s)
        layer.addView(s, K.lp(K.MATCH, K.MATCH))
        s.applyBackground()
        s.post { s.apply(true) }
    }

    fun pop() {
        if (stack.size <= 1) return
        val s = stack.removeAt(stack.size - 1)
        s.onHidden()
        layer.removeView(s)
        val t = stack.last()
        if (t.visibility != View.VISIBLE) t.visibility = View.VISIBLE
        t.applyBackground()
        t.onShown()
        t.restoreFocus()
    }

    private fun popSilently() {
        val s = stack.removeAt(stack.size - 1)
        s.onHidden(); layer.removeView(s)
    }

    fun openDetail(id: String, fromWeb: Boolean = false) {
        if (stack.isEmpty()) { val h = home ?: HomeScreen(this).also { home = it }; stack.add(h); layer.addView(h, K.lp(K.MATCH, K.MATCH)); h.openTab(if (id.startsWith("s")) "series" else "films", false) }
        setVisible(true)
        push(DetailScreen(this, id, fromWeb))
    }

    fun top(): Screen? = stack.lastOrNull()

    // ------------------------------------------------------------------ télécommande
    fun onKey(e: KeyEvent): Boolean {
        val code = e.keyCode
        val handled = when (code) {
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT,
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER, KeyEvent.KEYCODE_BACK,
            KeyEvent.KEYCODE_MENU, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_MEDIA_PLAY -> true
            else -> false
        }
        if (!handled) return false
        if (e.action != KeyEvent.ACTION_DOWN) return true
        if (loading.visibility == View.VISIBLE) {
            if (code == KeyEvent.KEYCODE_BACK) cancelPlay()
            return true
        }
        val t = top() ?: return true
        when (code) {
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_MEDIA_PLAY -> if (e.repeatCount == 0) t.ok()
            KeyEvent.KEYCODE_MENU -> if (e.repeatCount == 0) t.menu()
            KeyEvent.KEYCODE_BACK -> if (e.repeatCount == 0) back()
            else -> t.key(code)
        }
        return true
    }

    fun back() {
        val t = top() ?: return
        if (t.onBack()) return
        if (stack.size > 1) {
            val fromWeb = (t as? DetailScreen)?.fromWeb == true
            pop()
            if (fromWeb) toWeb()
            return
        }
        host.exitApp()
    }

    // ------------------------------------------------------------------ lecture
    fun play(id: String, src: String, ss: Int, ep: Int) {
        api("play(${q(id)},${q(src)},$ss,$ep)") { r ->
            if (r == null || !r.optBoolean("ok")) { toast(r?.optString("msg")?.ifEmpty { null } ?: "Lecture impossible"); return@api }
            loading.show(r)
        }
    }

    fun preload(id: String, ss: Int, ep: Int) { js("nativeApi.preload(${q(id)},$ss,$ep)") }
    fun unpreload() { js("nativeApi.unpreload()") }

    private fun cancelPlay() {
        loading.hide()
        js("nativeApi.cancel()")
    }

    /** Première image de la vidéo affichée : on laisse la place au lecteur */
    fun onFirstFrame() {
        if (loading.visibility != View.VISIBLE) return
        loading.hide()
        toWeb()
    }

    /** Messages envoyés par la couche de données */
    fun event(kind: String, data: String) {
        val o = try { if (data.isEmpty()) JSONObject() else JSONObject(data) } catch (e: Exception) { JSONObject() }
        when (kind) {
            "detail" -> stack.filterIsInstance<DetailScreen>().filter { it.itemId == o.optString("id") }.forEach { it.update(o) }
            "catalog" -> home?.reload()
            "loading" -> if (loading.visibility == View.VISIBLE) loading.update(o)
            "playfail" -> { loading.hide(); toast(o.optString("msg")) }
            "toast" -> toast(o.optString("msg"))
            "home" -> home?.reload()
        }
    }

    // ------------------------------------------------------------------ fond et message
    fun setBg(c1: String?, c2: String?, img: String?) {
        val a = K.color(c1, Color.parseColor("#2b3245"))
        val b = K.color(c2, Color.parseColor("#0a0b10"))
        val glow = GradientDrawable().apply {
            gradientType = GradientDrawable.RADIAL_GRADIENT
            gradientRadius = K.pxf(820f)
            setGradientCenter(0.78f, 0.28f)
            colors = intArrayOf(K.withAlpha(a, 0.82f), Color.TRANSPARENT)
        }
        val base = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(b, Color.parseColor("#050507")))
        bgBase.background = LayerDrawable(arrayOf<Drawable>(base, glow))
        val u = img ?: ""
        if (u != bgUrl) {
            bgUrl = u
            main.removeCallbacks(bgRun)
            main.postDelayed(bgRun, 220)
        }
    }

    private fun applyBgImage() {
        val u = bgUrl
        if (u.isBlank() || !u.startsWith("http")) {
            bgImg.animate().alpha(0f).setDuration(200).start(); return
        }
        bgImg.animate().cancel(); bgImg.alpha = 1f
        try {
            Glide.with(bgImg).load(if (u.contains("image.tmdb.org")) Img.tmdb(u, "w1280") else u)
                .override(K.px(1280), K.px(720)).centerCrop()
                .format(DecodeFormat.PREFER_RGB_565)
                .diskCacheStrategy(DiskCacheStrategy.RESOURCE)
                .transition(DrawableTransitionOptions.with(DrawableCrossFadeFactory.Builder(260).setCrossFadeEnabled(true).build()))
                .into(bgImg)
        } catch (_: Exception) { }
    }

    private val toastOff = Runnable { toastV.animate().alpha(0f).setDuration(200).start() }
    fun toast(msg: String) {
        if (msg.isBlank()) return
        toastV.text = msg
        toastV.animate().cancel(); toastV.alpha = 1f
        main.removeCallbacks(toastOff); main.postDelayed(toastOff, 2600)
    }
}

/** Petit indicateur de chargement (arc qui tourne) */
class Spinner(ctx: Context) : View(ctx) {
    private val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
    private var angle = 0f
    var color = Color.WHITE
        set(v) { field = v; invalidate() }
    private val anim = ValueAnimator.ofFloat(0f, 360f).apply {
        duration = 900; repeatCount = ValueAnimator.INFINITE; interpolator = LinearInterpolator()
        addUpdateListener { angle = it.animatedValue as Float; invalidate() }
    }
    fun start() { if (!anim.isStarted) anim.start() }
    fun stop() { anim.cancel() }
    override fun onDraw(c: Canvas) {
        val sw = K.pxf(3.5f); p.strokeWidth = sw
        val r = RectF(sw, sw, width - sw, height - sw)
        p.color = K.white(0.2f); c.drawArc(r, 0f, 360f, false, p)
        p.color = color; c.drawArc(r, angle - 90f, 100f, false, p)
    }
}

/** Écran de chargement de la lecture (maquettes 8 et 9) */
@SuppressLint("ViewConstructor")
class LoadingOverlay(ctx: Context) : FrameLayout(ctx) {
    private val bg = View(ctx)
    private val img = ImageView(ctx)
    private val kick = K.text(ctx, 15f, K.white(0.7f), 600)
    private val title = K.text(ctx, 92f, Color.WHITE, 400, 2)
    private val metaRow = LinearLayout(ctx)
    private val spin = Spinner(ctx)
    private val msg = K.text(ctx, 19f, Color.WHITE, 500, 2)
    private val hint = K.text(ctx, 15f, K.white(0.55f))
    private val banner = K.text(ctx, 17f, Color.WHITE, 500, 2)

    init {
        setBackgroundColor(Color.BLACK)
        isClickable = true
        addView(bg, K.lp(K.MATCH, K.MATCH))
        img.scaleType = ImageView.ScaleType.CENTER_CROP
        addView(img, K.lp(K.MATCH, K.MATCH))
        addView(View(ctx).apply {
            background = LayerDrawable(arrayOf<Drawable>(
                GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(K.black(0.75f), K.black(0.3f), K.black(0.15f))),
                GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, intArrayOf(K.black(0.85f), K.black(0.2f), Color.TRANSPARENT))))
        }, K.lp(K.MATCH, K.MATCH))
        val col = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
        kick.text = "LECTURE"; kick.letterSpacing = 0.08f
        col.addView(kick)
        col.addView(title, LinearLayout.LayoutParams(K.px(1100), K.WRAP).apply { topMargin = K.px(12) })
        metaRow.orientation = LinearLayout.HORIZONTAL; metaRow.gravity = Gravity.CENTER_VERTICAL
        col.addView(metaRow, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(12) })
        addView(col, LayoutParams(K.WRAP, K.WRAP, Gravity.BOTTOM).apply { leftMargin = K.px(80); bottomMargin = K.px(150) })
        val row = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        row.addView(spin, LinearLayout.LayoutParams(K.px(34), K.px(34)))
        row.addView(msg, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(16) })
        addView(row, LayoutParams(K.WRAP, K.WRAP, Gravity.BOTTOM).apply { leftMargin = K.px(80); bottomMargin = K.px(70) })
        hint.text = "Retour pour annuler"
        addView(hint, LayoutParams(K.WRAP, K.WRAP, Gravity.BOTTOM or Gravity.END).apply { rightMargin = K.px(80); bottomMargin = K.px(76) })
        banner.setPadding(K.px(24), K.px(14), K.px(24), K.px(14))
        banner.background = K.round(Color.argb(247, 36, 36, 44), 18f, 1, K.white(0.12f))
        banner.visibility = View.GONE
        addView(banner, LayoutParams(K.WRAP, K.WRAP, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply { topMargin = K.px(34) })
    }

    fun show(r: JSONObject) {
        banner.visibility = View.GONE
        bg.background = K.grad(K.color(r.optString("c1"), Color.DKGRAY), K.color(r.optString("c2"), Color.BLACK))
        title.text = r.optString("t")
        titleStyle(title, r.optString("f"), 2.8f)
        setMeta(r)
        msg.text = "Démarrage de la vidéo…"; msg.setTextColor(Color.WHITE); spin.color = Color.WHITE
        val u = r.optString("bd").ifEmpty { r.optString("img") }
        if (u.startsWith("http")) {
            try {
                Glide.with(img).load(if (u.contains("image.tmdb.org")) Img.tmdb(u, "w1280") else u).override(K.px(1280), K.px(720)).centerCrop()
                    .format(DecodeFormat.PREFER_RGB_565).into(img)
            } catch (_: Exception) {}
        } else img.setImageDrawable(null)
        alpha = 0f; visibility = View.VISIBLE
        animate().alpha(1f).setDuration(150).start()
        spin.start()
    }

    private fun setMeta(r: JSONObject) {
        metaRow.removeAllViews()
        val qq = r.optString("q")
        if (qq.isNotEmpty()) metaRow.addView(qBadge(context, qq).apply { (layoutParams as LinearLayout.LayoutParams).rightMargin = K.px(12) })
        val m = K.text(context, 18f, K.white(0.82f)); m.text = r.optString("src")
        metaRow.addView(m)
    }

    fun update(o: JSONObject) {
        if (o.has("msg")) msg.text = o.optString("msg")
        val warn = o.optBoolean("warn")
        spin.color = if (warn) Color.parseColor("#ffb340") else Color.WHITE
        if (o.has("banner")) {
            val b = o.optString("banner")
            banner.text = b; banner.visibility = if (b.isEmpty()) View.GONE else View.VISIBLE
        }
        if (o.has("q") || o.has("src")) setMeta(o)
    }

    fun hide() {
        spin.stop()
        visibility = View.GONE
    }
}
