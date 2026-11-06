package fr.prisme.tv.nat

import android.annotation.SuppressLint
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Ligne de méta-données (année • durée • genres + badges de note) */
fun metaRow(ctx: android.content.Context, row: LinearLayout, o: JSONObject, size: Float = 18f) {
    row.removeAllViews()
    val parts = o.optJSONArray("meta").strs().filter { it.isNotBlank() }
    val t = K.text(ctx, size, K.white(0.82f)); t.text = parts.joinToString("   •   ")
    row.addView(t)
    val age = o.optString("age")
    if (age.isNotBlank()) {
        val a = K.text(ctx, 13f, Color.WHITE, 700); a.text = age
        a.setPadding(K.px(6), K.px(1), K.px(6), K.px(1)); a.background = K.round(Color.TRANSPARENT, 5f, 2, K.white(0.55f))
        row.addView(a, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(14) })
    }
    fun rating(label: String, value: String, bg: GradientDrawable) {
        if (value.isBlank()) return
        val b = K.text(ctx, 12f, Color.BLACK, 800); b.text = label
        b.setPadding(K.px(6), K.px(2), K.px(6), K.px(2)); b.background = bg
        val v = K.text(ctx, size, Color.WHITE, 600); v.text = value
        row.addView(b, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(14) })
        row.addView(v, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(7) })
    }
    rating("TMDB", o.optString("tmdb"), GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(Color.parseColor("#90cea1"), Color.parseColor("#01b4e4"))).apply { cornerRadius = K.pxf(4f) })
    rating("IMDb", o.optString("imdb"), K.round(Color.parseColor("#f5c518"), 4f))
}

/** Grand titre : police du film et taille réduite pour les titres longs */
fun bigTitle(tv: TextView, o: JSONObject, base: Float) {
    val f = o.optString("f")
    val t = o.optString("t")
    titleStyle(tv, f)
    val k = when (f) { "bebas" -> 1f; "serif" -> 0.78f; "black" -> 0.64f; else -> 0.72f }
    var s = base * k
    if (t.length > 22) s *= 0.78f
    if (t.length > 34) s *= 0.8f
    tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, K.pxf(s))
    if (f == "thin") tv.typeface = K.font("outfit", 200)
    tv.text = t
}

@SuppressLint("ViewConstructor")
class HomeScreen(ui: NativeUi) : Screen(ui) {
    private val sv = ScrollView(ui.ctx)
    private val content = LinearLayout(ui.ctx)
    private val tabs = TabBar(ui.ctx)
    private val tabWrap = FrameLayout(ui.ctx)
    private val brand = LinearLayout(ui.ctx)
    private val clock = K.text(ui.ctx, 22f, K.white(0.85f), 500)
    private val hero = LinearLayout(ui.ctx)
    private val hKick = K.text(ui.ctx, 15f, K.white(0.7f), 600)
    private val hTitle = K.text(ui.ctx, 80f, Color.WHITE, 400, 2)
    private val hMeta = LinearLayout(ui.ctx)
    private val hSyn = K.text(ui.ctx, 18f, K.white(0.85f), 400, 3)
    private val tabLine: StaticLine
    private var ty = "films"
    private var data: JSONObject? = null
    private var heroItem: JSONObject? = null
    private var firstRowLine = 1
    override val vscroll: ScrollView get() = sv
    private val heroRun = Runnable { heroItem?.let { setHero(it) } }
    private val clockRun = object : Runnable {
        override fun run() { clock.text = SimpleDateFormat("HH:mm", Locale.FRANCE).format(Date()); postDelayed(this, 20000) }
    }

