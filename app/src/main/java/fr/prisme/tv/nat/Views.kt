package fr.prisme.tv.nat

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewOutlineProvider
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.bumptech.glide.Glide
import com.bumptech.glide.load.DecodeFormat
import com.bumptech.glide.load.engine.DiskCacheStrategy
import com.bumptech.glide.load.resource.drawable.DrawableTransitionOptions
import fr.prisme.tv.R
import org.json.JSONObject

/** Un élément que la télécommande peut sélectionner */
interface Foc {
    fun foc(on: Boolean)
}

fun View.roundClip(radiusUnits: Float) {
    val r = K.pxf(radiusUnits)
    outlineProvider = object : ViewOutlineProvider() {
        override fun getOutline(v: View, o: Outline) { o.setRoundRect(0, 0, v.width, v.height, r) }
    }
    clipToOutline = true
}

fun View.circleClip() {
    outlineProvider = object : ViewOutlineProvider() {
        override fun getOutline(v: View, o: Outline) { o.setOval(0, 0, v.width, v.height) }
    }
    clipToOutline = true
}

/** Agrandissement animé par la puce graphique (pas de recalcul de mise en page) */
fun View.lift(on: Boolean, scale: Float, dy: Float = 0f) {
    animate().cancel()
    animate().scaleX(if (on) scale else 1f).scaleY(if (on) scale else 1f)
        .translationY(if (on) K.pxf(dy) else 0f).setDuration(140).start()
}

object Img {
    /** Taille TMDB adaptée (les affiches d'origine peuvent faire plusieurs Mo) */
    fun tmdb(u: String, size: String): String =
        u.replace(Regex("(image\\.tmdb\\.org/t/p/)(original|w\\d+)/"), "$1$size/")

    fun load(v: ImageView, url: String?, w: Int, h: Int, fade: Boolean = true) {
        if (url.isNullOrBlank() || !url.startsWith("http")) {
            try { Glide.with(v).clear(v) } catch (_: Exception) {}
            v.setImageDrawable(null); return
        }
        try {
            var r = Glide.with(v).load(url).override(w, h).centerCrop()
                .format(DecodeFormat.PREFER_RGB_565)
                .diskCacheStrategy(DiskCacheStrategy.RESOURCE)
            if (fade) r = r.transition(DrawableTransitionOptions.withCrossFade(160))
            r.into(v)
        } catch (_: Exception) { }
    }
}

fun qBadge(ctx: Context, q: String, h: Float = 24f, size: Float = 13f): TextView =
    K.text(ctx, size, Color.BLACK, 800).apply {
        text = q
        gravity = Gravity.CENTER
        setPadding(K.px(8), 0, K.px(8), 0)
        background = K.round(K.qualColor(q), 6f)
        layoutParams = LinearLayout.LayoutParams(K.WRAP, K.px(h))
    }

/** Poster de secours (dégradé + titre), comme l'appli actuelle quand l'affiche manque */
fun titleStyle(tv: TextView, f: String, scale: Float = 1f) {
    tv.setAllCaps(false); tv.letterSpacing = 0f
    when (f) {
        "bebas" -> { tv.typeface = K.font("bebas"); tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, K.pxf(30f * scale)); tv.setAllCaps(false); tv.letterSpacing = 0.02f }
        "serif" -> { tv.typeface = K.font("serif", 700, true); tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, K.pxf(20f * scale)) }
        "black" -> { tv.typeface = K.font("black"); tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, K.pxf(15f * scale)); tv.setAllCaps(true) }
        else -> { tv.typeface = K.font("outfit", 300); tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, K.pxf(17f * scale)); tv.setAllCaps(true); tv.letterSpacing = 0.12f }
    }
}

// ---------------------------------------------------------------------------------------------------- Affiche
@SuppressLint("ViewConstructor")
class PosterCard(ctx: Context, val rank: Boolean = false, val pw: Float = 138f, val ph: Float = 207f) : LinearLayout(ctx), Foc {
    val poster = FrameLayout(ctx)
    private val kick = K.text(ctx, 10f, K.white(0.8f), 700)
    private val title = K.text(ctx, 20f, Color.WHITE, 400, 5)
    private val img = ImageView(ctx)
    private val badge = K.text(ctx, 10f, Color.WHITE, 800)
    private val prog = FrameLayout(ctx)
    private val progBar = View(ctx)
    private val border = View(ctx)
    private val cap = K.text(ctx, 14f, K.white(0.6f), 400)
    private val num = OutlineNum(ctx)
    private var root = this
    var item: JSONObject? = null

