package fr.prisme.tv.nat

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.text.TextPaint
import android.text.TextUtils
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Fond dessiné partout sauf dans un rectangle arrondi : la vidéo, posée dessous, y apparaît */
class HoleBg(ctx: Context) : View(ctx) {
    var hole: RectF? = null
        set(v) { field = v; invalidate() }
    var radius = 0f
    var bg: Drawable? = null
        set(v) { field = v; invalidate() }
    private val path = Path()
    override fun onDraw(c: Canvas) {
        val b = bg ?: return
        c.save()
        hole?.let { path.reset(); path.addRoundRect(it, radius, radius, Path.Direction.CW); c.clipOutPath(path) }
        b.setBounds(0, 0, width, height); b.draw(c)
        c.restore()
    }
}

/** Fond de la TV en direct (bleu nuit) */
fun liveBg(): Drawable {
    val base = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(Color.parseColor("#0b1020"), Color.parseColor("#050507")))
    val glow = GradientDrawable().apply {
        gradientType = GradientDrawable.RADIAL_GRADIENT
        gradientRadius = K.pxf(700f)
        setGradientCenter(0.78f, 0.3f)
        colors = intArrayOf(Color.parseColor("#331e4fd8"), Color.TRANSPARENT)
    }
    return LayerDrawable(arrayOf<Drawable>(base, glow))
}

fun clockText(): String = SimpleDateFormat("HH:mm", Locale.FRANCE).format(Date())

/** Logo de chaîne : image du fournisseur, sinon le nom sur la couleur de la chaîne */
@SuppressLint("ViewConstructor")
class ChLogo(ctx: Context, private val w: Float, private val h: Float, size: Float) : FrameLayout(ctx) {
    private val t = K.text(ctx, size, Color.WHITE, 700, 2)
    private val img = ImageView(ctx)
    private var url = ""
    private var target: CustomTarget<Drawable>? = null

    init {
        roundClip(8f)
        t.gravity = Gravity.CENTER
        t.setPadding(K.px(4), 0, K.px(4), 0)
        addView(t, K.lp(K.MATCH, K.MATCH))
        img.scaleType = ImageView.ScaleType.FIT_CENTER
        img.setPadding(K.px(5), K.px(4), K.px(5), K.px(4))
        addView(img, K.lp(K.MATCH, K.MATCH))
    }

    fun bind(o: JSONObject) {
        val col = K.color(o.optString("col"), Color.DKGRAY)
        t.text = o.optString("n")
        val u = o.optString("logo")
        if (u == url && u.isNotEmpty()) return
        url = u
        t.visibility = View.VISIBLE
        background = ColorDrawable(col)
        img.setImageDrawable(null)
        target?.let { try { Glide.with(img).clear(it) } catch (_: Exception) {} }
        target = null
        if (!u.startsWith("http")) return
        val tg = object : CustomTarget<Drawable>(K.px(w * 1.5f), K.px(h * 1.5f)) {
            override fun onResourceReady(resource: Drawable, transition: Transition<in Drawable>?) {
                if (url != u) return
                img.setImageDrawable(resource); t.visibility = View.INVISIBLE
                background = ColorDrawable(Color.argb(255, 34, 34, 42))
            }
            override fun onLoadCleared(placeholder: Drawable?) { img.setImageDrawable(null) }
        }
        target = tg
        try { Glide.with(img).load(u).fitCenter().into(tg) } catch (_: Exception) {}
    }
}

/** Petite barre d'avancement du programme */
class Bar(ctx: Context, private val dark: Boolean = false) : View(ctx) {
    var pct = 0f
        set(v) { field = v.coerceIn(0f, 1f); invalidate() }
    var onLight = false
        set(v) { field = v; invalidate() }
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)
    override fun onDraw(c: Canvas) {
        val r = height / 2f
        p.color = if (onLight) K.black(0.12f) else K.white(if (dark) 0.2f else 0.14f)
        c.drawRoundRect(0f, 0f, width.toFloat(), height.toFloat(), r, r, p)
        p.color = if (onLight) Color.BLACK else if (dark) Color.WHITE else K.white(0.7f)
        c.drawRoundRect(0f, 0f, width * pct, height.toFloat(), r, r, p)
    }
}

/** Ligne de chaîne (numéro, logo, nom, qualité, programme en cours) */
@SuppressLint("ViewConstructor")
class ChRow(ctx: Context, val rw: Float = 376f, val rh: Float = 68f) : LinearLayout(ctx) {
    private val num = K.text(ctx, 16f, K.white(0.5f))
    private val logo = ChLogo(ctx, 76f, 44f, 13f)
    private val name = K.text(ctx, 17f, Color.WHITE, 600)
    private val heart = K.text(ctx, 13f, K.white(0.7f))
    private val qb = FrameLayout(ctx)
    private val pg = K.text(ctx, 13.5f, K.white(0.58f))
    private val bar = Bar(ctx)
    var item: JSONObject? = null
    private var on = false

