package fr.prisme.tv.nat

import android.annotation.SuppressLint
import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import org.json.JSONObject

/** Recherche native (maquette 7) : clavier à gauche, résultats à droite */
@SuppressLint("ViewConstructor")
class SearchScreen(ui: NativeUi) : Screen(ui) {
    private val query = K.text(ui.ctx, 26f, Color.WHITE, 500)
    private val results = LinearLayout(ui.ctx)
    private val rsv = ScrollView(ui.ctx)
    private var q = ""
    private var kbLines = 0
    private val searchRun = Runnable { ui.safe("recherche") { search() } }

    @SuppressLint("ViewConstructor")
    inner class Key(val value: String, label: String, val wide: Boolean = false) : android.widget.TextView(ui.ctx), Foc {
        init {
            text = label; gravity = Gravity.CENTER
            typeface = K.ui(500); includeFontPadding = false
            setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, K.pxf(if (wide) 16f else 21f))
            paint(false)
        }
        private fun paint(on: Boolean) {
            background = K.round(if (on) Color.WHITE else K.white(0.07f), 12f)
            setTextColor(if (on) Color.BLACK else Color.WHITE)
        }
        override fun foc(on: Boolean) { paint(on); lift(on, 1.08f) }
    }

    init {
        val left = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL; clipChildren = false }
        val box = FrameLayout(ui.ctx)
        box.background = K.round(K.white(0.1f), 14f)
        query.text = "Titre, acteur…"; query.setTextColor(K.white(0.45f))
        box.addView(query, FrameLayout.LayoutParams(K.MATCH, K.WRAP, Gravity.CENTER_VERTICAL).apply { leftMargin = K.px(20); rightMargin = K.px(16) })
        left.addView(box, LinearLayout.LayoutParams(K.MATCH, K.px(60)).apply { bottomMargin = K.px(18) })
        val chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        val kw = (400f - 5 * 8f) / 6f
        for (r in 0 until 6) {
            val row = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL; clipChildren = false }
            val views = ArrayList<View>()
            for (c in 0 until 6) {
                val ch = chars[r * 6 + c].toString()
                val k = Key(ch, ch.uppercase())
                row.addView(k, LinearLayout.LayoutParams(K.px(kw), K.px(52)).apply { if (c > 0) leftMargin = K.px(8) })
                views.add(k)
            }
            left.addView(row, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { if (r > 0) topMargin = K.px(8) })
            lines.add(StaticLine(views, row, null, sameColumns = true))
        }
        val row = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL; clipChildren = false }
        val ww = (400f - 2 * 8f) / 3f
        val specials = listOf(Key(" ", "Espace", true), Key("<", "⌫ Effacer", true), Key("x", "Tout effacer", true))
        specials.forEachIndexed { i, k -> row.addView(k, LinearLayout.LayoutParams(K.px(ww), K.px(52)).apply { if (i > 0) leftMargin = K.px(8) }) }
        left.addView(row, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(8) })
        lines.add(StaticLine(specials, row, null, sameColumns = true))
        kbLines = lines.size
        addView(left, FrameLayout.LayoutParams(K.px(400), K.WRAP).apply { leftMargin = K.px(64); topMargin = K.px(70) })

        rsv.isVerticalScrollBarEnabled = false; rsv.isFocusable = false
        rsv.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        rsv.clipChildren = false
        results.orientation = LinearLayout.VERTICAL; results.clipChildren = false; results.clipToPadding = false
        rsv.addView(results, FrameLayout.LayoutParams(K.MATCH, K.WRAP))
        addView(rsv, FrameLayout.LayoutParams(K.MATCH, K.MATCH).apply { leftMargin = K.px(470); topMargin = K.px(50) })
        hint("Tape quelques lettres : les films, séries et acteurs s'affichent ici.")
        li = 0
    }

    override val vscroll: ScrollView? get() = null

    private fun hint(t: String) {
        results.removeAllViews()
        val h = K.text(ui.ctx, 18f, K.white(0.55f), 400, 3); h.text = t
        results.addView(h, LinearLayout.LayoutParams(K.px(700), K.WRAP).apply { leftMargin = K.px(4); topMargin = K.px(24) })
    }

    override fun applyBackground() { ui.setBg("#2b3245", "#0a0b10", null) }

    override fun onOk(line: Line, i: Int, v: View) {
        when (v) {
            is Key -> {
                q = when (v.value) { "<" -> q.dropLast(1); "x" -> ""; else -> (q + v.value).take(40) }
                if (q.isEmpty()) { query.text = "Titre, acteur…"; query.setTextColor(K.white(0.45f)) }
                else { query.text = q + "▏"; query.setTextColor(Color.WHITE) }
                removeCallbacks(searchRun); postDelayed(searchRun, 350)
            }
            is PosterCard -> v.item?.let { ui.openDetail(it.optString("id")) }
            is CastCard -> ui.push(ActorScreen(ui, v.actorId))
        }
    }

    override fun onMenu(line: Line, i: Int, v: View) {
        val id = (v as? PosterCard)?.item?.optString("id") ?: return
        ui.api("fav(${ui.q(id)})") { r -> if (r != null) ui.toast(r.optString("msg")) }
    }

    /** Droite du clavier → résultats ; gauche des résultats → clavier */
    override fun onEdge(dir: Int): Boolean {
        if (dir == android.view.KeyEvent.KEYCODE_DPAD_RIGHT && li < kbLines && lines.size > kbLines) { go(kbLines); return true }
        if (dir == android.view.KeyEvent.KEYCODE_DPAD_LEFT && li >= kbLines) { go(0); return true }
        return false
    }

    private fun search() {
        val qq = q.trim()
        if (qq.length < 2) { while (lines.size > kbLines) lines.removeAt(lines.size - 1); hint(if (qq.isEmpty()) "Tape quelques lettres : les films, séries et acteurs s'affichent ici." else "Encore une lettre…"); return }
        ui.api("search(${ui.q(qq)})") { o -> if (o != null && qq == q.trim()) show(o) }
    }

    private fun show(o: JSONObject) {
        val keepLi = li
        while (lines.size > kbLines) lines.removeAt(lines.size - 1)
        results.removeAllViews()
        fun posters(title: String, n: Int, items: List<JSONObject>) {
            if (items.isEmpty()) return
            val sec = RowSection(ui.ctx, title, n.toString(), 10f, 6f)
            val v = ArrayList<View>()
            items.forEach { val c = PosterCard(ui.ctx, false, 118f, 177f); c.bind(it); sec.add(c, 22f); v.add(c) }
            results.addView(sec, LinearLayout.LayoutParams(K.MATCH, K.WRAP))
            lines.add(StaticLine(v, sec, sec.scroller))
        }
        posters("Films", o.optInt("nf"), o.objs("films"))
        posters("Séries", o.optInt("ns"), o.objs("series"))
        val actors = o.objs("actors")
        if (actors.isNotEmpty()) {
            val sec = RowSection(ui.ctx, "Acteurs", actors.size.toString(), 10f, 6f)
            val v = ArrayList<View>()
            actors.forEach { val c = CastCard(ui.ctx); c.bind(it); sec.add(c, 22f); v.add(c) }
            results.addView(sec, LinearLayout.LayoutParams(K.MATCH, K.WRAP))
            lines.add(StaticLine(v, sec, sec.scroller))
        }
        if (lines.size == kbLines) hint("Aucun résultat pour « ${q.trim()} »")
        rsv.scrollTo(0, 0)
        li = keepLi.coerceAtMost(lines.size - 1)
    }

    override fun revealVertical(n: Int, instant: Boolean) {
        if (n < kbLines) return
        val L = lines.getOrNull(n) ?: return
        val y = maxOf(0, L.section.top - K.px(10))
        if (instant) rsv.scrollTo(0, y) else rsv.smoothScrollTo(0, y)
    }
}