    init {
        orientation = VERTICAL
        clipChildren = false; clipToPadding = false
        val wrap: FrameLayout? = if (rank) FrameLayout(ctx).apply { clipChildren = false } else null
        poster.roundClip(12f)
        poster.addView(View(ctx).apply { background = K.grad(K.black(0f), K.black(0.55f), GradientDrawable.Orientation.TOP_BOTTOM) }, K.lp(K.MATCH, K.MATCH))
        poster.addView(kick, FrameLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(12); topMargin = K.px(12) })
        kick.letterSpacing = 0.18f
        poster.addView(title, FrameLayout.LayoutParams(K.MATCH, K.WRAP, Gravity.BOTTOM).apply { leftMargin = K.px(12); rightMargin = K.px(10); bottomMargin = K.px(12) })
        img.scaleType = ImageView.ScaleType.CENTER_CROP
        poster.addView(img, K.lp(K.MATCH, K.MATCH))
        badge.text = "AJOUTÉ RÉCEMMENT"; badge.gravity = Gravity.CENTER; badge.letterSpacing = 0.06f
        badge.setBackgroundColor(Color.parseColor("#0a84ff"))
        poster.addView(badge, FrameLayout.LayoutParams(K.MATCH, K.px(22)))
        prog.background = K.round(K.white(0.3f), 3f); prog.roundClip(3f)
        progBar.setBackgroundColor(Color.WHITE)
        prog.addView(progBar, FrameLayout.LayoutParams(0, K.MATCH))
        poster.addView(prog, FrameLayout.LayoutParams(K.MATCH, K.px(5), Gravity.BOTTOM).apply { leftMargin = K.px(12); rightMargin = K.px(12); bottomMargin = K.px(10) })
        border.background = K.round(Color.TRANSPARENT, 12f, 3, Color.WHITE)
        border.visibility = View.INVISIBLE
        poster.addView(border, K.lp(K.MATCH, K.MATCH))
        if (wrap != null) {
            num.layoutParams = FrameLayout.LayoutParams(K.px(120), K.px(150), Gravity.BOTTOM or Gravity.START).apply { leftMargin = -K.px(4) }
            wrap.addView(num)
            wrap.addView(poster, FrameLayout.LayoutParams(K.px(pw), K.px(ph)).apply { leftMargin = K.px(68) })
            addView(wrap, LayoutParams(K.px(pw + 68), K.px(ph)))
            cap.setPadding(K.px(68), 0, 0, 0)
        } else {
            addView(poster, LayoutParams(K.px(pw), K.px(ph)))
        }
        addView(cap, LayoutParams(if (rank) K.px(pw + 68) else K.px(pw), K.WRAP).apply { topMargin = K.px(10) })
    }

    fun bind(it: JSONObject, rankNo: Int = 0) {
        item = it
        val c1 = K.color(it.optString("c1"), Color.parseColor("#2b3245"))
        val c2 = K.color(it.optString("c2"), Color.parseColor("#0a0b10"))
        poster.background = K.grad(c1, c2, GradientDrawable.Orientation.TL_BR)
        kick.text = if (it.optString("ty") == "s") "SÉRIE" else it.optInt("y").takeIf { y -> y > 0 }?.toString() ?: ""
        title.text = it.optString("t")
        titleStyle(title, it.optString("f"))
        cap.text = it.optString("t")
        val nw = it.optBoolean("nw")
        badge.visibility = if (nw) View.VISIBLE else View.GONE
        kick.visibility = if (nw) View.INVISIBLE else View.VISIBLE
        val pr = it.optDouble("pr", 0.0)
        prog.visibility = if (pr > 0.01) View.VISIBLE else View.GONE
        if (pr > 0.01) {
            val w = (K.px(pw - 24) * pr).toInt()
            progBar.layoutParams = FrameLayout.LayoutParams(w, K.MATCH)
        }
        if (rank) num.text = rankNo.toString()
        val url = it.optString("img")
        Img.load(img, if (url.contains("image.tmdb.org")) Img.tmdb(url, "w342") else url, K.px(pw * 1.1f), K.px(ph * 1.1f))
    }

    override fun foc(on: Boolean) {
        poster.lift(on, 1.1f, -4f)
        if (rank) num.setActive(on)
        border.visibility = if (on) View.VISIBLE else View.INVISIBLE
        poster.elevation = if (on) K.pxf(12f) else 0f
        cap.setTextColor(if (on) Color.WHITE else K.white(0.6f))
        cap.animate().translationY(if (on) K.pxf(10f) else 0f).setDuration(140).start()
    }
}