    init {
        orientation = HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
        setPadding(K.px(14), 0, K.px(14), 0)
        num.gravity = Gravity.END
        addView(num, LayoutParams(K.px(30), K.WRAP))
        addView(logo, LayoutParams(K.px(76), K.px(44)).apply { leftMargin = K.px(12) })
        val col = LinearLayout(ctx).apply { orientation = VERTICAL }
        val top = LinearLayout(ctx).apply { orientation = HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        name.maxWidth = K.px(150)
        top.addView(name, LayoutParams(K.WRAP, K.WRAP))
        top.addView(heart, LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(6) })
        top.addView(qb, LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(8) })
        col.addView(top)
        col.addView(pg, LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(3) })
        col.addView(bar, LayoutParams(K.MATCH, K.px(3)).apply { topMargin = K.px(6) })
        addView(col, LayoutParams(0, K.WRAP, 1f).apply { leftMargin = K.px(12) })
        paint()
    }

    fun bind(o: JSONObject, focused: Boolean) {
        item = o
        num.text = o.optInt("num").takeIf { it > 0 }?.toString() ?: ""
        logo.bind(o)
        name.text = o.optString("n")
        heart.text = if (o.optBoolean("fav")) "♥" else ""
        qb.removeAllViews()
        val q = o.optString("q")
        if (q.isNotEmpty()) qb.addView(qBadge(context, q, 20f, 11.5f))
        pg.text = "${o.optString("s")} · ${o.optString("pg")}"
        bar.pct = o.optInt("pct") / 100f
        setFoc(focused)
    }

    fun setFoc(f: Boolean) {
        if (f == on && background != null) return
        on = f; paint()
        val was = K.instant; K.instant = true
        try { lift(f, 1.03f) } finally { K.instant = was }
        elevation = if (f) K.pxf(8f) else 0f
    }

    private fun paint() {
        background = K.round(if (on) Color.WHITE else K.white(0.05f), 14f)
        num.setTextColor(if (on) K.black(0.6f) else K.white(0.5f))
        name.setTextColor(if (on) Color.BLACK else Color.WHITE)
        heart.setTextColor(if (on) K.black(0.6f) else K.white(0.7f))
        pg.setTextColor(if (on) K.black(0.6f) else K.white(0.58f))
        bar.onLight = on
    }
}

/** Catégorie de chaînes (colonne de gauche) */
@SuppressLint("ViewConstructor")
class CatRow(ctx: Context, val key: String, label: String, count: Int) : LinearLayout(ctx), Foc {
    private val t = K.text(ctx, 18f, K.white(0.72f), 500)
    private val c = K.text(ctx, 14f, K.white(0.45f), 500)
    var sel = false
        set(v) { field = v; paint(false) }

    init {
        orientation = HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
        setPadding(K.px(16), 0, K.px(16), 0)
        t.text = label; c.text = count.toString()
        addView(t, LayoutParams(0, K.WRAP, 1f))
        addView(c)
        paint(false)
    }

    private fun paint(on: Boolean) {
        background = if (on) K.round(Color.WHITE, 12f) else if (sel) K.round(K.white(0.1f), 12f) else null
        t.setTextColor(if (on) Color.BLACK else if (sel) Color.WHITE else K.white(0.72f))
        c.setTextColor(if (on) K.black(0.55f) else K.white(0.45f))
    }

    override fun foc(on: Boolean) { paint(on); lift(on, 1.04f) }
}

/** Liste de chaînes défilante (seules les lignes visibles existent) */
class ChList(ctx: Context, private val rw: Float, private val rh: Float, private val gap: Float) : RecyclerView(ctx) {
    var items: List<JSONObject> = emptyList()
    var fi = -1
    private val lm = LinearLayoutManager(ctx)

    init {
        layoutManager = lm
        itemAnimator = null
        clipChildren = false; clipToPadding = false
        overScrollMode = View.OVER_SCROLL_NEVER
        isFocusable = false
        descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        setPadding(K.px(8), K.px(6), K.px(8), K.px(40))
        adapter = object : Adapter<ViewHolder>() {
            override fun getItemCount() = items.size
            override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
                val r = ChRow(ctx, rw, rh)
                r.layoutParams = LayoutParams(K.px(rw), K.px(rh)).apply { bottomMargin = K.px(gap) }
                return object : ViewHolder(r) {}
            }
            override fun onBindViewHolder(h: ViewHolder, pos: Int) { (h.itemView as ChRow).bind(items[pos], pos == fi) }
        }
    }

    fun set(list: List<JSONObject>, f: Int) {
        items = list; fi = f
        adapter?.notifyDataSetChanged()
        if (f >= 0) lm.scrollToPositionWithOffset(f, K.px(rh * 2))
    }

    fun setFocus(i: Int) {
        val old = fi; fi = i
        if (old >= 0) (lm.findViewByPosition(old) as? ChRow)?.setFoc(false) ?: adapter?.notifyItemChanged(old)
        if (i < 0) return
        val v = lm.findViewByPosition(i) as? ChRow
        if (v != null) {
            v.setFoc(true)
            val pad = K.px(rh * 1.4f)
            if (v.top < pad) scrollBy(0, v.top - pad) else if (v.bottom > height - pad) scrollBy(0, v.bottom - height + pad)
        } else {
            lm.scrollToPositionWithOffset(i, K.px(rh * 2))
            adapter?.notifyItemChanged(i)
        }
    }

    fun refreshItems(list: List<JSONObject>) {
        items = list
        adapter?.notifyItemRangeChanged(0, list.size)
    }
}

