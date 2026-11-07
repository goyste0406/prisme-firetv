package fr.prisme.tv.nat

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import org.json.JSONObject

/** Interrupteur (dessiné, très léger) */
class SwitchV(ctx: Context) : View(ctx) {
    var on = false
        set(v) { field = v; invalidate() }
    var onLight = false
        set(v) { field = v; invalidate() }
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)
    override fun onDraw(c: Canvas) {
        val r = height / 2f
        p.color = if (on) Color.parseColor("#30d158") else if (onLight) K.black(0.18f) else K.white(0.22f)
        c.drawRoundRect(0f, 0f, width.toFloat(), height.toFloat(), r, r, p)
        p.color = Color.WHITE
        val k = r - K.pxf(3f)
        c.drawCircle(if (on) width - r else r, r, k, p)
    }
}

fun settingsBg(): Drawable {
    val base = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(Color.parseColor("#10131c"), Color.parseColor("#050507")))
    val glow = GradientDrawable().apply {
        gradientType = GradientDrawable.RADIAL_GRADIENT
        gradientRadius = K.pxf(700f)
        setGradientCenter(0.8f, 0.2f)
        colors = intArrayOf(Color.parseColor("#662b3245"), Color.TRANSPARENT)
    }
    return LayerDrawable(arrayOf<Drawable>(base, glow))
}

/** Ligne de réglage : titre, petite ligne, valeur ou interrupteur */
@SuppressLint("ViewConstructor")
class SetRow(ctx: Context, private val compact: Boolean = false) : LinearLayout(ctx) {
    private val l = K.text(ctx, if (compact) 17f else 18f, Color.WHITE, 600, 2)
    private val s = K.text(ctx, 13.5f, K.white(0.55f), 400, 4)
    private val v = K.text(ctx, 16f, K.white(0.65f), 500, 2)
    private val sw = SwitchV(ctx)
    private val hdr = K.text(ctx, 13f, K.white(0.5f), 600, 2)
    private val logT = K.text(ctx, 13.5f, K.white(0.75f), 400, 4)
    private val logV = K.text(ctx, 13f, K.white(0.45f), 500)
    private val main = LinearLayout(ctx)
    private val col = LinearLayout(ctx)
    var item: JSONObject? = null
    private var on = false
    private var mode = 0 // 0 réglage, 1 titre de section, 2 journal, 3 texte simple