/** Grand numéro du Top 10, en contour */
class OutlineNum(ctx: Context) : View(ctx) {
    var text = ""
        set(v) { field = v; invalidate() }
    private var active = false
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = K.pxf(2f); typeface = K.font("black") }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL; typeface = K.font("black") }
    fun setActive(on: Boolean) { active = on; invalidate() }
    override fun onDraw(c: Canvas) {
        val size = if (text.length > 1) K.pxf(116f) else K.pxf(146f)
        stroke.textSize = size; fill.textSize = size
        stroke.color = if (active) Color.WHITE else K.white(0.55f)
        fill.color = if (active) K.white(0.15f) else K.white(0.06f)
        val y = height - K.pxf(4f)
        fill.letterSpacing = -0.08f; stroke.letterSpacing = -0.08f
        c.drawText(text, 0f, y, fill)
        c.drawText(text, 0f, y, stroke)
    }
}

// ---------------------------------------------------------------------------------------------------- Tuile de genre
@SuppressLint("ViewConstructor")
class Tile(ctx: Context, val tw: Float, val th: Float = 112f) : FrameLayout(ctx), Foc {
    private val count = K.text(ctx, 13f, K.white(0.78f), 600)
    private val name = K.text(ctx, 24f, Color.WHITE, 700, 2)
    private val border = View(ctx)
    var key = ""

    init {
        roundClip(16f)
        addView(count, LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(18); topMargin = K.px(16) })
        addView(name, LayoutParams(K.MATCH, K.WRAP, Gravity.BOTTOM).apply { leftMargin = K.px(18); rightMargin = K.px(14); bottomMargin = K.px(14) })
        border.background = K.round(Color.TRANSPARENT, 16f, 3, Color.WHITE); border.visibility = View.INVISIBLE
        addView(border, K.lp(K.MATCH, K.MATCH))
    }

    fun bind(g: JSONObject, unit: String) {
        key = g.optString("k")
        name.text = g.optString("n")
        val n = g.optInt("c")
        count.text = "$n $unit"
        val c1 = K.color(g.optString("c1"), Color.GRAY)
        val c2 = K.color(g.optString("c2"), Color.BLACK)
        val base = K.grad(K.withAlpha(c1, 0.42f), c2, GradientDrawable.Orientation.TL_BR)
        val glow = GradientDrawable().apply {
            gradientType = GradientDrawable.RADIAL_GRADIENT
            gradientRadius = K.pxf(tw * 0.8f)
            setGradientCenter(0.88f, 0.05f)
            colors = intArrayOf(K.withAlpha(c1, 0.8f), Color.TRANSPARENT)
        }
        background = LayerDrawable(arrayOf<Drawable>(base, glow))
    }

    override fun foc(on: Boolean) {
        lift(on, 1.06f)
        border.visibility = if (on) View.VISIBLE else View.INVISIBLE
        elevation = if (on) K.pxf(10f) else 0f
    }
}

// ---------------------------------------------------------------------------------------------------- Pastille et bouton
@SuppressLint("ViewConstructor")
class Chip(ctx: Context, label: String, val size: Float = 17f, h: Float = 42f) : TextView(ctx), Foc {
    var selected2 = false
        set(v) { field = v; paint() }
    private var focused2 = false
    var tagKey = ""

    init {
        text = label
        typeface = K.ui(600)
        setTextSize(TypedValue.COMPLEX_UNIT_PX, K.pxf(size))
        includeFontPadding = false
        gravity = Gravity.CENTER
        setPadding(K.px(20), 0, K.px(20), 0)
        layoutParams = LinearLayout.LayoutParams(K.WRAP, K.px(h))
        paint()
    }