/** En-tête commun : logo, onglets, heure */
class TopBar(ui: NativeUi, parent: FrameLayout) {
    val tabs = TabBar(ui.ctx)
    val clock = K.text(ui.ctx, 22f, K.white(0.85f), 500)
    init {
        val brand = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        val dot = View(ui.ctx).apply { background = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(Color.parseColor("#ff375f"), Color.parseColor("#ff9f0a"), Color.parseColor("#30d158"), Color.parseColor("#0a84ff"), Color.parseColor("#bf5af2"))).apply { cornerRadius = K.pxf(7f) } }
        brand.addView(dot, LinearLayout.LayoutParams(K.px(22), K.px(22)))
        val bt = K.text(ui.ctx, 22f, Color.WHITE, 700); bt.text = "prisme"
        brand.addView(bt, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(8) })
        parent.addView(brand, FrameLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(56); topMargin = K.px(36) })
        parent.addView(clock, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.END).apply { rightMargin = K.px(56); topMargin = K.px(36) })
        val wrap = FrameLayout(ui.ctx).apply { clipChildren = false }
        wrap.addView(tabs, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.CENTER_HORIZONTAL))
        parent.addView(wrap, FrameLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(26) })
        clock.text = clockText()
    }
}

// ==================================================================================================== TV en direct
@SuppressLint("ViewConstructor")
class LiveScreen(ui: NativeUi) : Screen(ui) {
    override val video = true
    private val bgv = HoleBg(ui.ctx)
    private val top = TopBar(ui, this)
    private val catBox = LinearLayout(ui.ctx)
    private val catScroll = ScrollView(ui.ctx)
    private val list = ChList(ui.ctx, 376f, 68f, 7f)
    private val empty = K.text(ui.ctx, 17f, K.white(0.6f), 400, 4)
    // aperçu
    private val pv = FrameLayout(ui.ctx)
    private val pvSpin = Spinner(ui.ctx)
    private val pvMsg = K.text(ui.ctx, 15f, K.white(0.75f), 500, 2)
    private val pvChip = K.text(ui.ctx, 14f, Color.WHITE, 700)
    private val pvTime = K.text(ui.ctx, 16f, K.white(0.7f))
    private val pvGenre = K.text(ui.ctx, 13f, Color.WHITE, 500)
    private val pvTitle = K.text(ui.ctx, 27f, Color.WHITE, 700, 2)
    private val pvBar = Bar(ui.ctx, dark = true)
    private val pvDesc = K.text(ui.ctx, 15f, K.white(0.66f), 400, 3)
    private val pvNext = K.text(ui.ctx, 15f, K.white(0.62f), 400, 1)
    private val pvHint = K.text(ui.ctx, 14f, K.white(0.45f))

    private val holeU = RectF(698f, 110f, 698f + 534f, 110f + 300f)
    private var cats = ArrayList<CatRow>()
    private var chans: List<JSONObject> = emptyList()
    private var cat = "all"
    private var zone = 2
    private var ti = 2
    private var cti = 0
    private var ci = 0
    private var shown = false
    private var keepVideo = false
    private var prevId = ""
    private var lastEpg = 0L

    private val prevRun = Runnable { ui.safe("aperçu") { startPreview() } }
    private val infoRun = Runnable { ui.safe("chaîne") { loadInfo() } }
    private val catRun = Runnable { ui.safe("catégorie") { load(cats.getOrNull(cti)?.key ?: cat, false) } }
    private val clockRun = object : Runnable { override fun run() { top.clock.text = clockText(); postDelayed(this, 20000) } }