/** Page d'un acteur : photo, nom et ses titres disponibles dans ton catalogue */
@SuppressLint("ViewConstructor")
class ActorScreen(ui: NativeUi, val aid: String) : Screen(ui) {
    private val av = CastCard(ui.ctx)
    private val name = K.text(ui.ctx, 48f, Color.WHITE, 700)
    private val sub = K.text(ui.ctx, 17f, K.white(0.65f), 400, 2)
    private val rv = androidx.recyclerview.widget.RecyclerView(ui.ctx)
    private var items: List<JSONObject> = emptyList()
    private lateinit var grid: GridLine

    private inner class H(v: View) : androidx.recyclerview.widget.RecyclerView.ViewHolder(v)
    private val adapter = object : androidx.recyclerview.widget.RecyclerView.Adapter<H>() {
        override fun getItemCount() = items.size
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): H {
            val c = PosterCard(ui.ctx)
            c.layoutParams = androidx.recyclerview.widget.RecyclerView.LayoutParams(K.px(138), ViewGroup.LayoutParams.WRAP_CONTENT).apply { bottomMargin = K.px(30) }
            return H(c)
        }
        override fun onBindViewHolder(h: H, pos: Int) {
            val c = h.itemView as PosterCard
            c.bind(items[pos])
            val on = grid.idx == pos && li == 0
            c.foc(on); if (on) cur = c
        }
    }

    init {
        val head = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        head.addView(av, LinearLayout.LayoutParams(K.px(132), K.WRAP))
        val col = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL }
        val kick = K.text(ui.ctx, 15f, K.white(0.7f), 600); kick.text = "ACTEUR·RICE"; kick.letterSpacing = 0.08f
        col.addView(kick); col.addView(name, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(6) })
        col.addView(sub, LinearLayout.LayoutParams(K.px(800), K.WRAP).apply { topMargin = K.px(8) })
        head.addView(col, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(30) })
        addView(head, FrameLayout.LayoutParams(K.MATCH, K.WRAP).apply { leftMargin = K.px(64); topMargin = K.px(56) })
        rv.layoutManager = androidx.recyclerview.widget.GridLayoutManager(ui.ctx, 7)
        rv.adapter = adapter
        rv.itemAnimator = null
        rv.isFocusable = false
        rv.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        rv.clipChildren = false; rv.clipToPadding = false
        rv.overScrollMode = View.OVER_SCROLL_NEVER
        rv.setPadding(K.px(64), K.px(24), K.px(40), K.px(40))
        addView(rv, FrameLayout.LayoutParams(K.MATCH, K.MATCH).apply { topMargin = K.px(250) })
        grid = GridLine(rv, rv, 7) { items.size }
        lines.add(grid)
        ui.api("actor(${ui.q(aid)})") { o -> if (o != null) fill(o) }
    }

    fun fill(o: JSONObject) {
        name.text = o.optString("n")
        av.bind(JSONObject().put("id", aid).put("n", "").put("ph", o.optString("ph")))
        val n = o.optInt("count")
        sub.text = if (n > 0) "$n titre${if (n > 1) "s" else ""} dans ton catalogue" else "Aucun autre titre trouvé dans ton catalogue pour l'instant"
        items = o.objs("items")
        grid.idx = grid.idx.coerceIn(0, maxOf(0, items.size - 1))
        adapter.notifyDataSetChanged()
        later { if (ui.top() === this) apply(true) }
    }

    override fun applyBackground() { ui.setBg("#2b3245", "#0a0b10", null) }
    override fun onOk(line: Line, i: Int, v: View) { (v as? PosterCard)?.item?.let { ui.openDetail(it.optString("id")) } }
    override fun onMenu(line: Line, i: Int, v: View) {
        val id = (v as? PosterCard)?.item?.optString("id") ?: return
        ui.api("fav(${ui.q(id)})") { r -> if (r != null) ui.toast(r.optString("msg")) }
    }
}