    private fun paint() {
        when {
            focused2 -> { background = K.round(Color.WHITE, 21f); setTextColor(Color.BLACK) }
            selected2 -> { background = K.round(K.white(0.22f), 21f); setTextColor(Color.WHITE) }
            else -> { background = K.round(K.white(0.08f), 21f); setTextColor(K.white(0.7f)) }
        }
    }

    override fun foc(on: Boolean) { focused2 = on; paint(); lift(on, 1.07f) }
}

@SuppressLint("ViewConstructor")
class Btn(ctx: Context, label: String?, icon: Int, val round: Boolean = false) : LinearLayout(ctx), Foc {
    private val ic = ImageView(ctx)
    val tv = K.text(ctx, 21f, Color.WHITE, 600)

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER
        if (icon != 0) {
            ic.setImageResource(icon)
            addView(ic, LayoutParams(K.px(if (round) 22 else 20), K.px(if (round) 22 else 20)))
        }
        if (label != null) {
            tv.text = label
            addView(tv, LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = if (icon != 0) K.px(10) else 0 })
            setPadding(K.px(30), 0, K.px(30), 0)
        }
        layoutParams = LayoutParams(if (round) K.px(58) else K.WRAP, K.px(58))
        paint(false)
    }

    fun setLabel(s: String) { tv.text = s }

    private fun paint(on: Boolean) {
        val bg = if (on) Color.WHITE else Color.argb(235, 62, 62, 72)
        background = if (round) GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(bg) } else K.round(bg, 14f)
        val fg = if (on) Color.BLACK else Color.WHITE
        tv.setTextColor(fg); ic.setColorFilter(fg)
    }

    override fun foc(on: Boolean) { paint(on); lift(on, 1.07f); elevation = if (on) K.pxf(10f) else 0f }
}

// ---------------------------------------------------------------------------------------------------- Distribution
@SuppressLint("ViewConstructor")
class CastCard(ctx: Context) : LinearLayout(ctx), Foc {
    private val av = FrameLayout(ctx)
    private val ini = K.text(ctx, 36f, K.white(0.92f), 600)
    private val img = ImageView(ctx)
    private val ring = View(ctx)
    private val name = K.text(ctx, 15f, Color.WHITE, 600, 2)
    private val role = K.text(ctx, 13f, K.white(0.55f), 400, 1)
    var actorId = ""

    init {
        orientation = VERTICAL
        gravity = Gravity.CENTER_HORIZONTAL
        clipChildren = false
        av.circleClip()
        ini.gravity = Gravity.CENTER
        av.addView(ini, K.lp(K.MATCH, K.MATCH))
        img.scaleType = ImageView.ScaleType.CENTER_CROP
        av.addView(img, K.lp(K.MATCH, K.MATCH))
        ring.background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.TRANSPARENT); setStroke(K.px(3), Color.WHITE) }
        ring.visibility = View.INVISIBLE
        av.addView(ring, K.lp(K.MATCH, K.MATCH))
        addView(av, LayoutParams(K.px(118), K.px(118)))
        name.gravity = Gravity.CENTER; role.gravity = Gravity.CENTER
        addView(name, LayoutParams(K.px(132), K.WRAP).apply { topMargin = K.px(12) })
        addView(role, LayoutParams(K.px(132), K.WRAP).apply { topMargin = K.px(3) })
    }

    fun bind(c: JSONObject) {
        actorId = c.optString("id")
        val n = c.optString("n")
        name.text = n
        role.text = c.optString("r")
        role.visibility = if (role.text.isNullOrEmpty()) View.GONE else View.VISIBLE
        ini.text = n.split(Regex("[\\s-]+")).filter { it.isNotEmpty() && it[0].isUpperCase() }.take(2).joinToString("") { it.substring(0, 1) }
        val h = (actorId.hashCode() and 0x7fffffff) % 360
        av.background = K.grad(Color.HSVToColor(floatArrayOf(h.toFloat(), 0.5f, 0.75f)), Color.HSVToColor(floatArrayOf(h.toFloat(), 0.55f, 0.22f)))
        Img.load(img, c.optString("ph"), K.px(118), K.px(118))
    }

    override fun foc(on: Boolean) {
        av.lift(on, 1.12f)
        ring.visibility = if (on) View.VISIBLE else View.INVISIBLE
        name.animate().translationY(if (on) K.pxf(8f) else 0f).setDuration(140).start()
    }
}