    init {
        orientation = VERTICAL
        hdr.letterSpacing = 0.08f
        addView(hdr, LayoutParams(K.MATCH, K.WRAP).apply { leftMargin = K.px(6); topMargin = K.px(14); bottomMargin = K.px(4) })
        main.orientation = HORIZONTAL; main.gravity = Gravity.CENTER_VERTICAL
        main.minimumHeight = K.px(if (compact) 50 else 60)
        main.setPadding(K.px(if (compact) 16 else 20), K.px(10), K.px(if (compact) 16 else 20), K.px(10))
        col.orientation = VERTICAL
        col.addView(l, LayoutParams(K.MATCH, K.WRAP))
        col.addView(s, LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(3) })
        main.addView(col, LayoutParams(0, K.WRAP, 1f))
        v.gravity = Gravity.END
        v.maxWidth = K.px(if (compact) 120 else 300)
        main.addView(v, LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(16) })
        main.addView(sw, LayoutParams(K.px(50), K.px(30)).apply { leftMargin = K.px(16) })
        val lg = LinearLayout(ctx).apply { orientation = HORIZONTAL; tag = "log" }
        logV.minWidth = K.px(70)
        lg.addView(logV, LayoutParams(K.WRAP, K.WRAP))
        lg.addView(logT, LayoutParams(0, K.WRAP, 1f))
        lg.setPadding(K.px(14), K.px(7), K.px(14), K.px(7))
        addView(main, LayoutParams(K.MATCH, K.WRAP))
        addView(lg, LayoutParams(K.MATCH, K.WRAP))
    }

    val focusable get() = mode == 0 || mode == 2

    fun bind(o: JSONObject, focused: Boolean) {
        item = o
        val lg = findViewWithTag<View>("log")
        mode = when { o.has("hdr") -> 1; o.optBoolean("log") -> 2; else -> 0 }
        hdr.visibility = if (mode == 1) View.VISIBLE else View.GONE
        main.visibility = if (mode == 0) View.VISIBLE else View.GONE
        lg.visibility = if (mode == 2) View.VISIBLE else View.GONE
        when (mode) {
            1 -> hdr.text = o.optString("hdr").uppercase(java.util.Locale.FRANCE)
            2 -> { logT.text = o.optString("l"); logV.text = o.optString("v") }
            else -> {
                l.text = o.optString("l")
                val sub = o.optString("s"); s.text = sub; s.visibility = if (sub.isEmpty()) View.GONE else View.VISIBLE
                val hasSw = !o.isNull("sw") && o.has("sw")
                sw.visibility = if (hasSw) View.VISIBLE else View.GONE
                if (hasSw) sw.on = o.optBoolean("sw")
                val vv = o.optString("v")
                v.text = vv; v.visibility = if (vv.isEmpty() || (hasSw && vv.length > 40)) View.GONE else View.VISIBLE
            }
        }
        setFoc(focused)
    }

    fun setFoc(f: Boolean) {
        on = f && focusable
        val o = item
        val red = o?.optBoolean("red") == true
        when (mode) {
            0 -> {
                val act = o?.optString("act").orEmpty().isNotEmpty()
                main.background = K.round(if (on) Color.WHITE else K.white(if (act) 0.07f else 0.035f), if (compact) 14f else 16f)
                l.setTextColor(if (on) Color.BLACK else if (red) Color.parseColor("#ff6961") else Color.WHITE)
                s.setTextColor(if (on) K.black(0.6f) else K.white(0.55f))
                v.setTextColor(if (on) K.black(0.6f) else K.white(0.65f))
                sw.onLight = on
            }
            2 -> {
                background = if (on) K.round(K.white(0.12f), 10f) else null
            }
            else -> background = null
        }
        val was = K.instant; K.instant = true
        try { main.lift(on, 1.02f) } finally { K.instant = was }
        elevation = if (on) K.pxf(6f) else 0f
    }
}

/** Liste de réglages défilante (les très longues listes de catégories restent fluides) */
class SetList(ctx: Context, private val compact: Boolean = false) : RecyclerView(ctx) {
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
        setPadding(K.px(8), K.px(4), K.px(8), K.px(60))
        adapter = object : Adapter<ViewHolder>() {
            override fun getItemCount() = items.size
            override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
                val r = SetRow(ctx, compact)
                r.layoutParams = LayoutParams(K.MATCH, K.WRAP).apply { bottomMargin = K.px(8) }
                return object : ViewHolder(r) {}
            }
            override fun onBindViewHolder(h: ViewHolder, pos: Int) { (h.itemView as SetRow).bind(items[pos], pos == fi) }
        }
    }

    fun canFocus(i: Int): Boolean { val o = items.getOrNull(i) ?: return false; return !o.has("hdr") && !o.optBoolean("info") }

    fun set(list: List<JSONObject>, f: Int) {
        items = list; fi = f
        adapter?.notifyDataSetChanged()
        if (f >= 0) lm.scrollToPositionWithOffset(f, K.px(140)) else lm.scrollToPosition(0)
    }

    fun setFocus(i: Int) {
        val old = fi; fi = i
        if (old >= 0 && old != i) (lm.findViewByPosition(old) as? SetRow)?.setFoc(false) ?: adapter?.notifyItemChanged(old)
        if (i < 0) return
        val v = lm.findViewByPosition(i) as? SetRow
        if (v != null) {
            v.setFoc(true)
            val pad = K.px(110)
            if (v.top < pad) scrollBy(0, v.top - pad) else if (v.bottom > height - pad) scrollBy(0, v.bottom - height + pad)
        } else {
            lm.scrollToPositionWithOffset(i, K.px(160))
            adapter?.notifyItemChanged(i)
        }
    }

    fun update(i: Int) { adapter?.notifyItemChanged(i) }
}

