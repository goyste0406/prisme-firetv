package fr.prisme.tv.nat

import android.annotation.SuppressLint
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView

/**
 * Navigation à la télécommande, sans le système de focus d'Android (imprévisible avec des listes imbriquées) :
 * chaque écran est une suite de « lignes » (onglets, rangée d'affiches, boutons, grille…) et garde en mémoire
 * la position dans chacune. Haut/bas change de ligne, gauche/droite se déplace dans la ligne.
 */
abstract class Line {
    var idx = 0
    /** Lignes de tuiles d'une même grille : on garde la colonne en montant ou descendant */
    open val sameColumns = false
    abstract val count: Int
    /** Bloc à faire apparaître verticalement (titre + rangée) */
    abstract val section: View
    abstract fun reveal(i: Int, cb: (View) -> Unit)
    abstract fun viewAt(i: Int): View?
    /** Grille : nombre de colonnes (0 = ligne simple) */
    open val cols = 0
}

/** Ligne de vues déjà créées, éventuellement dans un défilement horizontal */
class StaticLine(val views: List<View>, override val section: View, val scroller: HorizontalScrollView? = null,
                 override val sameColumns: Boolean = false) : Line() {
    override val count get() = views.size
    override fun viewAt(i: Int) = views.getOrNull(i)
    override fun reveal(i: Int, cb: (View) -> Unit) {
        val v = views.getOrNull(i) ?: return
        scroller?.let { s ->
            val pad = K.px(64)
            val left = v.left // position dans la rangée, retrait de début compris
            var x = s.scrollX
            if (left - pad < x) x = left - pad
            else if (v.right + pad > x + s.width) x = v.right + pad - s.width
            x = x.coerceAtLeast(0)
            if (x != s.scrollX) {
                if (Math.abs(x - s.scrollX) > s.width * 2) s.scrollTo(x, 0) else s.smoothScrollTo(x, 0)
            }
        }
        cb(v)
    }
}

/** Grille d'affiches (RecyclerView) : seules les affiches visibles existent réellement */
class GridLine(val rv: RecyclerView, override val section: View, override val cols: Int, val total: () -> Int) : Line() {
    override val count get() = total()
    private val lm get() = rv.layoutManager as GridLayoutManager
    override fun viewAt(i: Int): View? = lm.findViewByPosition(i)
    override fun reveal(i: Int, cb: (View) -> Unit) {
        val pad = K.px(36)
        val v = lm.findViewByPosition(i)
        if (v != null) {
            if (v.top < pad) rv.smoothScrollBy(0, v.top - pad)
            else if (v.bottom > rv.height - pad) rv.smoothScrollBy(0, v.bottom - rv.height + pad)
            cb(v)
        } else {
            lm.scrollToPositionWithOffset(i, pad)
            rv.post { lm.findViewByPosition(i)?.let(cb) }
        }
    }
}

@SuppressLint("ViewConstructor")
abstract class Screen(val ui: NativeUi) : FrameLayout(ui.ctx) {
    val lines = ArrayList<Line>()
    var li = 0
    var cur: View? = null
    /** Fenêtre posée par-dessus l'écran précédent (choix de la source) */
    open val modal = false
    /** Défilement vertical de l'écran (null : l'écran ne défile pas) */
    open val vscroll: ScrollView? = null

    init { clipChildren = false }

    open fun onShown() {}
    open fun onHidden() {}
    open fun onFocus(line: Line, i: Int, v: View) {}
    open fun onOk(line: Line, i: Int, v: View) {}
    open fun onMenu(line: Line, i: Int, v: View) {}
    /** Retour : true si l'écran l'a géré lui-même */
    open fun onBack(): Boolean = false
    /** Bord atteint (aucune ligne au-dessus/dessous, début/fin de ligne) */
    open fun onEdge(dir: Int): Boolean = false
    open fun applyBackground() {}
    open fun refresh() {}
    /** Écran posé sur la vidéo (fond transparent là où l'image doit apparaître) */
    open val video = false
    /** Place la vidéo pour cet écran (appelé quand il passe au premier plan) */
    open fun applyVideo() {}
    /** Touches multimédia (lecture, avance, chaînes) : true si l'écran les a gérées */
    open fun media(code: Int): Boolean = false
    open fun onFirstFrame() {}
    open fun onPlayFail(msg: String) {}
    /** Messages de la couche de données (guide, lecteur…) */
    open fun onEvent(kind: String, o: org.json.JSONObject) {}
    /** Position verticale voulue pour une ligne (null : calcul par défaut) */
    open fun scrollTargetFor(n: Int): Int? = null

    fun line(): Line? = lines.getOrNull(li)

    /** Tâche différée protégée (une erreur désactive l'interface native au lieu de fermer l'appli) */
    fun later(delay: Long = 0, f: () -> Unit) {
        val r = Runnable { ui.safe(javaClass.simpleName) { f() } }
        if (delay > 0) postDelayed(r, delay) else post(r)
    }