    init {
        // contenu défilant
        sv.isVerticalScrollBarEnabled = false
        sv.overScrollMode = View.OVER_SCROLL_NEVER
        sv.isFocusable = false
        sv.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        sv.clipChildren = false
        content.orientation = LinearLayout.VERTICAL
        content.clipChildren = false; content.clipToPadding = false
        sv.addView(content, FrameLayout.LayoutParams(K.MATCH, K.WRAP))
        // aperçu (fixe, s'efface quand on descend)
        hero.orientation = LinearLayout.VERTICAL
        hero.gravity = Gravity.BOTTOM
        hKick.letterSpacing = 0.08f
        hero.addView(hKick)
        hero.addView(hTitle, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(10) })
        hMeta.orientation = LinearLayout.HORIZONTAL; hMeta.gravity = Gravity.CENTER_VERTICAL
        hero.addView(hMeta, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(10) })
        hSyn.setLineSpacing(0f, 1.3f)
        hero.addView(hSyn, LinearLayout.LayoutParams(K.px(640), K.WRAP).apply { topMargin = K.px(10) })
        addView(hero, FrameLayout.LayoutParams(K.px(760), K.px(268)).apply { leftMargin = K.px(64); topMargin = K.px(108) })
        addView(sv, K.lp(K.MATCH, K.MATCH))
        // barre du haut
        val dot = View(ui.ctx).apply { background = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(Color.parseColor("#ff375f"), Color.parseColor("#ff9f0a"), Color.parseColor("#30d158"), Color.parseColor("#0a84ff"), Color.parseColor("#bf5af2"))).apply { cornerRadius = K.pxf(7f) } }
        brand.orientation = LinearLayout.HORIZONTAL; brand.gravity = Gravity.CENTER_VERTICAL
        brand.addView(dot, LinearLayout.LayoutParams(K.px(22), K.px(22)))
        val bt = K.text(ui.ctx, 22f, Color.WHITE, 700); bt.text = "prisme"
        brand.addView(bt, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(8) })
        addView(brand, FrameLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(56); topMargin = K.px(36) })
        addView(clock, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.END).apply { rightMargin = K.px(56); topMargin = K.px(36) })
        tabWrap.clipChildren = false
        tabWrap.addView(tabs, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.CENTER_HORIZONTAL))
        addView(tabWrap, FrameLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(26) })
        tabLine = StaticLine(tabs.items, tabWrap)
        lines.add(tabLine)
        sv.setOnScrollChangeListener { _, _, y, _, _ ->
            val a = (1f - y / K.pxf(240f)).coerceIn(0f, 1f)
            hero.alpha = a
            tabWrap.alpha = if (li == 0) 1f else (1f - y / K.pxf(160f)).coerceIn(0f, 1f)
            brand.alpha = tabWrap.alpha; clock.alpha = tabWrap.alpha
        }
        post(clockRun)
    }

    override fun onHidden() { removeCallbacks(heroRun) }

    fun openTab(t: String, focusTabs: Boolean) {
        val changed = t != ty || data == null
        ty = t
        tabs.select(t)
        tabLine.idx = if (t == "series") 1 else 0
        if (focusTabs) { li = 0; sv.scrollTo(0, 0) }
        if (changed) load(focusTabs) else post { apply(true) }
    }

    fun reload() { load(false, keep = true) }

    private fun load(focusTabs: Boolean, keep: Boolean = false) {
        val k = if (ty == "series") "s" else "f"
        ui.api("home('$k')") { o ->
            if (o == null || o.has("error")) { if (o != null) ui.toast("Accueil indisponible : " + o.optString("error")); return@api }
            build(o, focusTabs, keep)
        }
    }

    private fun build(o: JSONObject, focusTabs: Boolean, keep: Boolean) {
        val oldLi = li
        val oldIdx = lines.map { it.idx }
        val oldScroll = sv.scrollY
        data = o
        content.removeAllViews()
        while (lines.size > 1) lines.removeAt(lines.size - 1)
        content.addView(View(ui.ctx), LinearLayout.LayoutParams(K.MATCH, K.px(362)))
        val unit = if (ty == "series") "séries" else "titres"
        for (r in o.objs("rows")) {
            val items = r.objs("items")
            if (items.isEmpty()) continue
            val sec = RowSection(ui.ctx, r.optString("title"), r.optString("small").ifEmpty { null })
            val views = ArrayList<View>()
            val rank = r.optString("kind") == "rank"
            items.forEachIndexed { i, it ->
                val c = PosterCard(ui.ctx, rank)
                c.bind(it, i + 1)
                sec.add(c, if (rank) 20f else 26f)
                views.add(c)
            }
            content.addView(sec, LinearLayout.LayoutParams(K.MATCH, K.WRAP))
            lines.add(StaticLine(views, sec, sec.scroller))
        }
        firstRowLine = 1
        // genres en tuiles
        val genres = o.objs("genres")
        if (genres.isNotEmpty()) {
            val head = K.text(ui.ctx, 20f, K.white(0.78f), 600)
            val sp = android.text.SpannableStringBuilder("Genres")
            val st = sp.length
            sp.append("   ${genres.size} · OK pour voir tous les titres du genre")
            sp.setSpan(android.text.style.AbsoluteSizeSpan(K.px(14)), st, sp.length, 0)
            sp.setSpan(android.text.style.ForegroundColorSpan(K.white(0.45f)), st, sp.length, 0)
            head.text = sp
            val block = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL; clipChildren = false; clipToPadding = false }
            block.addView(head, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { leftMargin = K.px(64); topMargin = K.px(30) })
            content.addView(block, LinearLayout.LayoutParams(K.MATCH, K.WRAP))
            val tw = (1280f - 128f - 3 * 20f) / 4f
            genres.chunked(4).forEachIndexed { ri, chunk ->
                val row = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL; clipChildren = false; clipToPadding = false }
                row.setPadding(K.px(64), K.px(if (ri == 0) 18 else 20), K.px(64), 0)
                val views = ArrayList<View>()
                chunk.forEachIndexed { i, g ->
                    val t = Tile(ui.ctx, tw)
                    t.bind(g, unit)
                    row.addView(t, LinearLayout.LayoutParams(K.px(tw), K.px(112)).apply { if (i > 0) leftMargin = K.px(20) })
                    views.add(t)
                }
                block.addView(row, LinearLayout.LayoutParams(K.MATCH, K.WRAP))
                lines.add(StaticLine(views, if (ri == 0) block else row, null, sameColumns = true))
            }
        }
        content.addView(View(ui.ctx), LinearLayout.LayoutParams(K.MATCH, K.px(80)))
        // aperçu : premier titre de la première rangée
        val first = o.objs("rows").firstOrNull { it.objs("items").isNotEmpty() }?.objs("items")?.firstOrNull()
        if (first != null) setHero(first) else { hKick.text = ""; hTitle.text = ""; hMeta.removeAllViews(); hSyn.text = if (ty == "series") "Aucune série pour l'instant." else "Aucun film pour l'instant." }
        if (keep) {
            for (i in 1 until lines.size) lines[i].idx = (oldIdx.getOrNull(i) ?: 0).coerceIn(0, maxOf(0, lines[i].count - 1))
            li = oldLi.coerceIn(0, lines.size - 1)
        } else {
            li = if (focusTabs || lines.size < 2) 0 else 1
        }
        post {
            if (keep) sv.scrollTo(0, oldScroll)
            if (visibility == View.VISIBLE && ui.top() === this) apply(true)
        }
    }

    private fun setHero(o: JSONObject) {
        hKick.text = o.optString("kick")
        bigTitle(hTitle, o, 80f)
        metaRow(ui.ctx, hMeta, o)
        hSyn.text = o.optString("s")
    }

    override fun applyBackground() {
        val h = heroItem
        if (h != null) ui.setBg(h.optString("c1"), h.optString("c2"), h.optString("bd")) else ui.setBg("#2b3245", "#0a0b10", null)
    }

    override fun scrollTargetFor(n: Int): Int? = if (n <= firstRowLine) 0 else null

    override fun onFocus(line: Line, i: Int, v: View) {
        if (line === tabLine) {
            val t = tabs.items[i]
            tabWrap.alpha = 1f; brand.alpha = 1f; clock.alpha = 1f
            when (t.key) {
                "films", "series" -> if (t.key != ty) openTab(t.key, focusTabs = true)
                else -> ui.webTab(t.key)
            }
            return
        }
        val p = v as? PosterCard
        if (p != null) {
            val it = p.item ?: return
            heroItem = it
            removeCallbacks(heroRun); postDelayed(heroRun, 110)
            ui.setBg(it.optString("c1"), it.optString("c2"), it.optString("bd"))
        } else if (v is Tile) {
            val g = data?.objs("genres")?.firstOrNull { it.optString("k") == v.key }
            if (g != null) ui.setBg(g.optString("c1"), g.optString("c2"), null)
        }
    }

    override fun onOk(line: Line, i: Int, v: View) {
        when (v) {
            is PosterCard -> v.item?.let { ui.openDetail(it.optString("id")) }
            is Tile -> ui.push(GenreScreen(ui, if (ty == "series") "s" else "f", v.key))
            is TabItem -> go(1)
        }
    }

    override fun onMenu(line: Line, i: Int, v: View) {
        val p = v as? PosterCard ?: return
        val id = p.item?.optString("id") ?: return
        ui.api("fav(${ui.q(id)})") { r -> if (r != null) { ui.toast(r.optString("msg")); reload() } }
    }

    override fun onBack(): Boolean {
        if (li != 0) { li = 0; sv.smoothScrollTo(0, 0); apply(false); return true }
        return false
    }

    /** Au retour, on ne reconstruit l'accueil que si quelque chose a changé (favori, reprise, catalogue) */
    override fun onShown() {
        val k = if (ty == "series") "s" else "f"
        ui.js("nativeApi.ver('$k')") { v -> if (v != null && v != data?.optString("v")) reload() }
    }
}