// ---------------------------------------------------------------------------------------------------- Carte source
@SuppressLint("ViewConstructor")
class SourceCard(ctx: Context) : LinearLayout(ctx), Foc {
    private var nc = false
    private var sel = false
    private val rows = ArrayList<TextView>()
    var srcId = ""

    init { orientation = VERTICAL; setPadding(K.px(20), K.px(18), K.px(20), K.px(18)) }

    fun bind(s: JSONObject) {
        removeAllViews(); rows.clear()
        srcId = s.optString("id")
        nc = !s.optBoolean("ok", true)
        sel = s.optBoolean("def")
        val head = LinearLayout(context).apply { orientation = HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        head.addView(qBadge(context, s.optString("q"), 30f, 14f))
        val pn = K.text(context, 17f, Color.WHITE, 700)
        pn.text = s.optString("pl"); rows.add(pn)
        head.addView(pn, LayoutParams(0, K.WRAP, 1f).apply { leftMargin = K.px(10) })
        if (sel) {
            val d = K.text(context, 12f, Color.WHITE, 700); d.text = "Par défaut"
            d.setPadding(K.px(8), K.px(3), K.px(8), K.px(3)); d.background = K.round(K.white(0.18f), 6f)
            head.addView(d); rows.add(d)
        }
        addView(head)
        val sn = K.text(context, 12f, K.white(0.5f))
        sn.typeface = android.graphics.Typeface.MONOSPACE
        sn.text = s.optString("name")
        addView(sn, LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(10); bottomMargin = K.px(8) })
        fun row(k: String, v: String) {
            if (v.isBlank()) return
            val l = LinearLayout(context).apply { orientation = HORIZONTAL }
            val a = K.text(context, 14f, K.white(0.5f)); a.text = k
            val b = K.text(context, 14f, Color.WHITE, 400, 3); b.text = v
            l.addView(a, LayoutParams(K.px(96), K.WRAP)); l.addView(b, LayoutParams(0, K.WRAP, 1f))
            rows.add(b)
            addView(l, LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(4) })
        }
        row("Vidéo", s.optString("codec"))
        row("Audio", s.optString("audio"))
        row("Sous-titres", s.optString("subs"))
        row("Format", s.optString("fmt"))
        if (nc) {
            val w = K.text(context, 13f, Color.parseColor("#ffb340"), 500, 2)
            w.text = "Non compatible : ce Fire Stick lit jusqu'en 1080p"
            addView(w, LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(8) })
        }
        alpha = if (nc) 0.55f else 1f
        paint(false)
    }

    private fun paint(on: Boolean) {
        background = when {
            on -> K.round(Color.WHITE, 18f)
            sel -> K.round(K.white(0.08f), 18f, 2, K.white(0.35f))
            else -> K.round(K.white(0.08f), 18f)
        }
        rows.forEach { it.setTextColor(if (on) Color.BLACK else Color.WHITE) }
    }

    override fun foc(on: Boolean) { paint(on); lift(on, 1.05f); alpha = if (on) 1f else if (nc) 0.55f else 1f }
}

// ---------------------------------------------------------------------------------------------------- Épisode
@SuppressLint("ViewConstructor")
class EpCard(ctx: Context) : LinearLayout(ctx), Foc {
    private val th = FrameLayout(ctx)
    private val img = ImageView(ctx)
    private val lb = K.text(ctx, 13f, Color.WHITE, 700)
    private val q = FrameLayout(ctx)
    private val prog = FrameLayout(ctx)
    private val progBar = View(ctx)
    private val border = View(ctx)
    private val t = K.text(ctx, 16f, Color.WHITE, 600)
    private val d = K.text(ctx, 13f, K.white(0.55f))
    var ep: JSONObject? = null

