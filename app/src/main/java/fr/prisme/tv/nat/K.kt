package fr.prisme.tv.nat

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Mesures et styles de l'interface native. Tout est dessiné sur une grille de 1280×720 (comme les maquettes),
 * puis mis à l'échelle de l'écran réel : sur un téléviseur 1080p, 1 unité = 1,5 pixel.
 */
object K {
    var u = 1.5f
    private val faces = HashMap<String, Typeface>()
    private var fontFiles: Set<String> = emptySet()
    private lateinit var app: Context

    fun init(ctx: Context) {
        app = ctx.applicationContext
        val dm = ctx.resources.displayMetrics
        u = maxOf(dm.widthPixels, dm.heightPixels) / 1280f
        fontFiles = try { ctx.assets.list("fonts")?.toSet() ?: emptySet() } catch (e: Exception) { emptySet() }
    }

    fun px(v: Float): Int = Math.round(v * u)
    fun px(v: Int): Int = Math.round(v * u)
    fun pxf(v: Float): Float = v * u

    /** Polices intégrées à l'appli (téléchargées depuis Google Fonts à la compilation) */
    fun font(name: String, weight: Int = 400, italic: Boolean = false): Typeface {
        val key = "$name/$weight/$italic"
        faces[key]?.let { return it }
        val file = when (name) {
            "outfit" -> "Outfit.ttf"
            "bebas" -> "BebasNeue.ttf"
            "serif" -> "PlayfairItalic.ttf"
            "black" -> "ArchivoBlack.ttf"
            else -> "Outfit.ttf"
        }
        var tf: Typeface? = null
        if (file in fontFiles) {
            tf = try {
                Typeface.Builder(app.assets, "fonts/$file")
                    .setFontVariationSettings("'wght' $weight")
                    .build()
            } catch (e: Exception) { null }
        }
        if (tf == null) {
            tf = when (name) {
                "serif" -> Typeface.create(Typeface.SERIF, Typeface.BOLD_ITALIC)
                "bebas", "black" -> Typeface.create("sans-serif-condensed", Typeface.BOLD)
                else -> Typeface.create(Typeface.SANS_SERIF, if (weight >= 600) Typeface.BOLD else Typeface.NORMAL)
            }
        }
        faces[key] = tf!!
        return tf
    }

    fun ui(weight: Int = 400) = font("outfit", weight)

    fun color(hex: String?, fallback: Int = Color.DKGRAY): Int = try {
        var h = (hex ?: "").trim()
        if (h.length == 9 && h.startsWith("#")) h = "#" + h.substring(7, 9) + h.substring(1, 7) // #rrggbbaa → #aarrggbb
        Color.parseColor(h)
    } catch (e: Exception) { fallback }

    fun withAlpha(c: Int, a: Float): Int = Color.argb((a * 255).toInt().coerceIn(0, 255), Color.red(c), Color.green(c), Color.blue(c))

    fun white(a: Float) = Color.argb((a * 255).toInt(), 255, 255, 255)
    fun black(a: Float) = Color.argb((a * 255).toInt(), 0, 0, 0)

    fun round(color: Int, radius: Float, stroke: Int = 0, strokeColor: Int = 0): GradientDrawable =
        GradientDrawable().apply {
            setColor(color); cornerRadius = pxf(radius)
            if (stroke > 0) setStroke(px(stroke), strokeColor)
        }

    fun grad(c1: Int, c2: Int, orientation: GradientDrawable.Orientation = GradientDrawable.Orientation.TL_BR, radius: Float = 0f) =
        GradientDrawable(orientation, intArrayOf(c1, c2)).apply { cornerRadius = pxf(radius) }

    fun text(ctx: Context, size: Float, color: Int = Color.WHITE, weight: Int = 400, lines: Int = 1): TextView =
        TextView(ctx).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_PX, pxf(size))
            setTextColor(color)
            typeface = ui(weight)
            includeFontPadding = false
            if (lines > 0) { maxLines = lines; ellipsize = android.text.TextUtils.TruncateAt.END }
        }

    fun lp(w: Int, h: Int) = FrameLayout.LayoutParams(w, h)
    fun llp(w: Int, h: Int) = LinearLayout.LayoutParams(w, h)
    const val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
    const val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT

    fun View.margins(l: Int = 0, t: Int = 0, r: Int = 0, b: Int = 0): View {
        val p = layoutParams as? ViewGroup.MarginLayoutParams ?: return this
        p.setMargins(l, t, r, b); layoutParams = p; return this
    }

    /** Couleurs des qualités (mêmes teintes que l'interface actuelle) */
    fun qualColor(q: String): Int = when (q) {
        "4K" -> Color.parseColor("#e8bb4a")
        "1080p" -> Color.parseColor("#7cc4ff")
        "720p" -> Color.parseColor("#c9ced8")
        "SD" -> Color.parseColor("#8e939e")
        else -> Color.parseColor("#5d6270")
    }

    /** Durée en minutes → « 1 h 52 » */
    fun dur(min: Int): String = if (min <= 0) "" else if (min < 60) "$min min" else "${min / 60} h ${String.format("%02d", min % 60)}"
}