    init {
        shown = true
        bgv.bg = liveBg()
        bgv.radius = K.pxf(18f)
        addView(bgv, 0, K.lp(K.MATCH, K.MATCH))
        top.tabs.select("live")
        // catégories
        catBox.orientation = LinearLayout.VERTICAL
        catScroll.isVerticalScrollBarEnabled = false; catScroll.isFocusable = false
        catScroll.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        catScroll.clipChildren = false; catBox.clipChildren = false
        catScroll.addView(catBox, FrameLayout.LayoutParams(K.MATCH, K.WRAP))
        addView(catScroll, FrameLayout.LayoutParams(K.px(236), K.px(600)).apply { leftMargin = K.px(40); topMargin = K.px(104) })
        catBox.setPadding(K.px(8), K.px(6), K.px(8), K.px(30))
        // chaînes
        addView(list, FrameLayout.LayoutParams(K.px(392), K.px(616)).apply { leftMargin = K.px(284); topMargin = K.px(104) })
        empty.visibility = View.GONE
        addView(empty, FrameLayout.LayoutParams(K.px(360), K.WRAP).apply { leftMargin = K.px(300); topMargin = K.px(130) })
        // aperçu en direct (le cadre est vide : la vidéo est dessous)
        val badge = K.text(ui.ctx, 13f, Color.WHITE, 800); badge.text = "●  EN DIRECT"; badge.letterSpacing = 0.04f
        badge.setPadding(K.px(10), K.px(5), K.px(10), K.px(5)); badge.background = K.round(Color.parseColor("#e5322d"), 7f)
        pv.addView(badge, FrameLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(14); topMargin = K.px(14) })
        pvChip.setPadding(K.px(12), K.px(7), K.px(12), K.px(7))
        pv.addView(pvChip, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.END).apply { rightMargin = K.px(14); topMargin = K.px(14) })
        val mid = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER_HORIZONTAL }
        mid.addView(pvSpin, LinearLayout.LayoutParams(K.px(34), K.px(34)))
        pvMsg.gravity = Gravity.CENTER
        mid.addView(pvMsg, LinearLayout.LayoutParams(K.px(420), K.WRAP).apply { topMargin = K.px(12) })
        pv.addView(mid, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.CENTER))
        val okHint = K.text(ui.ctx, 14f, K.white(0.85f)); okHint.text = "OK : plein écran"
        okHint.setShadowLayer(K.pxf(6f), 0f, 0f, Color.BLACK)
        pv.addView(okHint, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.BOTTOM or Gravity.END).apply { rightMargin = K.px(16); bottomMargin = K.px(14) })
        addView(pv, FrameLayout.LayoutParams(K.px(534), K.px(300)).apply { leftMargin = K.px(698); topMargin = K.px(110) })
        val info = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL }
        val tr = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        tr.addView(pvTime)
        pvGenre.setPadding(K.px(8), K.px(3), K.px(8), K.px(3)); pvGenre.background = K.round(Color.TRANSPARENT, 6f, 1, K.white(0.3f))
        tr.addView(pvGenre, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(10) })
        info.addView(tr)
        info.addView(pvTitle, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(6) })
        info.addView(pvBar, LinearLayout.LayoutParams(K.MATCH, K.px(4)).apply { topMargin = K.px(12) })
        pvDesc.setLineSpacing(0f, 1.3f)
        info.addView(pvDesc, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(12) })
        info.addView(pvNext, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(12) })
        pvHint.text = "▲▼ chaînes · ◀ catégories · ▶ guide · ☰ favori"
        info.addView(pvHint, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(14) })
        addView(info, FrameLayout.LayoutParams(K.px(534), K.WRAP).apply { leftMargin = K.px(698); topMargin = K.px(428) })
        post(clockRun)
        load(null, true)
    }

    private fun holePx() = RectF(K.pxf(holeU.left), K.pxf(holeU.top), K.pxf(holeU.right), K.pxf(holeU.bottom))

    override fun applyVideo() {
        bgv.hole = holePx()
        val r = holePx()
        ui.host.videoRect(r.left.toInt(), r.top.toInt(), r.width().toInt(), r.height().toInt())
    }

    private fun load(c: String?, first: Boolean) {
        val arg = if (c == null) "" else ui.q(c)
        ui.api("live($arg)") { o ->
            if (o == null || o.has("error")) { ui.toast("TV en direct indisponible"); return@api }
            cat = o.optString("cat")
            buildCats(o)
            chans = o.objs("chans")
            val sel = o.optString("sel")
            ci = chans.indexOfFirst { it.optString("id") == sel }.coerceAtLeast(0)
            empty.visibility = if (chans.isEmpty()) View.VISIBLE else View.GONE
            empty.text = if (cat == "fav") "Aucune chaîne en favori.\nAppuie sur ☰ Menu sur une chaîne pour l'ajouter." else "Aucune chaîne dans cette catégorie."
            list.set(chans, if (zone == 2) ci else -1)
            if (zone == 2) list.setFocus(ci)
            if (first) { zone = if (chans.isEmpty()) 1 else 2; paintFocus() }
            fillPanel()
            if (chans.isNotEmpty()) schedulePreview(if (first) 300 else 900) else stopPreview()
        }
    }

    private fun buildCats(o: JSONObject) {
        catBox.removeAllViews(); cats.clear()
        for (c in o.objs("cats")) {
            val r = CatRow(ui.ctx, c.optString("k"), c.optString("n"), c.optInt("c"))
            r.sel = r.key == cat
            catBox.addView(r, LinearLayout.LayoutParams(K.MATCH, K.px(46)).apply { bottomMargin = K.px(4) })
            cats.add(r)
        }
        cti = cats.indexOfFirst { it.key == cat }.coerceAtLeast(0)
        if (zone == 1) cats.getOrNull(cti)?.foc(true)
    }

    private fun paintFocus() {
        top.tabs.items.forEachIndexed { i, t -> t.foc(zone == 0 && i == ti) }
        cats.forEachIndexed { i, c -> c.foc(zone == 1 && i == cti) }
        if (zone == 2) list.setFocus(ci) else list.setFocus(-1)
        if (zone == 1) cats.getOrNull(cti)?.let { revealCat(it) }
    }

    private fun revealCat(v: View) {
        val pad = K.px(60)
        if (v.top - catScroll.scrollY < pad) catScroll.scrollTo(0, maxOf(0, v.top - pad))
        else if (v.bottom - catScroll.scrollY > catScroll.height - pad) catScroll.scrollTo(0, v.bottom - catScroll.height + pad)
    }

    private fun fillPanel() {
        val c = chans.getOrNull(ci)
        if (c == null) {
            pvChip.text = ""; pvTitle.text = ""; pvTime.text = ""; pvGenre.visibility = View.GONE; pvDesc.text = ""; pvNext.text = ""; pvBar.pct = 0f
            pvMsg.text = "Aucune chaîne"; pvSpin.stop(); pvSpin.visibility = View.GONE; return
        }
        pvChip.text = c.optString("n")
        pvChip.background = K.round(K.color(c.optString("col"), Color.DKGRAY), 8f)
        pvTitle.text = c.optString("pg")
        pvTime.text = c.optString("s")
        pvBar.pct = c.optInt("pct") / 100f
        removeCallbacks(infoRun); postDelayed(infoRun, 250)
    }

    private fun loadInfo() {
        val c = chans.getOrNull(ci) ?: return
        val id = c.optString("id")
        ui.api("ch(${ui.q(id)})") { o ->
            if (o == null || chans.getOrNull(ci)?.optString("id") != id) return@api
            pvTitle.text = o.optString("pg")
            pvTime.text = "${o.optString("s")} – ${o.optString("e")}"
            val g = o.optString("g")
            pvGenre.text = g; pvGenre.visibility = if (g.isEmpty()) View.GONE else View.VISIBLE
            pvBar.pct = o.optInt("pct") / 100f
            pvDesc.text = o.optString("desc")
            val n = o.objs("next").firstOrNull()
            pvNext.text = if (n != null) "À suivre · ${n.optString("s")} ${n.optString("t")}" else ""
        }
    }

    private fun schedulePreview(delay: Long = 900) {
        removeCallbacks(prevRun)
        val c = chans.getOrNull(ci) ?: return
        if (c.optString("id") != prevId) {
            pvSpin.visibility = View.VISIBLE; pvSpin.start()
            pvMsg.text = "Aperçu de ${c.optString("n")}…"
        }
        postDelayed(prevRun, delay)
    }

    private fun startPreview() {
        if (!shown) return
        val c = chans.getOrNull(ci) ?: return
        val id = c.optString("id")
        if (id == prevId) return
        prevId = id
        pvSpin.visibility = View.VISIBLE; pvSpin.start()
        pvMsg.text = "Aperçu de ${c.optString("n")}…"
        ui.js("nativeApi.livePrev(${ui.q(id)})")
        postDelayed({ if (prevId == id && pvSpin.visibility == View.VISIBLE) pvMsg.text = "Le serveur met du temps à répondre…" }, 9000)
    }

    private fun stopPreview() {
        removeCallbacks(prevRun)
        if (prevId.isNotEmpty()) ui.js("nativeApi.liveStop()")
        prevId = ""
    }

    override fun onFirstFrame() {
        pvSpin.stop(); pvSpin.visibility = View.GONE; pvMsg.text = ""
    }

    override fun onPlayFail(msg: String) {
        pvSpin.stop(); pvSpin.visibility = View.GONE
        pvMsg.text = "Aperçu indisponible"
        prevId = ""
    }

    override fun onEvent(kind: String, o: JSONObject) {
        if (kind != "epg" || !shown) return
        val now = System.currentTimeMillis()
        if (now - lastEpg < 2500) return
        lastEpg = now
        ui.api("live()") { r ->
            if (r == null || r.optString("cat") != cat) return@api
            val L = r.objs("chans")
            if (L.size != chans.size) return@api
            chans = L
            list.refreshItems(L)
            val c = chans.getOrNull(ci)
            if (c != null) { pvTitle.text = c.optString("pg"); pvBar.pct = c.optInt("pct") / 100f }
            removeCallbacks(infoRun); postDelayed(infoRun, 100)
        }
    }

    override fun onShown() {
        shown = true
        keepVideo = false
        top.clock.text = clockText()
        ui.js("nativeApi.unfull();nativeApi.livePos()") { s ->
            val o = try { JSONObject(s ?: "{}") } catch (e: Exception) { JSONObject() }
            val id = o.optString("id")
            if (id.isNotEmpty()) {
                prevId = id
                val i = chans.indexOfFirst { it.optString("id") == id }
                if (i >= 0 && i != ci) { ci = i; if (zone == 2) list.setFocus(ci); fillPanel() }
                pvSpin.stop(); pvSpin.visibility = View.GONE; pvMsg.text = ""
            } else { prevId = ""; schedulePreview(300) }
        }
    }

    override fun onHidden() {
        shown = false
        removeCallbacks(prevRun); removeCallbacks(infoRun)
        if (!keepVideo) stopPreview()
    }

    override fun restoreFocus() { paintFocus() }

    private fun focusTab(i: Int) {
        ti = i; paintFocus()
        when (top.tabs.items[i].key) {
            "films", "series" -> { ui.closeLive(top.tabs.items[i].key) }
            "settings" -> { stopPreview(); ui.webTab("settings") }
        }
    }

    override fun key(code: Int): Boolean {
        when (zone) {
            0 -> when (code) {
                KeyEvent.KEYCODE_DPAD_LEFT -> if (ti > 0) focusTab(ti - 1)
                KeyEvent.KEYCODE_DPAD_RIGHT -> if (ti < top.tabs.items.size - 1) focusTab(ti + 1)
                KeyEvent.KEYCODE_DPAD_DOWN -> { zone = if (chans.isEmpty()) 1 else 2; paintFocus() }
            }
            1 -> when (code) {
                KeyEvent.KEYCODE_DPAD_UP -> if (cti > 0) { cti--; paintFocus(); removeCallbacks(catRun); postDelayed(catRun, 350) } else { zone = 0; ti = 2; paintFocus() }
                KeyEvent.KEYCODE_DPAD_DOWN -> if (cti < cats.size - 1) { cti++; paintFocus(); removeCallbacks(catRun); postDelayed(catRun, 350) }
                KeyEvent.KEYCODE_DPAD_RIGHT -> if (chans.isNotEmpty()) { removeCallbacks(catRun); if (cats.getOrNull(cti)?.key != cat) load(cats[cti].key, false); zone = 2; paintFocus() }
            }
            2 -> when (code) {
                KeyEvent.KEYCODE_DPAD_UP -> if (ci > 0) moveCh(ci - 1) else { zone = 0; ti = 2; paintFocus() }
                KeyEvent.KEYCODE_DPAD_DOWN -> if (ci < chans.size - 1) moveCh(ci + 1)
                KeyEvent.KEYCODE_DPAD_LEFT -> { zone = 1; paintFocus() }
                KeyEvent.KEYCODE_DPAD_RIGHT -> openGuide()
            }
        }
        return true
    }

    override fun media(code: Int): Boolean {
        if (zone != 2) return false
        when (code) {
            KeyEvent.KEYCODE_CHANNEL_UP -> if (ci > 0) moveCh(ci - 1)
            KeyEvent.KEYCODE_CHANNEL_DOWN -> if (ci < chans.size - 1) moveCh(ci + 1)
            else -> return false
        }
        return true
    }

    private fun moveCh(i: Int) {
        ci = i; list.setFocus(i); fillPanel(); schedulePreview()
    }

    override fun ok() {
        when (zone) {
            0 -> when (top.tabs.items[ti].key) { "search" -> { stopPreview(); ui.push(SearchScreen(ui)) } }
            1 -> { removeCallbacks(catRun); load(cats.getOrNull(cti)?.key ?: cat, false); if (chans.isNotEmpty()) { zone = 2; paintFocus() } }
            2 -> openFull(chans.getOrNull(ci)?.optString("id") ?: return)
        }
    }

    override fun menu() {
        if (zone != 2) return
        val c = chans.getOrNull(ci) ?: return
        ui.api("chFav(${ui.q(c.optString("id"))})") { r ->
            if (r == null) return@api
            ui.toast(r.optString("msg"))
            c.put("fav", r.optBoolean("fav"))
            list.adapter?.notifyItemChanged(ci)
            if (cat == "fav") load(cat, false)
        }
    }

    fun openFull(id: String) {
        removeCallbacks(prevRun)
        keepVideo = true
        prevId = id
        ui.api("liveFull(${ui.q(id)})") { r ->
            if (r == null || r.optBoolean("none")) { keepVideo = false; ui.toast("Lecture impossible"); return@api }
            ui.push(PlayerScreen(ui, r))
        }
    }

    private fun openGuide() {
        if (chans.isEmpty()) return
        ui.push(GuideScreen(ui, ci) { id -> ui.pop(); openFull(id) })
    }

    override fun onBack(): Boolean {
        if (zone != 0) { zone = 0; ti = 2; paintFocus(); return true }
        ui.closeLive("films")
        return true
    }
}