    init {
        orientation = VERTICAL
        clipChildren = false
        th.roundClip(12f)
        img.scaleType = ImageView.ScaleType.CENTER_CROP
        th.addView(img, K.lp(K.MATCH, K.MATCH))
        th.addView(View(ctx).apply { background = K.grad(K.black(0f), K.black(0.5f), GradientDrawable.Orientation.TOP_BOTTOM) }, K.lp(K.MATCH, K.MATCH))
        lb.letterSpacing = 0.1f
        th.addView(lb, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.BOTTOM).apply { leftMargin = K.px(12); bottomMargin = K.px(12) })
        th.addView(q, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.END).apply { rightMargin = K.px(10); topMargin = K.px(10) })
        prog.background = K.round(K.white(0.3f), 2f); prog.roundClip(2f)
        progBar.setBackgroundColor(Color.WHITE)
        prog.addView(progBar, FrameLayout.LayoutParams(0, K.MATCH))
        th.addView(prog, FrameLayout.LayoutParams(K.MATCH, K.px(4), Gravity.BOTTOM).apply { leftMargin = K.px(12); rightMargin = K.px(12); bottomMargin = K.px(5) })
        border.background = K.round(Color.TRANSPARENT, 12f, 3, Color.WHITE); border.visibility = View.INVISIBLE
        th.addView(border, K.lp(K.MATCH, K.MATCH))
        addView(th, LayoutParams(K.px(260), K.px(146)))
        addView(t, LayoutParams(K.px(260), K.WRAP).apply { topMargin = K.px(12) })
        addView(d, LayoutParams(K.px(260), K.WRAP).apply { topMargin = K.px(3) })
    }

    fun bind(e: JSONObject, label: String, c1: Int, c2: Int) {
        ep = e
        th.background = K.grad(c1, c2)
        lb.text = label
        t.text = e.optString("t")
        d.text = e.optString("d")
        q.removeAllViews()
        val qq = e.optString("q")
        if (qq.isNotEmpty()) q.addView(qBadge(context, qq, 22f, 11f))
        val pr = e.optDouble("pr", 0.0)
        prog.visibility = if (pr > 0.01) View.VISIBLE else View.GONE
        progBar.layoutParams = FrameLayout.LayoutParams((K.px(236) * pr).toInt(), K.MATCH)
        Img.load(img, e.optString("img"), K.px(286), K.px(160))
    }

    override fun foc(on: Boolean) {
        th.lift(on, 1.08f)
        border.visibility = if (on) View.VISIBLE else View.INVISIBLE
        th.elevation = if (on) K.pxf(10f) else 0f
        t.animate().translationY(if (on) K.pxf(8f) else 0f).setDuration(140).start()
        d.animate().translationY(if (on) K.pxf(8f) else 0f).setDuration(140).start()
    }
}

// ---------------------------------------------------------------------------------------------------- Onglets
@SuppressLint("ViewConstructor")
class TabItem(ctx: Context, val key: String, label: String?, icon: Int) : LinearLayout(ctx), Foc {
    private val tv = K.text(ctx, 21f, K.white(0.72f), 500)
    private val ic = ImageView(ctx)
    var sel = false
        set(v) { field = v; paint(false) }

    init {
        gravity = Gravity.CENTER
        if (label != null) { tv.text = label; addView(tv); setPadding(K.px(24), 0, K.px(24), 0) }
        else { ic.setImageResource(icon); addView(ic, LayoutParams(K.px(22), K.px(22))); setPadding(K.px(16), 0, K.px(16), 0) }
        paint(false)
    }

    private fun paint(on: Boolean) {
        val fg = if (on) Color.BLACK else if (sel) Color.WHITE else K.white(0.72f)
        background = if (on) K.round(Color.WHITE, 30f) else if (sel) K.round(K.white(0.2f), 30f) else null
        tv.setTextColor(fg); ic.setColorFilter(fg)
    }

    override fun foc(on: Boolean) { paint(on); lift(on, 1.08f) }
}

class TabBar(ctx: Context) : LinearLayout(ctx) {
    val items = listOf(
        TabItem(ctx, "films", "Films", 0), TabItem(ctx, "series", "Séries", 0), TabItem(ctx, "live", "TV en direct", 0),
        TabItem(ctx, "search", null, R.drawable.ic_search), TabItem(ctx, "settings", null, R.drawable.ic_settings)
    )

    init {
        orientation = HORIZONTAL
        setPadding(K.px(6), K.px(6), K.px(6), K.px(6))
        background = K.round(Color.argb(235, 26, 26, 32), 40f, 1, K.white(0.1f))
        clipChildren = false
        items.forEach { addView(it, LayoutParams(K.WRAP, K.px(44)).apply { rightMargin = K.px(4) }) }
    }

    fun select(key: String) { items.forEach { it.sel = it.key == key } }
}
