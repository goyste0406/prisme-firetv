package fr.prisme.tv.nat

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.os.SystemClock
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import fr.prisme.tv.R
import org.json.JSONObject
import java.util.Locale

/** Barre de lecture (avancement + curseur) */
class SeekBarV(ctx: Context) : View(ctx) {
    var frac = 0f
        set(v) { field = v.coerceIn(0f, 1f); invalidate() }
    var focusedBar = false
        set(v) { field = v; invalidate() }
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)
    override fun onDraw(c: Canvas) {
        val h = K.pxf(6f); val cy = height / 2f; val r = h / 2
        p.color = K.white(0.22f); c.drawRoundRect(0f, cy - r, width.toFloat(), cy + r, r, r, p)
        p.color = Color.WHITE; c.drawRoundRect(0f, cy - r, width * frac, cy + r, r, r, p)
        val kr = if (focusedBar) K.pxf(11f) else K.pxf(7f)
        if (focusedBar) { p.color = K.white(0.25f); c.drawCircle(width * frac, cy, kr + K.pxf(5f), p) }
        p.color = Color.WHITE; c.drawCircle(width * frac, cy, kr, p)
    }
}

/** Bouton du lecteur (pastille avec titre et petite ligne) */
@SuppressLint("ViewConstructor")
class PBtn(ctx: Context, val key: String, label: String, sub: String, icon: Int = 0) : LinearLayout(ctx), Foc {
    private val ic = ImageView(ctx)
    private val t = K.text(ctx, 16f, Color.WHITE, 600)
    private val s = K.text(ctx, 12.5f, K.white(0.6f), 500)

    init {
        orientation = HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
        setPadding(K.px(18), 0, K.px(20), 0)
        if (icon != 0) { ic.setImageResource(icon); addView(ic, LayoutParams(K.px(20), K.px(20)).apply { rightMargin = K.px(10) }) }
        val col = LinearLayout(ctx).apply { orientation = VERTICAL }
        t.text = label; col.addView(t, LayoutParams(K.WRAP, K.WRAP))
        s.text = sub; s.visibility = if (sub.isEmpty()) View.GONE else View.VISIBLE
        col.addView(s, LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(2) })
        addView(col)
        paint(false)
    }

    private fun paint(on: Boolean) {
        background = K.round(if (on) Color.WHITE else K.white(0.12f), 28f)
        t.setTextColor(if (on) Color.BLACK else Color.WHITE)
        s.setTextColor(if (on) K.black(0.6f) else K.white(0.6f))
        ic.setColorFilter(if (on) Color.BLACK else Color.WHITE)
    }

    override fun foc(on: Boolean) { paint(on); lift(on, 1.05f); elevation = if (on) K.pxf(8f) else 0f }
}

// ==================================================================================================== Panneau latéral (pistes, format, source)
@SuppressLint("ViewConstructor")
class SidePanel(ui: NativeUi, kick: String, title: String, sections: List<Pair<String, List<Item>>>, private val onPick: (Int, Int) -> Unit) : Screen(ui) {
    data class Item(val label: String, val sub: String = "", val sel: Boolean = false, val warn: String = "", val dim: Boolean = false)
    override val modal = true
    private val sv = ScrollView(ui.ctx)
    override val vscroll: ScrollView get() = sv