// ==================================================================================================== Guide des programmes
@SuppressLint("ViewConstructor")
class GuideScreen(ui: NativeUi, startRow: Int, private val onPick: (String) -> Unit) : Screen(ui) {
    private val grid = GuideGrid(ui.ctx)
    private val kick = K.text(ui.ctx, 14f, K.white(0.6f), 600)
    private val clock = K.text(ui.ctx, 22f, K.white(0.85f), 500)
    private var lastEpg = 0L
    private var loading = false

    init {
        background = liveBg()
        kick.letterSpacing = 0.08f
        val head = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL }
        head.addView(kick)
        val t = K.text(ui.ctx, 38f, Color.WHITE, 700); t.text = "Guide des programmes"
        head.addView(t, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(4) })
        addView(head, FrameLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(64); topMargin = K.px(40) })
        clock.text = clockText()
        addView(clock, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.END).apply { rightMargin = K.px(64); topMargin = K.px(50) })
        addView(grid, FrameLayout.LayoutParams(K.MATCH, K.px(530)).apply { leftMargin = K.px(64); rightMargin = K.px(64); topMargin = K.px(130) })
        val hint = K.text(ui.ctx, 14f, K.white(0.45f)); hint.text = "◀ ▶ avancer dans le temps · ▲ ▼ chaînes · OK regarder · Retour : liste des chaînes"
        addView(hint, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.BOTTOM).apply { leftMargin = K.px(64); bottomMargin = K.px(26) })
        grid.fr = startRow
        grid.first = maxOf(0, startRow - 2)
        fetch()
    }

    /** Charge les lignes visibles (le guide de chaque chaîne est demandé au fournisseur au besoin) */
    private fun fetch() {
        if (loading) return
        loading = true
        val from = grid.first
        ui.api("guide($from,${GuideGrid.ROWS})") { o ->
            loading = false
            if (o == null) return@api
            kick.text = "TV EN DIRECT · ${o.optString("catName").uppercase(Locale.FRANCE)}"
            grid.total = o.optInt("total")
            grid.now = o.optDouble("now").toFloat()
            if (grid.ws < 0) grid.ws = (Math.floor((grid.now - 30) / 30.0) * 30).toFloat().coerceAtLeast(0f)
            val f = o.optInt("from")
            o.objs("chans").forEachIndexed { i, c -> grid.rows[f + i] = c }
            if (grid.ft < 0) grid.ft = grid.now
            grid.invalidate()
            if (from != grid.first) fetch()
        }
    }

    override fun onEvent(kind: String, o: JSONObject) {
        if (kind != "epg") return
        val now = System.currentTimeMillis()
        if (now - lastEpg < 1500) return
        lastEpg = now; fetch()
    }

    override fun key(code: Int): Boolean {
        when (code) {
            KeyEvent.KEYCODE_DPAD_UP -> if (grid.fr > 0) { grid.fr--; if (grid.fr < grid.first) { grid.first = grid.fr; fetch() } }
            KeyEvent.KEYCODE_DPAD_DOWN -> if (grid.fr < grid.total - 1) { grid.fr++; if (grid.fr >= grid.first + GuideGrid.ROWS) { grid.first = grid.fr - GuideGrid.ROWS + 1; fetch() } }
            KeyEvent.KEYCODE_DPAD_LEFT -> grid.move(-1)
            KeyEvent.KEYCODE_DPAD_RIGHT -> grid.move(1)
            else -> return false
        }
        grid.invalidate()
        return true
    }

    override fun ok() {
        val id = grid.rows[grid.fr]?.optString("id") ?: return
        onPick(id)
    }
}

