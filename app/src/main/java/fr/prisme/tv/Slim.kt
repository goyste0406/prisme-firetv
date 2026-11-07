package fr.prisme.tv

import android.util.JsonReader
import android.util.JsonToken
import android.util.JsonWriter
import java.io.InputStream
import java.io.InputStreamReader
import java.io.OutputStream
import java.io.OutputStreamWriter

/**
 * Listes Xtream allégées : les très gros catalogues (plusieurs dizaines de Mo) sont lus en continu ici,
 * côté natif, et seuls les champs utiles sont transmis à l'interface, sous forme de tableaux compacts.
 * Sans ça, la mémoire de l'interface déborde sur le Fire TV Stick et l'appli se ferme.
 */
object Slim {
    /** Nombre d'éléments déjà lus dans la liste en cours (affiché pendant les actualisations) */
    val count = java.util.concurrent.atomic.AtomicInteger(0)
    private val FIELDS = mapOf(
        "live" to listOf("stream_id", "name", "stream_icon", "category_id", "*cats", "num", "tv_archive"),
        "vod" to listOf("stream_id", "name", "stream_icon", "category_id", "*cats", "rating", "added", "container_extension", "tmdb|tmdb_id"),
        "series" to listOf("series_id", "name", "cover", "category_id", "*cats", "rating", "last_modified", "plot:240", "cast:160",
            "director:80", "genre", "releaseDate|release_date", "*backdrop", "tmdb")
    )

    fun convert(kind: String, input: InputStream, out: OutputStream) {
        val spec = FIELDS[kind] ?: FIELDS.getValue("vod")
        val wanted = HashSet<String>()
        spec.forEach { f -> if (!f.startsWith("*")) f.substringBefore(":").split("|").forEach { wanted.add(it) } }
        count.set(0)
        val r = JsonReader(InputStreamReader(input, "UTF-8"))
        r.isLenient = true
        val w = JsonWriter(OutputStreamWriter(out, "UTF-8"))
        w.beginArray()
        when (r.peek()) {
            JsonToken.BEGIN_ARRAY -> { r.beginArray(); while (r.hasNext()) item(r, w, spec, wanted); r.endArray() }
            JsonToken.BEGIN_OBJECT -> { r.beginObject(); while (r.hasNext()) { r.nextName(); item(r, w, spec, wanted) }; r.endObject() }
            else -> r.skipValue()
        }
        w.endArray(); w.flush()
    }

    private fun scalar(r: JsonReader): String = when (r.peek()) {
        JsonToken.STRING, JsonToken.NUMBER -> r.nextString()
        JsonToken.BOOLEAN -> r.nextBoolean().toString()
        JsonToken.NULL -> { r.nextNull(); "" }
        else -> { r.skipValue(); "" }
    }

    private fun item(r: JsonReader, w: JsonWriter, spec: List<String>, wanted: Set<String>) {
        if (r.peek() != JsonToken.BEGIN_OBJECT) { r.skipValue(); return }
        count.incrementAndGet()
        val m = HashMap<String, String>()
        var cats: ArrayList<String>? = null
        var backdrop = ""
        r.beginObject()
        while (r.hasNext()) {
            val n = r.nextName()
            when {
                n == "category_ids" && r.peek() == JsonToken.BEGIN_ARRAY -> {
                    val l = ArrayList<String>(); r.beginArray(); while (r.hasNext()) { val v = scalar(r); if (v.isNotEmpty()) l.add(v) }; r.endArray(); cats = l
                }
                n == "backdrop_path" -> {
                    if (r.peek() == JsonToken.BEGIN_ARRAY) {
                        r.beginArray(); while (r.hasNext()) { val v = scalar(r); if (backdrop.isEmpty()) backdrop = v }; r.endArray()
                    } else backdrop = scalar(r)
                }
                n in wanted -> m[n] = scalar(r)
                else -> r.skipValue()
            }
        }
        r.endObject()
        w.beginArray()
        for (f in spec) {
            when (f) {
                "*cats" -> { val c = cats; if (c == null || c.size < 2) w.nullValue() else { w.beginArray(); c.forEach { w.value(it) }; w.endArray() } }
                "*backdrop" -> w.value(backdrop)
                else -> {
                    val max = f.substringAfter(":", "").toIntOrNull() ?: 0
                    var v = f.substringBefore(":").split("|").map { m[it] ?: "" }.firstOrNull { it.isNotEmpty() } ?: ""
                    if (max > 0 && v.length > max) v = v.substring(0, max)
                    w.value(v)
                }
            }
        }
        w.endArray()
    }
}