    open fun key(code: Int): Boolean {
        val L = line() ?: return false
        if (L.count == 0) { val n = nextLine(li, 1); if (n >= 0) { go(n); return true } }
        when (code) {
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                if (L.cols > 0 && L.idx % L.cols == 0) return onEdge(code)
                if (L.idx > 0) setIdx(L.idx - 1) else return onEdge(code)
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                if (L.cols > 0 && (L.idx % L.cols == L.cols - 1)) return onEdge(code)
                if (L.idx < L.count - 1) setIdx(L.idx + 1) else return onEdge(code)
            }
            KeyEvent.KEYCODE_DPAD_UP -> {
                if (L.cols > 0 && L.idx >= L.cols) { setIdx(L.idx - L.cols); return true }
                val n = nextLine(li, -1); if (n < 0) return onEdge(code); go(n)
            }
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                if (L.cols > 0) {
                    val rowsLeft = (L.count - 1) / L.cols - L.idx / L.cols
                    if (rowsLeft > 0) { setIdx(minOf(L.idx + L.cols, L.count - 1)); return true }
                }
                val n = nextLine(li, 1); if (n < 0) return onEdge(code); go(n)
            }
            else -> return false
        }
        return true
    }

    private fun nextLine(from: Int, d: Int): Int {
        var n = from + d
        while (n in lines.indices && lines[n].count == 0) n += d
        return if (n in lines.indices) n else -1
    }

    fun go(n: Int, instant: Boolean = false) {
        val from = line(); val to = lines.getOrNull(n) ?: return
        if (from != null && from !== to && from.sameColumns && to.sameColumns) {
            to.idx = minOf(from.idx, to.count - 1)
        }
        to.idx = to.idx.coerceIn(0, maxOf(0, to.count - 1))
        li = n
        apply(instant)
    }

    fun setIdx(i: Int) { val L = line() ?: return; L.idx = i; apply(false) }

    fun apply(instant: Boolean = false) {
        val L = line() ?: return
        if (L.count == 0) return
        (cur as? Foc)?.foc(false)
        cur = null
        revealVertical(li, instant)
        val target = L.idx
        L.reveal(target) { v ->
            if (L.idx != target || line() !== L) return@reveal
            (cur as? Foc)?.foc(false)
            cur = v
            val was = K.instant
            K.instant = instant
            try { (v as? Foc)?.foc(true) } finally { K.instant = was }
            onFocus(L, target, v)
        }
    }

    open fun revealVertical(n: Int, instant: Boolean) {
        val sv = vscroll ?: return
        val L = lines.getOrNull(n) ?: return
        val y = scrollTargetFor(n) ?: run {
            var top = 0; var v: View? = L.section
            while (v != null && v !== sv) { top += v.top; v = v.parent as? View }
            maxOf(0, top - K.px(70))
        }
        if (instant) sv.scrollTo(0, y) else if (y != sv.scrollY) sv.smoothScrollTo(0, y)
    }

    open fun ok() { val L = line() ?: return; val v = cur ?: L.viewAt(L.idx) ?: return; onOk(L, L.idx, v) }
    open fun menu() { val L = line() ?: return; val v = cur ?: L.viewAt(L.idx) ?: return; onMenu(L, L.idx, v) }

    /** Focus remis en place quand l'écran redevient visible (retour) */
    open fun restoreFocus() { apply(true) }
}

/** Rangée défilante horizontale avec titre, au format des rangées de l'appli */
class RowSection(ctx: android.content.Context, title: String, small: String? = null, padTop: Float = 22f, padX: Float = 64f) : LinearLayout(ctx) {
    val scroller = HorizontalScrollView(ctx)
    val inner = LinearLayout(ctx)
    val head = K.text(ctx, 20f, K.white(0.78f), 600)

    init {
        orientation = VERTICAL
        clipChildren = false; clipToPadding = false
        setPadding(0, K.px(padTop), 0, 0)
        val sp = android.text.SpannableStringBuilder(title)
        if (!small.isNullOrEmpty()) {
            val st = sp.length
            sp.append("   ").append(small)
            sp.setSpan(android.text.style.AbsoluteSizeSpan(K.px(14)), st, sp.length, 0)
            sp.setSpan(android.text.style.ForegroundColorSpan(K.white(0.45f)), st, sp.length, 0)
        }
        head.text = sp
        addView(head, LayoutParams(K.MATCH, K.WRAP).apply { leftMargin = K.px(padX) })
        scroller.isHorizontalScrollBarEnabled = false
        scroller.overScrollMode = View.OVER_SCROLL_NEVER
        scroller.clipChildren = false; scroller.clipToPadding = false
        scroller.isFocusable = false
        scroller.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        inner.orientation = HORIZONTAL
        inner.clipChildren = false; inner.clipToPadding = false
        inner.setPadding(K.px(padX), K.px(16), K.px(64), K.px(14))
        scroller.addView(inner, FrameLayout.LayoutParams(K.WRAP, K.WRAP))
        addView(scroller, LayoutParams(K.MATCH, K.WRAP))
    }

    fun add(v: View, gap: Float = 26f) {
        val old = v.layoutParams as? ViewGroup.LayoutParams
        val lp = if (old != null) LayoutParams(old.width, old.height) else LayoutParams(K.WRAP, K.WRAP)
        if (inner.childCount > 0) lp.leftMargin = K.px(gap)
        inner.addView(v, lp)
    }
}
