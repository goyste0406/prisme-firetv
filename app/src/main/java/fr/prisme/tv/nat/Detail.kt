package fr.prisme.tv.nat

import android.annotation.SuppressLint
import android.graphics.Color
import android.text.SpannableStringBuilder
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import fr.prisme.tv.R
import org.json.JSONObject

/** Fiche d'un film ou d'une série (maquettes 2, 3 et 5) */
@SuppressLint("ViewConstructor")
class DetailScreen(ui: NativeUi, val itemId: String, val fromWeb: Boolean) : Screen(ui) {
    private val sv = ScrollView(ui.ctx)
    private val content = LinearLayout(ui.ctx)
    override val vscroll: ScrollView get() = sv
    private var d: JSONObject? = null
    private var playBtn: Btn? = null
    private var favBtn: Btn? = null
    private var srcBtn: Btn? = null
    private var season = 0
    private var epLineIndex = -1
    private var epSection: RowSection? = null
    private var preloaded = false
    private val preloadRun = Runnable { startPreload() }

    init {
        sv.isVerticalScrollBarEnabled = false
        sv.overScrollMode = View.OVER_SCROLL_NEVER
        sv.isFocusable = false
        sv.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        sv.clipChildren = false
        content.orientation = LinearLayout.VERTICAL
        content.clipChildren = false; content.clipToPadding = false
        sv.addView(content, FrameLayout.LayoutParams(K.MATCH, K.WRAP))
        addView(sv, K.lp(K.MATCH, K.MATCH))
        val wait = K.text(ui.ctx, 20f, K.white(0.6f)); wait.text = "Chargement de la fiche…"
        content.addView(wait, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(64); topMargin = K.px(560) })
        ui.api("detail(${ui.q(itemId)})") { o -> if (o != null && !o.has("error")) update(o) else ui.toast("Fiche indisponible") }
    }

    fun update(o: JSONObject) {
        val first = d == null
        val oldLi = li
        val oldIdx = lines.map { it.idx }
        val oldScroll = sv.scrollY
        d = o
        if (first) season = o.optInt("ssel", 0)
        build(o)
        applyBackground()
        if (first) {
            li = 0; lines.firstOrNull()?.idx = 0
        } else {
            li = oldLi.coerceIn(0, maxOf(0, lines.size - 1))
            lines.forEachIndexed { i, l -> l.idx = (oldIdx.getOrNull(i) ?: 0).coerceIn(0, maxOf(0, l.count - 1)) }
        }
        post {
            if (!first) sv.scrollTo(0, oldScroll)
            if (ui.top() === this) apply(true)
        }
    }

    private fun build(o: JSONObject) {
        content.removeAllViews(); lines.clear(); epLineIndex = -1
        val series = o.optString("ty") == "s"
        // ---- haut de fiche (un écran entier, contenu calé en bas)
        val top = FrameLayout(ui.ctx)
        val col = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL; clipChildren = false; clipToPadding = false }
        val kick = K.text(ui.ctx, 15f, K.white(0.7f), 600); kick.letterSpacing = 0.08f; kick.text = o.optString("kick")
        col.addView(kick)
        val title = K.text(ui.ctx, 66f, Color.WHITE, 400, 2)
        bigTitle(title, o, 86f)
        col.addView(title, LinearLayout.LayoutParams(K.px(1000), K.WRAP).apply { topMargin = K.px(14) })
        val meta = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        metaRow(ui.ctx, meta, o)
        col.addView(meta, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(14) })
        val syn = K.text(ui.ctx, 18f, K.white(0.85f), 400, 5); syn.setLineSpacing(0f, 1.3f)
        syn.text = o.optString("s").ifEmpty { if (o.optBoolean("loading")) "Chargement de la fiche…" else "" }
        col.addView(syn, LinearLayout.LayoutParams(K.px(700), K.WRAP).apply { topMargin = K.px(14) })
        val crew = K.text(ui.ctx, 16f, K.white(0.6f), 400, 4); crew.setLineSpacing(0f, 1.35f)
        val sb = SpannableStringBuilder()
        fun line(label: String, v: String) {
            if (v.isBlank()) return
            if (sb.isNotEmpty()) sb.append("\n")
            val s = sb.length; sb.append(label).append(" : ")
            sb.setSpan(ForegroundColorSpan(K.white(0.92f)), s, sb.length, 0)
            sb.setSpan(StyleSpan(android.graphics.Typeface.BOLD), s, sb.length, 0)
            sb.append(v)
        }
        line(if (series) "Création" else "Réalisation", o.optString("dir"))
        line("Avec", o.optString("castLine"))
        line("Ajouté", o.optString("added"))
        crew.text = sb
        if (sb.isNotEmpty()) col.addView(crew, LinearLayout.LayoutParams(K.px(900), K.WRAP).apply { topMargin = K.px(14) })
        // boutons
        val btns = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL; clipChildren = false }
        val bl = ArrayList<View>()
        val pb = Btn(ui.ctx, o.optString("playLabel", "Lecture"), R.drawable.ic_play)
        playBtn = pb; btns.addView(pb, LinearLayout.LayoutParams(K.WRAP, K.px(58))); bl.add(pb)
        val nSrc = o.objs("sources").size
        if (!series && nSrc > 1) {
            val s = Btn(ui.ctx, "Sources", R.drawable.ic_layers)
            srcBtn = s; btns.addView(s, LinearLayout.LayoutParams(K.WRAP, K.px(58)).apply { leftMargin = K.px(16) }); bl.add(s)
        } else srcBtn = null
        val fb = Btn(ui.ctx, null, if (o.optBoolean("fav")) R.drawable.ic_heart_on else R.drawable.ic_heart, round = true)
        favBtn = fb; btns.addView(fb, LinearLayout.LayoutParams(K.px(58), K.px(58)).apply { leftMargin = K.px(16) }); bl.add(fb)
        col.addView(btns, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(22) })
        val srcLine = o.optString("srcLine")
        if (srcLine.isNotBlank()) {
            val sl = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
            val a = K.text(ui.ctx, 16f, K.white(0.65f)); a.text = "Source : "
            val b = K.text(ui.ctx, 16f, Color.WHITE, 600); b.text = srcLine
            sl.addView(a); sl.addView(b)
            val q = o.optString("srcQ")
            if (q.isNotEmpty()) sl.addView(qBadge(ui.ctx, q, 22f, 12f).apply { (layoutParams as LinearLayout.LayoutParams).leftMargin = K.px(10) })
            if (nSrc > 1) { val c = K.text(ui.ctx, 16f, K.white(0.5f)); c.text = "  ·  $nSrc sources"; sl.addView(c) }
            col.addView(sl, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(16) })
        }
        top.addView(col, FrameLayout.LayoutParams(K.MATCH, K.WRAP, Gravity.BOTTOM).apply { leftMargin = K.px(64); rightMargin = K.px(120); bottomMargin = K.px(64) })
        content.addView(top, LinearLayout.LayoutParams(K.MATCH, K.px(720)))
        lines.add(StaticLine(bl, top))

        // ---- séries : saisons et épisodes
        if (series) {
            val seasons = o.objs("seasons")
            if (seasons.isNotEmpty()) {
                season = season.coerceIn(0, seasons.size - 1)
                val sec = RowSection(ui.ctx, "Saisons", null, 10f)
                val chips = ArrayList<View>()
                seasons.forEachIndexed { i, s ->
                    val c = Chip(ui.ctx, s.optString("label")); c.selected2 = i == season
                    sec.add(c, 10f); chips.add(c)
                }
                content.addView(sec, LinearLayout.LayoutParams(K.MATCH, K.WRAP))
                lines.add(StaticLine(chips, sec, sec.scroller).also { it.idx = season })
                val es = RowSection(ui.ctx, "Épisodes", null, 4f)
                epSection = es
                content.addView(es, LinearLayout.LayoutParams(K.MATCH, K.WRAP))
                epLineIndex = lines.size
                lines.add(StaticLine(emptyList(), es, es.scroller))
                fillEpisodes()
            }
        }
        // ---- sources (films)
        if (!series && nSrc > 0) {
            val sec = RowSection(ui.ctx, if (nSrc > 1) "Sources disponibles" else "Source", if (nSrc > 1) "$nSrc · OK pour lire depuis cette source" else null)
            val v = ArrayList<View>()
            o.objs("sources").forEach { s -> val c = SourceCard(ui.ctx); c.bind(s); sec.add(c, 22f); v.add(c) }
            v.forEach { it.layoutParams = (it.layoutParams as LinearLayout.LayoutParams).apply { width = K.px(340) } }
            content.addView(sec, LinearLayout.LayoutParams(K.MATCH, K.WRAP))
            lines.add(StaticLine(v, sec, sec.scroller))
        }
        // ---- distribution
        val cast = o.objs("cast")
        if (cast.isNotEmpty()) {
            val sec = RowSection(ui.ctx, "Distribution", null)
            val v = ArrayList<View>()
            cast.forEach { c -> val cc = CastCard(ui.ctx); cc.bind(c); sec.add(cc, 26f); v.add(cc) }
            content.addView(sec, LinearLayout.LayoutParams(K.MATCH, K.WRAP))
            lines.add(StaticLine(v, sec, sec.scroller))
        }
        // ---- titres similaires
        val sim = o.objs("similar")
        if (sim.isNotEmpty()) {
            val sec = RowSection(ui.ctx, "Titres similaires", null)
            val v = ArrayList<View>()
            sim.forEach { s -> val p = PosterCard(ui.ctx); p.bind(s); sec.add(p, 26f); v.add(p) }
            content.addView(sec, LinearLayout.LayoutParams(K.MATCH, K.WRAP))
            lines.add(StaticLine(v, sec, sec.scroller))
        }
        content.addView(View(ui.ctx), LinearLayout.LayoutParams(K.MATCH, K.px(70)))
    }

    private fun fillEpisodes() {
        val o = d ?: return
        val es = epSection ?: return
        val seasons = o.objs("seasons")
        val s = seasons.getOrNull(season) ?: return
        es.inner.removeAllViews()
        val c1 = K.color(o.optString("c1"), Color.DKGRAY); val c2 = K.color(o.optString("c2"), Color.BLACK)
        val v = ArrayList<View>()
        val sn = s.optString("n")
        s.objs("eps").forEach { e ->
            val c = EpCard(ui.ctx)
            c.bind(e, "S$sn · E${e.optInt("num")}", c1, c2)
            es.add(c, 26f); v.add(c)
        }
        if (v.isEmpty()) {
            val t = K.text(ui.ctx, 16f, K.white(0.6f)); t.text = if (o.optBoolean("loading")) "Chargement des épisodes…" else "Aucun épisode"
            es.inner.addView(t)
        }
        es.scroller.scrollTo(0, 0)
        if (epLineIndex >= 0) lines[epLineIndex] = StaticLine(v, es, es.scroller).also { it.idx = 0 }
    }

    override fun applyBackground() {
        val o = d
        if (o == null) ui.setBg("#2b3245", "#0a0b10", null) else ui.setBg(o.optString("c1"), o.optString("c2"), o.optString("bd").ifEmpty { null })
    }

    override fun scrollTargetFor(n: Int): Int? = if (n == 0) 0 else null

    override fun onFocus(line: Line, i: Int, v: View) {
        removeCallbacks(preloadRun)
        if (v === playBtn) postDelayed(preloadRun, 500)
        else if (preloaded) { preloaded = false; ui.unpreload() }
        if (v is Chip && line === lines.getOrNull(epLineIndex - 1) && i != season) {
            (line as StaticLine).views.forEachIndexed { k, c -> (c as Chip).selected2 = k == i }
            season = i
            fillEpisodes()
        }
    }

    /** Épisode à lancer avec le bouton Lecture (reprise ou premier de la saison choisie) */
    private fun playTarget(): Pair<Int, Int> {
        val o = d ?: return Pair(0, 0)
        val r = o.optJSONObject("resume")
        if (r != null) return Pair(r.optInt("ss"), r.optInt("ep"))
        val s = o.objs("seasons").getOrNull(season) ?: return Pair(0, 0)
        val e = s.objs("eps").firstOrNull() ?: return Pair(0, 0)
        return Pair(season + 1, e.optInt("num"))
    }

    private fun startPreload() {
        val o = d ?: return
        if (ui.top() !== this) return
        val (ss, ep) = if (o.optString("ty") == "s") playTarget() else Pair(0, 0)
        ui.preload(itemId, ss, ep)
        preloaded = true
    }

    override fun onHidden() {
        removeCallbacks(preloadRun)
        if (preloaded) { preloaded = false; ui.unpreload() }
    }

    override fun onShown() {
        // reprise, favori ou qualité ont pu changer pendant la lecture
        ui.api("detail(${ui.q(itemId)})") { o -> if (o != null && !o.has("error")) update(o) }
    }

    override fun onOk(line: Line, i: Int, v: View) {
        val o = d ?: return
        when {
            v === playBtn -> {
                removeCallbacks(preloadRun); preloaded = false
                if (o.optString("ty") == "s") { val (ss, ep) = playTarget(); if (ss > 0) ui.play(itemId, "", ss, ep) else ui.toast("Épisodes en cours de chargement") }
                else ui.play(itemId, "", 0, 0)
            }
            v === favBtn -> toggleFav()
            v === srcBtn -> ui.push(SourceDialog(ui, this, o))
            v is SourceCard -> { preloaded = false; ui.play(itemId, v.srcId, 0, 0) }
            v is EpCard -> { val e = v.ep ?: return; preloaded = false; ui.play(itemId, "", season + 1, e.optInt("num")) }
            v is Chip -> go(li + 1)
            v is CastCard -> ui.webScreen("actor", v.actorId)
            v is PosterCard -> v.item?.let { ui.openDetail(it.optString("id")) }
        }
    }

    fun playSource(src: String) { preloaded = false; ui.play(itemId, src, 0, 0) }

    override fun onMenu(line: Line, i: Int, v: View) { if (v !is PosterCard) toggleFav() }

    private fun toggleFav() {
        ui.api("fav(${ui.q(itemId)})") { r ->
            if (r == null) return@api
            ui.toast(r.optString("msg"))
            val on = r.optBoolean("fav")
            d?.put("fav", on)
            (favBtn?.getChildAt(0) as? android.widget.ImageView)?.setImageResource(if (on) R.drawable.ic_heart_on else R.drawable.ic_heart)
        }
    }
}