// ==================================================================================================== Réglages
@SuppressLint("ViewConstructor")
class SettingsScreen(ui: NativeUi, private val kind: String = "root", private val pid: String = "") : Screen(ui) {
    private val kick = K.text(ui.ctx, 14f, K.white(0.55f), 600)
    private val title = K.text(ui.ctx, 40f, Color.WHITE, 700, 2)
    private val sub = K.text(ui.ctx, 15f, K.white(0.6f), 400, 3)
    private val left = SetList(ui.ctx, compact = true)
    private val right = SetList(ui.ctx)
    private val hint = K.text(ui.ctx, 14f, K.white(0.45f))
    private var data: JSONObject? = null
    private var zone = 0
    private var lf = 0
    private var rf = -1
    private var busy = false
    private val root get() = kind == "root"

    init {
        background = settingsBg()
        kick.letterSpacing = 0.08f
        val head = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL }
        head.addView(kick)
        head.addView(title, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(4) })
        head.addView(sub, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(6) })
        addView(head, FrameLayout.LayoutParams(K.px(360), K.WRAP).apply { leftMargin = K.px(64); topMargin = K.px(48) })
        addView(left, FrameLayout.LayoutParams(K.px(376), K.MATCH).apply { leftMargin = K.px(56); topMargin = K.px(if (kind == "root") 138 else 170); bottomMargin = K.px(10) })
        addView(right, FrameLayout.LayoutParams(K.px(776), K.MATCH).apply { leftMargin = K.px(448); topMargin = K.px(44); bottomMargin = K.px(10) })
        hint.setBackgroundColor(Color.argb(230, 6, 6, 9))
        hint.setPadding(K.px(8), K.px(8), K.px(8), K.px(8))
        hint.text = when (kind) {
            "plm" -> "◀ actions · ▶ catégories · OK afficher ou masquer · les changements s'appliquent en quittant la page"
            "diag" -> "◀ actions · ▶ informations et journal · Retour : réglages"
            else -> "▲▼ rubriques et réglages · ▶ entrer · OK changer · Retour : accueil"
        }
        addView(hint, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.BOTTOM).apply { leftMargin = K.px(448); bottomMargin = K.px(14) })
        load(false)
    }

    private fun call(fn: String, extra: String = ""): String = "$fn(${ui.q(kind)},${ui.q(pid)}$extra)"

    private fun load(keep: Boolean) {
        ui.api(call("setPage")) { o ->
            if (o == null) return@api
            if (o.optBoolean("back")) { ui.pop(); return@api }
            show(o, keep)
        }
    }

    private fun obj(vararg kv: Pair<String, Any>): JSONObject { val o = JSONObject(); kv.forEach { o.put(it.first, it.second) }; return o }

    private fun show(o: JSONObject, keep: Boolean) {
        data = o
        kick.text = o.optString("kick")
        title.text = o.optString("title")
        val sb = o.optString("sub"); sub.text = sb; sub.visibility = if (sb.isEmpty()) View.GONE else View.VISIBLE
        val secs = o.objs("secs")
        // colonne de gauche
        val L = ArrayList<JSONObject>()
        if (root) secs.forEach { s -> L.add(obj("l" to s.optString("n"), "v" to s.optString("c"), "act" to "sec")) }
        else o.objs("left").forEach { r -> if (r.optString("act").isEmpty()) r.put("info", true); L.add(r) }
        if (!keep) { lf = L.indexOfFirst { !it.optBoolean("info") }.coerceAtLeast(0) }
        lf = lf.coerceIn(0, maxOf(0, L.size - 1))
        left.set(L, if (zone == 0) lf else -1)
        fillRight(keep)
        if (!keep) { zone = if (root || L.any { !it.optBoolean("info") }) 0 else 1; if (zone == 1) rf = firstRight() }
        paint()
    }

    private fun rightItems(): List<JSONObject> {
        val d = data ?: return emptyList()
        val out = ArrayList<JSONObject>()
        val secs = d.objs("secs")
        val list = if (root) listOfNotNull(secs.getOrNull(lf)) else secs
        for (s in list) {
            out.add(obj("hdr" to s.optString("t")))
            s.objs("rows").forEach { r -> if (r.optString("act").isEmpty() && !r.optBoolean("log")) r.put("info", true); out.add(r) }
        }
        return out
    }

    private fun firstRight(): Int = right.items.indices.firstOrNull { right.canFocus(it) } ?: right.items.indices.firstOrNull { !right.items[it].has("hdr") } ?: -1

    private fun fillRight(keep: Boolean) {
        val items = rightItems()
        right.set(items, -1)
        if (!keep || rf >= items.size) rf = -1
        if (zone == 1) { if (rf < 0) rf = firstRight(); right.setFocus(rf) }
    }

    private fun paint() {
        left.setFocus(if (zone == 0) lf else -1)
        right.setFocus(if (zone == 1) rf else -1)
    }

    /** Déplacement vertical : on saute les titres de section (et les lignes d'information à gauche) */
    private fun step(list: SetList, from: Int, d: Int, allowInfo: Boolean): Int {
        var i = from + d
        while (i in list.items.indices) {
            val o = list.items[i]
            if (!o.has("hdr") && (allowInfo || !o.optBoolean("info"))) return i
            i += d
        }
        return from
    }

    override fun key(code: Int): Boolean {
        if (busy) return true
        when (code) {
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN -> {
                val d = if (code == KeyEvent.KEYCODE_DPAD_DOWN) 1 else -1
                if (zone == 0) {
                    val n = step(left, lf, d, false)
                    if (n != lf) { lf = n; left.setFocus(lf); if (root) fillRight(false) }
                } else {
                    val n = step(right, rf, d, true)
                    if (n != rf) { rf = n; right.setFocus(rf) }
                }
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> if (zone == 0) { val f = firstRight(); if (f >= 0) { zone = 1; if (rf < 0) rf = f; paint() } }
            KeyEvent.KEYCODE_DPAD_LEFT -> if (zone == 1 && left.items.isNotEmpty() && left.items.any { !it.optBoolean("info") }) { zone = 0; paint() }
            else -> return false
        }
        return true
    }

    override fun ok() {
        if (busy) return
        if (zone == 0 && root) { val f = firstRight(); if (f >= 0) { zone = 1; rf = f; paint() }; return }
        val list = if (zone == 0) left else right
        val i = if (zone == 0) lf else rf
        val o = list.items.getOrNull(i) ?: return
        val a = o.optString("act")
        if (a.isEmpty()) return
        // interrupteur : il bascule tout de suite, la couche de données suit
        if (o.has("sw") && !o.isNull("sw")) { o.put("sw", !o.optBoolean("sw")); list.update(i) }
        busy = true
        ui.api(call("setAct", ",${ui.q(a)}")) { r ->
            busy = false
            if (r == null) return@api
            when {
                r.has("nav") -> ui.push(SettingsScreen(ui, r.optString("nav"), r.optString("id")))
                r.optBoolean("web") -> ui.toWeb()
                r.optBoolean("back") -> { ui.pop() }
                r.has("patch") -> {
                    val p = r.getJSONObject("patch")
                    val k = right.items.indexOfFirst { it.optString("act") == p.optString("act") }
                    if (k >= 0) { right.items[k].put("sw", p.optBoolean("sw")); right.items[k].put("s", p.optString("s")); right.update(k) }
                }
                else -> show(r, keep = true)
            }
        }
    }

    override fun onEvent(kind: String, o: JSONObject) {
        if (kind == "setpage" && this.kind == "diag") load(true)
    }

    override fun onShown() { load(true) }

    override fun restoreFocus() { paint() }

    override fun onBack(): Boolean {
        if (root && zone == 1) { zone = 0; paint(); return true }
        ui.js("nativeApi.setLeave(${ui.q(kind)})")
        ui.pop()
        return true
    }
}