/** Grille du guide : chaînes en lignes, heures en colonnes (dessinée en une fois, très légère) */
class GuideGrid(ctx: Context) : View(ctx) {
    companion object { const val ROWS = 7; const val SPAN = 120f }
    val rows = HashMap<Int, JSONObject>()
    var total = 0
    var first = 0
    var fr = 0
    var ft = -1f
    var ws = -1f
    var now = 0f
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val tp = TextPaint(Paint.ANTI_ALIAS_FLAG)
    private val rect = RectF()

    private fun progs(r: Int): List<JSONObject> = rows[r]?.objs("progs") ?: emptyList()

    /** Programme sélectionné d'une ligne : celui qui couvre l'heure choisie, sinon le suivant */
    private fun cur(r: Int): JSONObject? {
        val L = progs(r)
        val t = maxOf(ft, ws)
        return L.firstOrNull { it.optDouble("s") <= t && it.optDouble("e") > t } ?: L.firstOrNull { it.optDouble("s") > t }
    }

    fun move(d: Int) {
        val L = progs(fr)
        val c = cur(fr)
        if (c == null || L.isEmpty()) { ws = (ws + d * 30f).coerceAtLeast(0f); ft = ws; return }
        if (d > 0) {
            val n = L.firstOrNull { it.optDouble("s") >= c.optDouble("e") - 0.5 }
            if (n == null) { ws += 30f; ft = maxOf(ft, ws); return }
            ft = n.optDouble("s").toFloat()
            while (ft >= ws + SPAN - 10f) ws += 30f
        } else {
            val p = L.lastOrNull { it.optDouble("e") <= c.optDouble("s") + 0.5 }
            if (p == null) { if (ws > 0f) { ws -= 30f; ft = ws }; return }
            ft = p.optDouble("s").toFloat()
            if (ft < ws) ws = (Math.floor(ft / 30.0) * 30).toFloat().coerceAtLeast(0f)
        }
    }