    @SuppressLint("ViewConstructor")
    inner class Row(val sec: Int, val idx: Int, it: Item) : LinearLayout(ui.ctx), Foc {
        private val t = K.text(ui.ctx, 18f, Color.WHITE, 600, 2)
        private val s = K.text(ui.ctx, 13f, K.white(0.55f), 500, 2)
        private val w = K.text(ui.ctx, 13f, Color.parseColor("#ffb340"), 500, 2)
        private val ck = ImageView(ui.ctx)
        private val sel = it.sel
        private val dim = it.dim
        init {
            orientation = HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            setPadding(K.px(18), K.px(12), K.px(18), K.px(12))
            minimumHeight = K.px(58)
            val col = LinearLayout(ui.ctx).apply { orientation = VERTICAL }
            t.text = it.label; col.addView(t)
            if (it.sub.isNotEmpty()) { s.text = it.sub; col.addView(s, LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(2) }) }
            if (it.warn.isNotEmpty()) { w.text = it.warn; col.addView(w, LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(3) }) }
            addView(col, LayoutParams(0, K.WRAP, 1f))
            ck.setImageResource(R.drawable.ic_check)
            ck.visibility = if (sel) View.VISIBLE else View.INVISIBLE
            addView(ck, LayoutParams(K.px(20), K.px(20)).apply { leftMargin = K.px(12) })
            paint(false)
        }
        private fun paint(on: Boolean) {
            background = K.round(if (on) Color.WHITE else K.white(0.07f), 14f)
            t.setTextColor(if (on) Color.BLACK else Color.WHITE)
            s.setTextColor(if (on) K.black(0.55f) else K.white(0.55f))
            ck.setColorFilter(if (on) Color.BLACK else Color.parseColor("#7cc4ff"))
            alpha = if (dim && !on) 0.55f else 1f
        }
        override fun foc(on: Boolean) { paint(on); lift(on, 1.03f) }
    }

    init {
        val panel = FrameLayout(ui.ctx)
        panel.background = K.round(Color.argb(246, 18, 18, 24), 0f)
        val inner = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL; clipChildren = false; clipToPadding = false }
        inner.setPadding(K.px(40), K.px(44), K.px(40), K.px(60))
        val k = K.text(ui.ctx, 14f, K.white(0.6f), 600); k.text = kick.uppercase(Locale.FRANCE); k.letterSpacing = 0.08f
        inner.addView(k)
        val tt = K.text(ui.ctx, 30f, Color.WHITE, 700, 2); tt.text = title
        inner.addView(tt, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(6) })
        var first: Int? = null
        sections.forEachIndexed { si, (head, items) ->
            if (head.isNotEmpty()) {
                val h = K.text(ui.ctx, 13f, K.white(0.55f), 600); h.text = head.uppercase(Locale.FRANCE); h.letterSpacing = 0.08f
                inner.addView(h, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(22); bottomMargin = K.px(10); leftMargin = K.px(4) })
            } else inner.addView(View(ui.ctx), LinearLayout.LayoutParams(1, K.px(18)))
            items.forEachIndexed { i, it ->
                val r = Row(si, i, it)
                inner.addView(r, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { bottomMargin = K.px(8) })
                if (it.sel && first == null) first = lines.size
                lines.add(StaticLine(listOf(r), r))
            }
        }
        sv.isVerticalScrollBarEnabled = false; sv.isFocusable = false
        sv.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        sv.clipChildren = false
        sv.addView(inner, FrameLayout.LayoutParams(K.MATCH, K.WRAP))
        panel.addView(sv, K.lp(K.MATCH, K.MATCH))
        val hint = K.text(ui.ctx, 13.5f, K.white(0.45f)); hint.text = "OK choisir · Retour fermer"
        hint.setBackgroundColor(Color.argb(246, 18, 18, 24))
        hint.setPadding(K.px(40), K.px(10), K.px(40), K.px(24))
        panel.addView(hint, FrameLayout.LayoutParams(K.MATCH, K.WRAP, Gravity.BOTTOM))
        addView(panel, FrameLayout.LayoutParams(K.px(460), K.MATCH, Gravity.END))
        addView(View(ui.ctx).apply { setBackgroundColor(K.white(0.1f)) }, FrameLayout.LayoutParams(K.px(1), K.MATCH, Gravity.END).apply { rightMargin = K.px(460) })
        li = first ?: 0
    }

    override fun scrollTargetFor(n: Int): Int? {
        val v = lines.getOrNull(n)?.section ?: return null
        var top = 0; var x: View? = v
        while (x != null && x !== sv) { top += x.top; x = x.parent as? View }
        val y = top - sv.height / 2 + v.height / 2
        return maxOf(0, y)
    }

    override fun onOk(line: Line, i: Int, v: View) {
        val r = v as? Row ?: return
        ui.pop()
        onPick(r.sec, r.idx)
    }
}

// ==================================================================================================== Lecteur
@SuppressLint("ViewConstructor")
class PlayerScreen(ui: NativeUi, init: JSONObject? = null) : Screen(ui) {
    override val video = true
    private var info: JSONObject = init ?: JSONObject()
    private val isLive get() = info.optString("kind") == "live"

    private val ov = FrameLayout(ui.ctx)
    private val kick = K.text(ui.ctx, 14f, K.white(0.7f), 600)
    private val title = K.text(ui.ctx, 36f, Color.WHITE, 700, 1)
    private val sub = K.text(ui.ctx, 18f, K.white(0.8f), 500, 1)
    private val badges = LinearLayout(ui.ctx)
    private val clock = K.text(ui.ctx, 22f, K.white(0.85f), 500)
    private val pauseBox = LinearLayout(ui.ctx)
    private val spin = Spinner(ui.ctx)
    private val spinMsg = K.text(ui.ctx, 16f, K.white(0.8f), 500, 2)
    // film / épisode
    private val vodBox = LinearLayout(ui.ctx)
    private val seek = SeekBarV(ui.ctx)
    private val tLeft = K.text(ui.ctx, 17f, K.white(0.85f), 500)
    private val tRight = K.text(ui.ctx, 17f, K.white(0.6f), 500)
    // direct
    private val liveBox = LinearLayout(ui.ctx)
    private val lNum = K.text(ui.ctx, 20f, Color.WHITE, 700)
    private val lChip = K.text(ui.ctx, 13f, Color.WHITE, 700)
    private val lGenre = K.text(ui.ctx, 15f, K.white(0.7f), 500)
    private val lTitle = K.text(ui.ctx, 34f, Color.WHITE, 700, 1)
    private val lS = K.text(ui.ctx, 15f, K.white(0.75f))
    private val lE = K.text(ui.ctx, 15f, K.white(0.75f))
    private val lBar = Bar(ui.ctx, dark = true)
    private val lNext = K.text(ui.ctx, 15f, K.white(0.62f), 400, 1)
    private val btnRow = LinearLayout(ui.ctx)
    private val btns = ArrayList<PBtn>()
    // liste des chaînes sur le côté
    private val side = FrameLayout(ui.ctx)
    private val sideList = ChList(ui.ctx, 300f, 60f, 4f)
    private var sideItems: List<JSONObject> = emptyList()
    private var si = 0
    // épisode suivant
    private val up = FrameLayout(ui.ctx)
    private val upBg = HoleBg(ui.ctx)
    private val upKick = K.text(ui.ctx, 15f, K.white(0.7f), 600)
    private val upTitle = K.text(ui.ctx, 84f, Color.WHITE, 400, 1)
    private val upEp = K.text(ui.ctx, 26f, Color.WHITE, 700, 2)
    private val upPlot = K.text(ui.ctx, 17f, K.white(0.72f), 400, 4)
    private val upBar = Bar(ui.ctx, dark = true)
    private val upGo = Btn(ui.ctx, "Lancer maintenant", R.drawable.ic_play)
    private val upNo = Btn(ui.ctx, "Revoir le générique", 0)
    private var upOn = false
    private var upCancelled = false
    private var ubi = 0
    private val upRect = RectF(796f, 56f, 796f + 420f, 56f + 236f)