/** Fenêtre de choix de la source (maquette 4) */
@SuppressLint("ViewConstructor")
class SourceDialog(ui: NativeUi, private val det: DetailScreen, d: JSONObject) : Screen(ui) {
    override val modal = true
    private val rows = ArrayList<SrcRow>()

    @SuppressLint("ViewConstructor")
    inner class SrcRow(val s: JSONObject) : LinearLayout(ui.ctx), Foc {
        private val texts = ArrayList<android.widget.TextView>()
        private val ok = s.optBoolean("ok", true)
        init {
            orientation = HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            setPadding(K.px(18), K.px(14), K.px(18), K.px(14))
            addView(FrameLayout(ui.ctx).apply { addView(qBadge(ui.ctx, s.optString("q"), 30f, 14f)) }, LayoutParams(K.px(92), K.WRAP))
            val mid = LinearLayout(ui.ctx).apply { orientation = VERTICAL }
            val n = K.text(ui.ctx, 19f, Color.WHITE, 600); n.text = s.optString("pl") + if (s.optBoolean("def")) "  · par défaut" else ""
            val dd = K.text(ui.ctx, 14f, K.white(0.6f)); dd.text = listOf(s.optString("name"), s.optString("codec")).filter { it.isNotBlank() }.joinToString(" · ")
            mid.addView(n); mid.addView(dd, LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(3) })
            if (!ok) { val w = K.text(ui.ctx, 13f, Color.parseColor("#ffb340")); w.text = "Non compatible : ce Fire Stick lit jusqu'en 1080p"; mid.addView(w, LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(3) }) }
            addView(mid, LayoutParams(0, K.WRAP, 1f).apply { leftMargin = K.px(16) })
            val a = K.text(ui.ctx, 13f, K.white(0.6f), 400, 3); a.text = s.optString("audio").replace(" | ", "\n"); a.gravity = Gravity.END
            addView(a, LayoutParams(K.px(220), K.WRAP).apply { leftMargin = K.px(16) })
            texts.add(n); texts.add(dd); texts.add(a)
            alpha = if (ok) 1f else 0.55f
            paint(false)
        }
        private fun paint(on: Boolean) {
            background = K.round(if (on) Color.WHITE else K.white(0.07f), 16f)
            texts[0].setTextColor(if (on) Color.BLACK else Color.WHITE)
            texts[1].setTextColor(if (on) K.black(0.6f) else K.white(0.6f))
            texts[2].setTextColor(if (on) K.black(0.6f) else K.white(0.6f))
        }
        override fun foc(on: Boolean) { paint(on); lift(on, 1.03f); alpha = if (on || ok) 1f else 0.55f }
    }

    init {
        setBackgroundColor(K.black(0.72f))
        val box = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL; clipChildren = false }
        box.setPadding(K.px(34), K.px(30), K.px(34), K.px(30))
        box.background = K.round(Color.argb(250, 30, 30, 38), 28f, 1, K.white(0.14f))
        val n = d.objs("sources").size
        val k = K.text(ui.ctx, 15f, K.white(0.7f), 600); k.letterSpacing = 0.08f
        k.text = "$n SOURCE${if (n > 1) "S" else ""} · CHOISISSEZ LA VERSION"
        box.addView(k)
        val t = K.text(ui.ctx, 32f, Color.WHITE, 700); t.text = d.optString("t")
        box.addView(t, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(6); bottomMargin = K.px(12) })
        d.objs("sources").forEachIndexed { i, s ->
            val r = SrcRow(s); rows.add(r)
            box.addView(r, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = if (i > 0) K.px(8) else 0 })
            lines.add(StaticLine(listOf(r), r))
        }
        val f = K.text(ui.ctx, 14f, K.white(0.5f)); f.text = "OK pour lire cette source · Retour pour fermer"
        box.addView(f, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(10) })
        addView(box, FrameLayout.LayoutParams(K.px(800), K.WRAP, Gravity.CENTER))
        li = rows.indexOfFirst { it.s.optBoolean("def") }.coerceAtLeast(0)
    }

    override fun onOk(line: Line, i: Int, v: View) {
        val r = v as? SrcRow ?: return
        ui.pop()
        det.playSource(r.s.optString("id"))
    }
}