    private fun hhmm(m: Double): String {
        val v = ((Math.round(m) % 1440) + 1440) % 1440
        return String.format(Locale.FRANCE, "%02d:%02d", v / 60, v % 60)
    }

    private fun text(c: Canvas, s: String, x: Float, y: Float, maxW: Float, size: Float, color: Int, weight: Int) {
        tp.textSize = K.pxf(size); tp.color = color; tp.typeface = K.ui(weight)
        val t = TextUtils.ellipsize(s, tp, maxOf(0f, maxW), TextUtils.TruncateAt.END)
        c.drawText(t, 0, t.length, x, y, tp)
    }

    override fun onDraw(c: Canvas) {
        if (ws < 0) return
        val lw = K.pxf(150f); val gap = K.pxf(8f); val x0 = lw + gap; val W = width - x0
        val head = K.pxf(34f); val rh = K.pxf(62f); val step = K.pxf(70f)
        // heures
        for (k in 0 until 4) {
            val m = ws + k * 30f
            text(c, hhmm(m.toDouble()), x0 + W * (k * 30f / SPAN), K.pxf(18f), K.pxf(80f), 14f, K.white(0.55f), 400)
        }
        for (i in 0 until ROWS) {
            val r = first + i
            if (r >= total) break
            val y = head + i * step
            val ch = rows[r]
            // chaîne
            rect.set(0f, y, lw, y + rh)
            fill.color = K.white(0.05f); c.drawRoundRect(rect, K.pxf(12f), K.pxf(12f), fill)
            if (ch != null) {
                text(c, ch.optInt("num").takeIf { it > 0 }?.toString() ?: "", K.pxf(10f), y + rh / 2 + K.pxf(5f), K.pxf(22f), 13f, K.white(0.5f), 400)
                rect.set(K.pxf(36f), y + K.pxf(13f), K.pxf(140f), y + rh - K.pxf(13f))
                fill.color = K.color(ch.optString("col"), Color.DKGRAY); c.drawRoundRect(rect, K.pxf(8f), K.pxf(8f), fill)
                tp.textSize = K.pxf(12.5f); tp.typeface = K.ui(700)
                val n = TextUtils.ellipsize(ch.optString("n"), tp, rect.width() - K.pxf(10f), TextUtils.TruncateAt.END).toString()
                text(c, n, rect.centerX() - tp.measureText(n) / 2, rect.centerY() + K.pxf(4.5f), rect.width(), 12.5f, Color.WHITE, 700)
            }
            // programmes
            val L = progs(r)
            val sel = if (r == fr) cur(r) else null
            val vis = L.filter { it.optDouble("e") > ws && it.optDouble("s") < ws + SPAN }
            if (vis.isEmpty()) {
                rect.set(x0, y, x0 + W, y + rh)
                val on = r == fr
                fill.color = if (on) Color.WHITE else K.white(0.05f); c.drawRoundRect(rect, K.pxf(12f), K.pxf(12f), fill)
                val msg = if (ch == null) "Chargement du guide…" else if (L.isEmpty()) "Programme non communiqué" else "Pas de programme à cette heure"
                text(c, msg, x0 + K.pxf(12f), y + K.pxf(26f), W - K.pxf(24f), 15f, if (on) Color.BLACK else K.white(0.6f), 600)
                if (on) text(c, "OK : regarder", x0 + K.pxf(12f), y + K.pxf(46f), W, 12.5f, K.black(0.6f), 400)
            }
            for (p in vis) {
                val s = p.optDouble("s").toFloat(); val e = p.optDouble("e").toFloat()
                val a = x0 + W * ((maxOf(s, ws) - ws) / SPAN)
                val b = x0 + W * ((minOf(e, ws + SPAN) - ws) / SPAN) - K.pxf(6f)
                if (b - a < K.pxf(4f)) continue
                rect.set(a, y, b, y + rh)
                val on = p === sel
                val past = e <= now
                fill.color = if (on) Color.WHITE else if (past) K.white(0.035f) else K.white(0.07f)
                c.drawRoundRect(rect, K.pxf(12f), K.pxf(12f), fill)
                val fg = if (on) Color.BLACK else if (past) K.white(0.55f) else Color.WHITE
                text(c, p.optString("t"), a + K.pxf(12f), y + K.pxf(26f), b - a - K.pxf(24f), 15f, fg, 600)
                val g = p.optString("g")
                val sub = "${hhmm(s.toDouble())} – ${hhmm(e.toDouble())}" + (if (g.isNotEmpty()) " · $g" else "") + (if (on) " · OK : regarder" else "")
                text(c, sub, a + K.pxf(12f), y + K.pxf(46f), b - a - K.pxf(24f), 12.5f, if (on) K.black(0.6f) else K.white(0.55f), 400)
            }
        }
        // maintenant
        if (now >= ws && now < ws + SPAN) {
            val x = x0 + W * ((now - ws) / SPAN)
            fill.color = Color.parseColor("#e5322d")
            c.drawRect(x - K.pxf(1f), K.pxf(24f), x + K.pxf(1f), height.toFloat(), fill)
            val lbl = hhmm(now.toDouble())
            tp.textSize = K.pxf(12f); tp.typeface = K.ui(700)
            val w = tp.measureText(lbl) + K.pxf(12f)
            rect.set(x - w / 2, K.pxf(4f), x + w / 2, K.pxf(24f))
            c.drawRoundRect(rect, K.pxf(5f), K.pxf(5f), fill)
            text(c, lbl, x - w / 2 + K.pxf(6f), K.pxf(19f), w, 12f, Color.WHITE, 700)
        }
    }
}
