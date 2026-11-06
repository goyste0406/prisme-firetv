package fr.prisme.tv.nat

import android.annotation.SuppressLint
import android.graphics.Color
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import org.json.JSONObject

/** Grille complète d'un genre (maquette 6) : seules les affiches visibles sont créées */
@SuppressLint("ViewConstructor")
class GenreScreen(ui: NativeUi, private val ty: String, private val key: String) : Screen(ui) {
    private val kick = K.text(ui.ctx, 15f, K.white(0.7f), 600)
    private val title = K.text(ui.ctx, 48f, Color.WHITE, 700)
    private val chipsRow = LinearLayout(ui.ctx)
    private val header = LinearLayout(ui.ctx)
    private val rv = RecyclerView(ui.ctx)
    private var items: List<JSONObject> = emptyList()
    private var sort = "new"
    private val chips: List<Chip>
    private val sortKeys = listOf("new", "az", "note")
    private lateinit var grid: GridLine
    private val chipLine: StaticLine
    private var c1 = "#2b3245"
    private var c2 = "#0a0b10"

    private inner class H(v: View) : RecyclerView.ViewHolder(v)

    private val adapter = object : RecyclerView.Adapter<H>() {
        override fun getItemCount() = items.size
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): H {
            val c = PosterCard(ui.ctx)
            c.layoutParams = RecyclerView.LayoutParams(K.px(138), ViewGroup.LayoutParams.WRAP_CONTENT).apply { bottomMargin = K.px(30) }
            return H(c)
        }
        override fun onBindViewHolder(h: H, pos: Int) {
            val c = h.itemView as PosterCard
            c.bind(items[pos])
            val on = li == 1 && grid.idx == pos
            c.foc(on)
            if (on) cur = c
        }
    }

    init {
        setBackgroundColor(Color.TRANSPARENT)
        header.orientation = LinearLayout.VERTICAL
        kick.letterSpacing = 0.08f
        header.addView(kick)
        header.addView(title, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(6) })
        chipsRow.orientation = LinearLayout.HORIZONTAL
        chipsRow.clipChildren = false
        chips = listOf(Chip(ui.ctx, "Derniers ajouts"), Chip(ui.ctx, "A → Z"), Chip(ui.ctx, "Les mieux notés"))
        chips.forEachIndexed { i, c -> chipsRow.addView(c, LinearLayout.LayoutParams(K.WRAP, K.px(42)).apply { if (i > 0) leftMargin = K.px(12) }) }
        chips[0].selected2 = true
        header.addView(chipsRow, LinearLayout.LayoutParams(K.WRAP, K.WRAP).apply { topMargin = K.px(18) })
        addView(header, FrameLayout.LayoutParams(K.MATCH, K.WRAP).apply { leftMargin = K.px(64); topMargin = K.px(64) })

        rv.layoutManager = GridLayoutManager(ui.ctx, 7)
        rv.adapter = adapter
        rv.setHasFixedSize(true)
        rv.itemAnimator = null
        rv.isFocusable = false
        rv.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        rv.clipChildren = false; rv.clipToPadding = false
        rv.overScrollMode = View.OVER_SCROLL_NEVER
        rv.setItemViewCacheSize(14)
        rv.setPadding(K.px(64), K.px(24), K.px(40), K.px(40))
        addView(rv, FrameLayout.LayoutParams(K.MATCH, K.MATCH).apply { topMargin = K.px(222) })

        chipLine = StaticLine(chips, header)
        grid = GridLine(rv, rv, 7) { items.size }
        lines.add(chipLine); lines.add(grid)
        li = 1
        load()
    }

    private fun load() {
        ui.api("genre(${ui.q(ty)},${ui.q(key)},${ui.q(sort)})") { o ->
            if (o == null) return@api
            kick.text = o.optString("kick")
            title.text = o.optString("title")
            c1 = o.optString("c1", c1); c2 = o.optString("c2", c2)
            applyBackground()
            items = o.objs("items")
            grid.idx = 0
            adapter.notifyDataSetChanged()
            rv.scrollToPosition(0)
            if (items.isEmpty()) li = 0
            later { if (ui.top() === this) apply(true) }
        }
    }

    override fun applyBackground() { ui.setBg(c1, c2, null) }

    override fun onFocus(line: Line, i: Int, v: View) {
        if (line === chipLine) {
            val s = sortKeys[i]
            if (s != sort) {
                sort = s
                chips.forEachIndexed { k, c -> c.selected2 = k == i }
                load()
            }
        }
    }

    override fun onOk(line: Line, i: Int, v: View) {
        if (v is PosterCard) v.item?.let { ui.openDetail(it.optString("id")) }
        else if (line === chipLine) go(1)
    }

    override fun onMenu(line: Line, i: Int, v: View) {
        val id = (v as? PosterCard)?.item?.optString("id") ?: return
        ui.api("fav(${ui.q(id)})") { r -> if (r != null) ui.toast(r.optString("msg")) }
    }
}