    private var ovOn = true
    private var zone = 0
    private var bi = 0
    private var pos = 0L
    private var dur = 0L
    private var playing = false
    private var started = false
    private var lastKey = SystemClock.uptimeMillis()
    private var scrubT = -1L
    private var scrubN = 0
    private var lastScrub = 0L
    private var lastInfo = 0L
    private var st = JSONObject()
    private var ticks = 0

    private val poll = object : Runnable { override fun run() { ui.safe("lecteur") { tickState() }; postDelayed(this, 500) } }
    private val commitRun = Runnable { ui.safe("lecteur") { commitScrub() } }

    init {
        isClickable = true
        // dégradés haut et bas
        ov.addView(View(ui.ctx).apply { background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(K.black(0.72f), Color.TRANSPARENT)) }, FrameLayout.LayoutParams(K.MATCH, K.px(220)))
        ov.addView(View(ui.ctx).apply { background = GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, intArrayOf(K.black(0.9f), K.black(0.55f), Color.TRANSPARENT)) }, FrameLayout.LayoutParams(K.MATCH, K.px(360), Gravity.BOTTOM))
        val tl = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL }
        kick.letterSpacing = 0.08f
        tl.addView(kick)
        tl.addView(title, LinearLayout.LayoutParams(K.px(860), K.WRAP).apply { topMargin = K.px(4) })
        tl.addView(sub, LinearLayout.LayoutParams(K.px(860), K.WRAP).apply { topMargin = K.px(6) })
        ov.addView(tl, FrameLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(64); topMargin = K.px(44) })
        badges.orientation = LinearLayout.HORIZONTAL; badges.gravity = Gravity.CENTER_VERTICAL
        ov.addView(badges, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.END).apply { rightMargin = K.px(64); topMargin = K.px(46) })
        // pause
        pauseBox.orientation = LinearLayout.VERTICAL; pauseBox.gravity = Gravity.CENTER_HORIZONTAL
        val circ = FrameLayout(ui.ctx).apply { background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.WHITE) } }
        val pi = ImageView(ui.ctx); pi.setImageResource(R.drawable.ic_play); pi.setColorFilter(Color.BLACK)
        circ.addView(pi, FrameLayout.LayoutParams(K.px(34), K.px(34), Gravity.CENTER))
        pauseBox.addView(circ, LinearLayout.LayoutParams(K.px(88), K.px(88)))
        val pl = K.text(ui.ctx, 16f, K.white(0.75f)); pl.text = "En pause"
        pauseBox.addView(pl, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(14) })
        pauseBox.visibility = View.GONE
        ov.addView(pauseBox, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.CENTER_HORIZONTAL).apply { topMargin = K.px(280) })
        // film / épisode : barre de lecture
        vodBox.orientation = LinearLayout.VERTICAL
        vodBox.addView(seek, LinearLayout.LayoutParams(K.MATCH, K.px(28)))
        val tr = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL }
        tr.addView(tLeft, LinearLayout.LayoutParams(0, K.WRAP, 1f))
        tr.addView(tRight)
        vodBox.addView(tr, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(4) })
        ov.addView(vodBox, FrameLayout.LayoutParams(K.MATCH, K.WRAP, Gravity.BOTTOM).apply { leftMargin = K.px(64); rightMargin = K.px(64); bottomMargin = K.px(108) })
        // direct : programme en cours
        liveBox.orientation = LinearLayout.VERTICAL
        val cr = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        cr.addView(lNum)
        lChip.setPadding(K.px(10), K.px(6), K.px(10), K.px(6))
        cr.addView(lChip, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(12) })
        cr.addView(lGenre, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(12) })
        liveBox.addView(cr)
        liveBox.addView(lTitle, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(8) })
        val pr = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        pr.addView(lS)
        pr.addView(lBar, LinearLayout.LayoutParams(0, K.px(5), 1f).apply { leftMargin = K.px(14); rightMargin = K.px(14) })
        pr.addView(lE)
        liveBox.addView(pr, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(12) })
        liveBox.addView(lNext, LinearLayout.LayoutParams(K.MATCH, K.WRAP).apply { topMargin = K.px(10) })
        ov.addView(liveBox, FrameLayout.LayoutParams(K.MATCH, K.WRAP, Gravity.BOTTOM).apply { leftMargin = K.px(64); rightMargin = K.px(64); bottomMargin = K.px(104) })
        // boutons
        btnRow.orientation = LinearLayout.HORIZONTAL; btnRow.gravity = Gravity.CENTER_VERTICAL
        btnRow.clipChildren = false; btnRow.clipToPadding = false
        ov.addView(btnRow, FrameLayout.LayoutParams(K.MATCH, K.px(64), Gravity.BOTTOM).apply { leftMargin = K.px(60); rightMargin = K.px(60); bottomMargin = K.px(30) })
        ov.clipChildren = false
        addView(ov, K.lp(K.MATCH, K.MATCH))
        // chargement (toujours visible, même sans les commandes)
        val sp = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER_HORIZONTAL }
        sp.addView(spin, LinearLayout.LayoutParams(K.px(44), K.px(44)))
        spinMsg.gravity = Gravity.CENTER; spinMsg.setShadowLayer(K.pxf(6f), 0f, 0f, Color.BLACK)
        sp.addView(spinMsg, LinearLayout.LayoutParams(K.px(520), K.WRAP).apply { topMargin = K.px(14) })
        addView(sp, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.CENTER))
        spin.visibility = View.GONE
        // liste des chaînes
        side.background = GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(K.black(0.88f), K.black(0.7f), Color.TRANSPARENT))
        val sh = K.text(ui.ctx, 13f, K.white(0.55f), 600); sh.letterSpacing = 0.08f; sh.tag = "head"
        side.addView(sh, FrameLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(54); topMargin = K.px(40) })
        side.addView(sideList, FrameLayout.LayoutParams(K.px(316), K.MATCH).apply { leftMargin = K.px(32); topMargin = K.px(70); bottomMargin = K.px(50) })
        val shint = K.text(ui.ctx, 13f, K.white(0.45f)); shint.text = "OK change de chaîne · Retour ferme"
        side.addView(shint, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.BOTTOM).apply { leftMargin = K.px(54); bottomMargin = K.px(20) })
        side.visibility = View.GONE
        addView(side, FrameLayout.LayoutParams(K.px(460), K.MATCH))
        // épisode suivant
        upBg.radius = K.pxf(16f)
        up.addView(upBg, K.lp(K.MATCH, K.MATCH))
        val uc = LinearLayout(ui.ctx).apply { orientation = LinearLayout.VERTICAL; clipChildren = false; clipToPadding = false }
        upKick.letterSpacing = 0.08f
        uc.addView(upKick)
        uc.addView(upTitle, LinearLayout.LayoutParams(K.px(680), K.WRAP).apply { topMargin = K.px(10) })
        uc.addView(upEp, LinearLayout.LayoutParams(K.px(640), K.WRAP).apply { topMargin = K.px(10) })
        upPlot.setLineSpacing(0f, 1.35f)
        uc.addView(upPlot, LinearLayout.LayoutParams(K.px(620), K.WRAP).apply { topMargin = K.px(12) })
        val ub = LinearLayout(ui.ctx).apply { orientation = LinearLayout.HORIZONTAL; clipChildren = false }
        ub.addView(upGo)
        ub.addView(upNo, LinearLayout.LayoutParams(K.WRAP, K.px(58)).apply { leftMargin = K.px(12) })
        uc.addView(ub, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(30) })
        uc.addView(upBar, LinearLayout.LayoutParams(K.px(360), K.px(4)).apply { topMargin = K.px(22) })
        up.addView(uc, FrameLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(80); topMargin = K.px(190) })
        val uh = K.text(ui.ctx, 14f, K.white(0.45f)); uh.text = "Retour : rester sur le générique · l'épisode suivant ne se lance pas"
        up.addView(uh, FrameLayout.LayoutParams(K.WRAP, K.WRAP, Gravity.BOTTOM).apply { leftMargin = K.px(80); bottomMargin = K.px(40) })
        up.visibility = View.GONE
        addView(up, K.lp(K.MATCH, K.MATCH))
        setInfo(info)
        zone = if (isLive) 1 else 0
        started = false
        spinOn("")
        paintFocus()
    }

    // ------------------------------------------------------------------ informations
    private fun setInfo(o: JSONObject) {
        if (o.optBoolean("none")) return
        val kindChanged = o.optString("kind") != info.optString("kind") || btns.isEmpty()
        info = o
        badges.removeAllViews()
        if (isLive) {
            val b = K.text(ui.ctx, 13f, Color.WHITE, 800); b.text = "●  EN DIRECT"
            b.setPadding(K.px(10), K.px(5), K.px(10), K.px(5)); b.background = K.round(Color.parseColor("#e5322d"), 7f)
            badges.addView(b)
        }
        val q = o.optString("q")
        if (q.isNotEmpty()) badges.addView(qBadge(ui.ctx, q, 26f, 13f).apply { (layoutParams as LinearLayout.LayoutParams).leftMargin = K.px(10) })
        val codec = audioLabel(true)
        if (codec.isNotEmpty()) {
            val a = K.text(ui.ctx, 13f, Color.WHITE, 700); a.text = codec
            a.setPadding(K.px(9), K.px(4), K.px(9), K.px(4)); a.background = K.round(Color.TRANSPARENT, 7f, 1, K.white(0.4f))
            badges.addView(a, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(10) })
        }
        badges.addView(clock, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { leftMargin = K.px(18) })
        clock.text = clockText()
        if (isLive) {
            kick.text = ""; title.text = ""; sub.text = ""
            vodBox.visibility = View.GONE; liveBox.visibility = View.VISIBLE
            lNum.text = o.optInt("num").takeIf { it > 0 }?.toString() ?: ""
            lChip.text = o.optString("n"); lChip.background = K.round(K.color(o.optString("col"), Color.DKGRAY), 7f)
            lGenre.text = o.optString("g")
            lTitle.text = o.optString("pg")
            lS.text = o.optString("s"); lE.text = o.optString("e")
            lBar.pct = o.optInt("pct") / 100f
            val n = o.objs("next").firstOrNull()
            lNext.text = if (n != null) "À suivre · ${n.optString("s")} ${n.optString("t")}" else ""
        } else {
            kick.text = o.optString("kick").uppercase(Locale.FRANCE)
            title.text = o.optString("t")
            sub.text = o.optString("sub"); sub.visibility = if (sub.text.isNullOrEmpty()) View.GONE else View.VISIBLE
            vodBox.visibility = View.VISIBLE; liveBox.visibility = View.GONE
        }
        buildButtons(kindChanged)
    }

    private fun audioLabel(short: Boolean): String {
        val a = st.optJSONArray("audio") ?: return ""
        val i = st.optInt("aSel", -1)
        val x = a.optJSONObject(if (i >= 0) i else 0) ?: return ""
        return if (short) x.optString("codec") else listOf(langOf(x), x.optString("codec")).filter { it.isNotBlank() }.joinToString(" ")
    }

    private fun subLabel(): String {
        val s = st.optJSONArray("subs")
        val i = st.optInt("sSel", -1)
        if (s == null || i < 0) return "aucun"
        val x = s.optJSONObject(i) ?: return "aucun"
        return langOf(x).ifEmpty { "piste ${i + 1}" }
    }

    /** Nom de langue lisible (les pistes sans langue déclarée n'affichent rien) */
    private fun langOf(x: JSONObject): String {
        val c = x.optString("code").lowercase(Locale.ROOT)
        if (c in setOf("und", "zxx", "mis", "mul", "")) {
            val n = x.optString("name")
            return if (n.isBlank() || n.equals(c, true) || n == "Piste" || n.length <= 3) "" else n
        }
        return x.optString("lang").ifEmpty { x.optString("name") }
    }

    private fun buildButtons(force: Boolean) {
        val defs = ArrayList<Triple<String, String, String>>()
        val trk = listOf(audioLabel(false).ifEmpty { "Piste par défaut" }, subLabel()).joinToString(" · ")
        if (isLive) {
            defs.add(Triple("guide", "Guide", "Programmes"))
            defs.add(Triple("tracks", "Audio et sous-titres", trk))
            defs.add(Triple("src", "Source", info.optString("src")))
            defs.add(Triple("fmt", "Format", info.optString("fmt")))
            defs.add(Triple("fav", if (info.optBoolean("fav")) "Retirer des favoris" else "Ajouter aux favoris", ""))
        } else {
            defs.add(Triple("tracks", "Audio et sous-titres", trk))
            defs.add(Triple("src", "Source", info.optString("src")))
            defs.add(Triple("fmt", "Format", info.optString("fmt")))
            if (info.optBoolean("ser") && info.optString("next").isNotEmpty()) defs.add(Triple("next", "Épisode suivant", info.optString("next")))
            defs.add(Triple("restart", "Reprendre au début", ""))
        }
        val same = !force && defs.size == btns.size && defs.map { it.first } == btns.map { it.key }
        if (same) {
            // mise à jour légère : on ne recrée les boutons que si leur texte change
            val changed = defs.indices.any { btns[it].tag != defs[it].second + "|" + defs[it].third }
            if (!changed) return
        }
        btnRow.removeAllViews(); btns.clear()
        for ((k, l, s) in defs) {
            val icon = when (k) { "src" -> R.drawable.ic_layers; "fav" -> if (info.optBoolean("fav")) R.drawable.ic_heart_on else R.drawable.ic_heart; "next" -> R.drawable.ic_play; else -> 0 }
            val b = PBtn(ui.ctx, k, l, s, icon)
            b.tag = "$l|$s"
            btnRow.addView(b, LinearLayout.LayoutParams(K.WRAP, K.px(56)).apply { rightMargin = K.px(10) })
            btns.add(b)
        }
        bi = bi.coerceIn(0, maxOf(0, btns.size - 1))
        paintFocus()
    }

    private fun refreshInfo(withList: Boolean = false, cb: ((JSONObject) -> Unit)? = null) {
        lastInfo = SystemClock.uptimeMillis()
        ui.api("pinfo(${if (withList) 1 else 0})") { o -> if (o != null && !o.optBoolean("none")) { setInfo(o); cb?.invoke(o) } }
    }

    // ------------------------------------------------------------------ état du lecteur
    private fun fmtT(ms: Long): String {
        val s = maxOf(0L, ms / 1000)
        val h = s / 3600; val m = (s % 3600) / 60; val ss = s % 60
        return if (h > 0) String.format(Locale.FRANCE, "%d:%02d:%02d", h, m, ss) else String.format(Locale.FRANCE, "%d:%02d", m, ss)
    }

    private fun tickState() {
        st = try { JSONObject(ui.host.playerState()) } catch (e: Exception) { JSONObject() }
        val p = st.optLong("pos", 0); val d = st.optLong("dur", -1)
        playing = st.optBoolean("playing")
        val buf = st.optBoolean("buffering")
        if (!started && (playing || (p > 0 && !buf))) { started = true; spinOff() }
        pos = p
        dur = if (d > 0) d else info.optLong("d", 0) * 1000
        if (started && buf) spinOn("") else if (started && spin.visibility == View.VISIBLE) spinOff()
        if (!isLive) {
            if (scrubT < 0) showTime(pos)
            val paused = started && !playing && !buf
            pauseBox.visibility = if (paused && ovOn && !upOn) View.VISIBLE else View.GONE
            if (paused && !ovOn && !upOn) showOv()
        }
        val now = SystemClock.uptimeMillis()
        if (ovOn && playing && scrubT < 0 && side.visibility != View.VISIBLE && now - lastKey > 5000) hideOv()
        if (isLive && now - lastInfo > 30000) refreshInfo()
        if (++ticks % 4 == 0) buildButtons(false)
    }

    private fun showTime(t: Long) {
        seek.frac = if (dur > 0) t.toFloat() / dur else 0f
        tLeft.text = fmtT(t)
        if (dur > 0) {
            val end = java.util.Calendar.getInstance().apply { add(java.util.Calendar.MILLISECOND, (dur - t).toInt()) }
            tRight.text = String.format(Locale.FRANCE, "Fin à %02d:%02d · −%s", end.get(java.util.Calendar.HOUR_OF_DAY), end.get(java.util.Calendar.MINUTE), fmtT(dur - t))
        } else tRight.text = ""
    }

    private fun spinOn(msg: String) {
        spin.visibility = View.VISIBLE; spin.start()
        spinMsg.text = msg; spinMsg.visibility = if (msg.isEmpty()) View.GONE else View.VISIBLE
    }
    private fun spinOff() { spin.stop(); spin.visibility = View.GONE; spinMsg.visibility = View.GONE }

    // ------------------------------------------------------------------ commandes
    private fun showOv() {
        lastKey = SystemClock.uptimeMillis()
        if (ovOn) return
        ovOn = true
        ov.animate().cancel(); ov.animate().alpha(1f).setDuration(160).start()
        paintFocus()
    }

    private fun hideOv() {
        if (!ovOn) return
        ovOn = false
        ov.animate().cancel(); ov.animate().alpha(0f).setDuration(220).start()
        pauseBox.visibility = View.GONE
    }

    private fun paintFocus() {
        seek.focusedBar = ovOn && zone == 0 && !isLive
        btns.forEachIndexed { i, b -> b.foc(ovOn && zone == 1 && i == bi) }
    }

    private fun scrub(d: Int) {
        if (isLive || dur <= 0) return
        val now = SystemClock.uptimeMillis()
        scrubN = if (now - lastScrub < 700) scrubN + 1 else 0
        lastScrub = now
        val step = when { scrubN < 3 -> 10_000L; scrubN < 8 -> 30_000L; scrubN < 14 -> 60_000L; scrubN < 22 -> 120_000L; else -> 300_000L }
        val base = if (scrubT >= 0) scrubT else pos
        scrubT = (base + d * step).coerceIn(0L, maxOf(0L, dur - 3000))
        showTime(scrubT)
        removeCallbacks(commitRun); postDelayed(commitRun, 900)
    }

    private fun commitScrub() {
        if (scrubT < 0) return
        val t = scrubT
        scrubT = -1; scrubN = 0
        pos = t
        ui.js("nativeApi.pact('seek',$t)")
    }

    private fun togglePause() {
        ui.js("nativeApi.pact('pp')")
        playing = !playing
        if (!isLive) pauseBox.visibility = if (!playing) View.VISIBLE else View.GONE
        showOv()
    }

    private fun zap(arg: String) {
        started = false; spinOn("")
        ui.api("pact('zap',${ui.q(arg)})") { o -> if (o != null) { setInfo(o); showOv() } }
    }

    override fun key(code: Int): Boolean {
        lastKey = SystemClock.uptimeMillis()
        if (upOn) {
            when (code) {
                KeyEvent.KEYCODE_DPAD_LEFT -> if (ubi > 0) { ubi = 0; paintUp() }
                KeyEvent.KEYCODE_DPAD_RIGHT -> if (ubi < 1) { ubi = 1; paintUp() }
            }
            return true
        }
        if (side.visibility == View.VISIBLE) {
            when (code) {
                KeyEvent.KEYCODE_DPAD_UP -> if (si > 0) { si--; sideList.setFocus(si) }
                KeyEvent.KEYCODE_DPAD_DOWN -> if (si < sideItems.size - 1) { si++; sideList.setFocus(si) }
                KeyEvent.KEYCODE_DPAD_RIGHT -> closeSide()
            }
            return true
        }
        if (isLive) {
            when (code) {
                KeyEvent.KEYCODE_DPAD_UP -> zap("-1")
                KeyEvent.KEYCODE_DPAD_DOWN -> zap("1")
                KeyEvent.KEYCODE_DPAD_LEFT -> if (!ovOn || bi == 0) openSide() else { bi--; paintFocus() }
                KeyEvent.KEYCODE_DPAD_RIGHT -> if (!ovOn) showOv() else if (bi < btns.size - 1) { bi++; paintFocus() }
            }
            zone = 1
            return true
        }
        if (!ovOn) {
            when (code) {
                KeyEvent.KEYCODE_DPAD_LEFT -> { zone = 0; showOv(); paintFocus(); scrub(-1) }
                KeyEvent.KEYCODE_DPAD_RIGHT -> { zone = 0; showOv(); paintFocus(); scrub(1) }
                else -> { zone = 0; showOv(); paintFocus() }
            }
            return true
        }
        when (zone) {
            0 -> when (code) {
                KeyEvent.KEYCODE_DPAD_LEFT -> scrub(-1)
                KeyEvent.KEYCODE_DPAD_RIGHT -> scrub(1)
                KeyEvent.KEYCODE_DPAD_DOWN -> { commitScrub(); zone = 1; paintFocus() }
            }
            1 -> when (code) {
                KeyEvent.KEYCODE_DPAD_LEFT -> if (bi > 0) { bi--; paintFocus() }
                KeyEvent.KEYCODE_DPAD_RIGHT -> if (bi < btns.size - 1) { bi++; paintFocus() }
                KeyEvent.KEYCODE_DPAD_UP -> { zone = 0; paintFocus() }
            }
        }
        return true
    }

    override fun media(code: Int): Boolean {
        lastKey = SystemClock.uptimeMillis()
        if (upOn) return true
        when (code) {
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_MEDIA_PLAY, KeyEvent.KEYCODE_MEDIA_PAUSE -> if (!isLive) togglePause() else showOv()
            KeyEvent.KEYCODE_MEDIA_REWIND -> if (isLive) zap("-1") else { zone = 0; showOv(); paintFocus(); scrub(-1) }
            KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> if (isLive) zap("1") else { zone = 0; showOv(); paintFocus(); scrub(1) }
            KeyEvent.KEYCODE_CHANNEL_UP -> if (isLive) zap("-1")
            KeyEvent.KEYCODE_CHANNEL_DOWN -> if (isLive) zap("1")
            else -> return false
        }
        return true
    }

    override fun ok() {
        lastKey = SystemClock.uptimeMillis()
        if (upOn) { if (ubi == 0) upNow() else upCancel(); return }
        if (side.visibility == View.VISIBLE) { sideItems.getOrNull(si)?.let { zap(it.optString("id")) }; closeSide(); return }
        if (!ovOn) { if (isLive) { zone = 1; showOv(); paintFocus() } else { togglePause(); zone = 0; paintFocus() }; return }
        if (!isLive && zone == 0) { if (scrubT >= 0) { removeCallbacks(commitRun); commitScrub() } else togglePause(); return }
        btns.getOrNull(bi)?.let { action(it.key) }
    }

    override fun menu() {
        if (upOn) return
        lastKey = SystemClock.uptimeMillis()
        openTracks()
    }

    private fun action(k: String) {
        when (k) {
            "tracks" -> openTracks()
            "fmt" -> openFormat()
            "src" -> openSources()
            "restart" -> { ui.js("nativeApi.pact('restart')"); pos = 0; showTime(0); ui.toast("Reprise au début") }
            "next" -> { started = false; spinOn(""); ui.api("pact('nextep')") { o -> if (o != null) setInfo(o) } }
            "fav" -> ui.api("pact('fav')") { o -> if (o != null) { setInfo(o); ui.toast(if (o.optBoolean("fav")) "Ajoutée aux favoris" else "Retirée des favoris") } }
            "guide" -> ui.api("pinfo(1)") { o ->
                val L = o?.objs("list") ?: emptyList()
                val idx = L.indexOfFirst { it.optString("id") == info.optString("id") }.coerceAtLeast(0)
                ui.push(GuideScreen(ui, idx) { id -> ui.pop(); zap(id) })
            }
        }
    }

    private fun openTracks() {
        val a = st.optJSONArray("audio"); val s = st.optJSONArray("subs")
        val aSel = st.optInt("aSel", -1); val sSel = st.optInt("sSel", -1)
        val au = ArrayList<SidePanel.Item>()
        for (i in 0 until (a?.length() ?: 0)) { val x = a!!.optJSONObject(i) ?: continue; au.add(SidePanel.Item(langOf(x).ifEmpty { "Piste ${i + 1}" }, x.optString("codec"), i == aSel)) }
        val su = ArrayList<SidePanel.Item>()
        su.add(SidePanel.Item("Désactivés", "", sSel < 0))
        for (i in 0 until (s?.length() ?: 0)) { val x = s!!.optJSONObject(i) ?: continue; su.add(SidePanel.Item(langOf(x).ifEmpty { "Sous-titres ${i + 1}" }, x.optString("codec"), i == sSel)) }
        if (au.isEmpty() && su.size == 1) { ui.toast("Pistes en cours de lecture…"); return }
        val name = if (isLive) info.optString("n") else info.optString("t")
        ui.push(SidePanel(ui, name, "Audio et sous-titres", listOf("Audio · ${au.size}" to au, "Sous-titres · ${su.size - 1}" to su)) { sec, i ->
            if (sec == 0) ui.js("nativeApi.pact('audio',$i)") else ui.js("nativeApi.pact('sub',${i - 1})")
            postDelayed({ ui.safe("lecteur") { tickState(); buildButtons(false) } }, 600)
        })
    }

    private fun openFormat() {
        val F = listOf("auto" to "Auto" to "Format d'origine du flux", "fit" to "Ajuster à l'écran" to "Image entière, sans recadrage", "fill" to "Remplir l'écran" to "Supprime les bandes noires, recadre les bords",
            "169" to "16:9" to "Écran TV standard", "43" to "4:3" to "Anciens programmes", "219" to "21:9" to "Cinéma, bandes en haut et en bas",
            "stretch" to "Étirer" to "Déforme l'image pour remplir l'écran", "zoom" to "Zoom 133 %" to "Agrandit le centre de l'image")
        val cur = info.optString("fmtk", "auto")
        val items = F.map { (kl, d) -> SidePanel.Item(kl.second, d, kl.first == cur) }
        ui.push(SidePanel(ui, if (isLive) info.optString("n") else info.optString("t"), "Format de l'image", listOf("" to items)) { _, i ->
            ui.api("pact('fmt',${ui.q(F[i].first.first)})") { o -> if (o != null) setInfo(o) }
        })
    }

    private fun openSources() {
        ui.api("psrcs()") { o ->
            val L = o?.objs("sources") ?: emptyList()
            if (L.size < 2) { ui.toast("Une seule source disponible"); return@api }
            val items = L.map { s ->
                SidePanel.Item("${s.optString("q")} · ${s.optString("pl")}", listOf(s.optString("name"), s.optString("codec")).filter { it.isNotBlank() }.joinToString(" · "),
                    s.optBoolean("def"), if (s.optBoolean("ok", true)) "" else "Non compatible : ce Fire Stick lit jusqu'en 1080p", !s.optBoolean("ok", true))
            }
            ui.push(SidePanel(ui, o?.optString("t") ?: "", "Choisir la source", listOf("${L.size} sources" to items)) { _, i ->
                val id = L[i].optString("id")
                started = false; spinOn("")
                ui.api("pact('src',${ui.q(id)})") { r -> if (r != null) { if (r.has("msg")) { ui.toast(r.optString("msg")); spinOff(); started = true } else setInfo(r) } }
            })
        }
    }

    // ------------------------------------------------------------------ liste des chaînes
    private fun openSide() {
        refreshInfo(true) { o ->
            sideItems = o.objs("list")
            si = sideItems.indexOfFirst { it.optString("id") == o.optString("id") }.coerceAtLeast(0)
            (side.findViewWithTag<View>("head") as? android.widget.TextView)?.text = o.optString("cat").uppercase(Locale.FRANCE)
            side.visibility = View.VISIBLE
            hideOv()
            sideList.set(sideItems, si)
            sideList.post { sideList.setFocus(si) }
        }
    }

    private fun closeSide() { side.visibility = View.GONE; showOv() }

    // ------------------------------------------------------------------ épisode suivant
    private fun paintUp() { upGo.foc(ubi == 0); upNo.foc(ubi == 1) }

    private fun upRectPx() = RectF(K.pxf(upRect.left), K.pxf(upRect.top), K.pxf(upRect.right), K.pxf(upRect.bottom))

    private fun showUp(o: JSONObject) {
        val c1 = K.color(o.optString("c1"), Color.DKGRAY); val c2 = K.color(o.optString("c2"), Color.BLACK)
        val glow = GradientDrawable().apply { gradientType = GradientDrawable.RADIAL_GRADIENT; gradientRadius = K.pxf(760f); setGradientCenter(0.75f, 0.35f); colors = intArrayOf(K.withAlpha(c1, 0.6f), Color.TRANSPARENT) }
        val base = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(c2, Color.parseColor("#050507")))
        val shade = GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, intArrayOf(K.black(0.85f), K.black(0.4f), Color.TRANSPARENT))
        upBg.bg = LayerDrawable(arrayOf<Drawable>(base, glow, shade))
        upBg.hole = upRectPx()
        upTitle.text = o.optString("t")
        titleStyle(upTitle, o.optString("f"), 2.8f)
        upEp.text = o.optString("ep")
        upPlot.text = o.optString("plot"); upPlot.visibility = if (upPlot.text.isNullOrEmpty()) View.GONE else View.VISIBLE
        upOn = true; ubi = 0
        up.visibility = View.VISIBLE; up.alpha = 0f; up.animate().alpha(1f).setDuration(200).start()
        hideOv(); side.visibility = View.GONE
        paintUp()
        applyVideo()
    }

    private fun hideUp() {
        if (!upOn) return
        upOn = false
        up.visibility = View.GONE
        applyVideo()
    }

    private fun upNow() {
        hideUp(); started = false; spinOn("")
        ui.api("pact('nextep')") { o -> if (o != null) setInfo(o) }
    }

    private fun upCancel() {
        upCancelled = true
        hideUp()
        ui.js("nativeApi.pact('upnx')")
        showOv()
    }

    override fun applyVideo() {
        if (upOn) { val r = upRectPx(); ui.host.videoRect(r.left.toInt(), r.top.toInt(), r.width().toInt(), r.height().toInt()) }
        else ui.host.videoRect(0, 0, 0, 0)
    }

    // ------------------------------------------------------------------ événements
    override fun onEvent(kind: String, o: JSONObject) {
        when (kind) {
            "upnext" -> if (o.optBoolean("on")) {
                if (upCancelled) return
                if (!upOn) showUp(o)
                val left = o.optInt("left")
                upKick.text = "ÉPISODE SUIVANT DANS $left S"
                upBar.pct = ((10 - left) / 10f).coerceIn(0f, 1f)
            } else hideUp()
            "pinfo" -> { upCancelled = false; started = false; spinOn(""); refreshInfo() }
            "epg" -> if (isLive && SystemClock.uptimeMillis() - lastInfo > 3000) refreshInfo()
        }
    }

    override fun onFirstFrame() { started = true; spinOff() }

    override fun onPlayFail(msg: String) {
        if (ui.top() === this) ui.pop() else ui.closePlayer()
    }

    override fun onShown() { removeCallbacks(poll); post(poll); lastKey = SystemClock.uptimeMillis() }
    override fun onHidden() { removeCallbacks(poll); removeCallbacks(commitRun) }

    override fun restoreFocus() { paintFocus() }

    init { post(poll); if (init == null) refreshInfo() }

    override fun onBack(): Boolean {
        if (upOn) { upCancel(); return true }
        if (side.visibility == View.VISIBLE) { closeSide(); return true }
        if (scrubT >= 0) { removeCallbacks(commitRun); scrubT = -1; scrubN = 0; showTime(pos); ui.toast("Avance annulée"); return true }
        removeCallbacks(poll)
        if (isLive) ui.js("nativeApi.unfull()") else ui.js("nativeApi.pact('stop')")
        ui.pop()
        return true
    }
}
