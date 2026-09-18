package com.secretly.secretly_app

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * След о входящих звонках, которые показала НАТИВНАЯ плашка.
 *
 * 🔴 ЗАЧЕМ (07.08.2026, поле: «на Андроид только в шторке, в чате информации о
 * неотвеченом вызове нет»). Запись о звонке в ленту чата пишет ровно одно место
 * — `_endCall` в call_manager.dart, и только если Dart успел обработать
 * приглашение. Когда Activity убита, приглашение обрабатывает FCM-служба, Dart
 * о звонке не узнаёт никогда, и в чате не остаётся ничего.
 *
 * Этот след — мост через ту пропасть: натив записывает факт звонка сюда, Dart
 * на ближайшем запуске его вычерпывает и пишет пропущенный.
 *
 * 🔴 СПИСОК, А НЕ ОДИН СЛОТ. Главный капкан, и он не теоретический: на
 * однослотовом буфере мы уже обожглись 04.08 — он затирал решение «Принять».
 * Два пропущенных подряд обязаны остаться двумя.
 *
 * 🔴 НИКАКОЙ РАСШИФРОВКИ. Всё, что здесь лежит, приходит открытым текстом в
 * метаданных пуша. Трогать шифр в фоне запрещено инвариантом И-3: расшифровка
 * только в главном изоляте, иначе получаем двух писателей в ратчет.
 */
object MissedCallTrail {
    private const val TAG = "MissedCallTrail"
    private const val PREFS = "secretly_pending_actions"
    private const val KEY = "missed_call_trail_v1"

    /** Больше держать незачем: Dart вычерпывает след на ближайшем запуске. */
    private const val MAX_ENTRIES = 20

    /**
     * Устройство, пролежавшее месяц, не имеет права вывалить в ленту древние
     * звонки — человек давно всё увидел на другом устройстве или забыл.
     */
    private const val MAX_AGE_MS = 7L * 24 * 60 * 60 * 1000

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun read(context: Context): JSONArray =
        try {
            JSONArray(prefs(context).getString(KEY, "[]") ?: "[]")
        } catch (e: Exception) {
            // Испорченную запись лучше потерять целиком, чем уронить на ней
            // показ входящего звонка.
            Log.w(TAG, "trail unreadable, starting empty: $e")
            JSONArray()
        }

    private fun write(context: Context, array: JSONArray) {
        prefs(context).edit().putString(KEY, array.toString()).apply()
    }

    /**
     * Записывает показанный входящий звонок.
     *
     * Повтор по тому же `callId` не создаёт второй записи: пуш о приглашении
     * может прийти дважды, а звонок при этом один.
     */
    fun add(
        context: Context,
        callId: String,
        callAttemptId: String,
        callerProfileId: String?,
        callerName: String?,
        isVideo: Boolean,
        createdAtMs: Long,
    ) {
        val id = callId.trim()
        if (id.isEmpty()) return
        try {
            val now = System.currentTimeMillis()
            val source = read(context)
            val out = JSONArray()
            for (i in 0 until source.length()) {
                val item = source.optJSONObject(i) ?: continue
                if (item.optString("call_id") == id) continue // дедуп по звонку
                val age = now - item.optLong("created_at_ms", now)
                if (age > MAX_AGE_MS) continue // просрочено
                out.put(item)
            }
            out.put(
                JSONObject().apply {
                    put("call_id", id)
                    put("call_attempt_id", callAttemptId.trim().ifBlank { id })
                    put("caller_profile_id", callerProfileId?.trim().orEmpty())
                    put("caller_name", callerName?.trim().orEmpty())
                    put("is_video", isVideo)
                    put("created_at_ms", if (createdAtMs > 0) createdAtMs else now)
                }
            )
            // Потолок: держим САМЫЕ СВЕЖИЕ, отрезая с головы.
            val capped = if (out.length() <= MAX_ENTRIES) out else JSONArray().also { trimmed ->
                for (i in (out.length() - MAX_ENTRIES) until out.length()) {
                    out.optJSONObject(i)?.let { trimmed.put(it) }
                }
            }
            write(context, capped)
            // Молчание при успехе стоило нам полевого прогона: след писался не
            // в ту функцию, а понять это по логу было НЕЧЕМ. Строка дешёвая —
            // одна на звонок, и в ней только обрезанный идентификатор.
            Log.d(TAG, "trail add callId=${id.take(8)} size=${capped.length()}")
        } catch (e: Exception) {
            Log.w(TAG, "trail add failed: $e")
        }
    }

    /**
     * Снимает след: звонок был ОТРАБОТАН, а не пропущен.
     *
     * 🔴 Зовётся при «Принять» и «Отклонить» с плашки. Без этого принятый
     * разговор отразился бы в ленте как пропущенный — то есть правка, которая
     * чинит одну ложь, порождала бы другую. Отбой звонившего след НЕ снимает:
     * это и есть пропущенный.
     */
    fun remove(context: Context, callId: String?) {
        val id = callId?.trim().orEmpty()
        if (id.isEmpty()) return
        try {
            val source = read(context)
            val out = JSONArray()
            for (i in 0 until source.length()) {
                val item = source.optJSONObject(i) ?: continue
                if (item.optString("call_id") == id) continue
                out.put(item)
            }
            write(context, out)
        } catch (e: Exception) {
            Log.w(TAG, "trail remove failed: $e")
        }
    }

    /**
     * Отдаёт след и СРАЗУ его очищает.
     *
     * Очистка именно здесь, а не после успешной записи в базу: повторно
     * показать пропущенный хуже, чем не показать вовсе, — человек решит, что
     * ему звонили дважды. Дедуп на стороне Dart всё равно есть
     * (`recordCallOutcome` дедуплицирует по попытке).
     */
    fun drain(context: Context): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        try {
            val source = read(context)
            val now = System.currentTimeMillis()
            for (i in 0 until source.length()) {
                val item = source.optJSONObject(i) ?: continue
                val createdAtMs = item.optLong("created_at_ms", 0L)
                if (createdAtMs <= 0L || now - createdAtMs > MAX_AGE_MS) continue
                out.add(
                    mapOf(
                        "call_id" to item.optString("call_id"),
                        "call_attempt_id" to item.optString("call_attempt_id"),
                        "caller_profile_id" to item.optString("caller_profile_id"),
                        "caller_name" to item.optString("caller_name"),
                        "is_video" to item.optBoolean("is_video", false),
                        "created_at_ms" to createdAtMs,
                    )
                )
            }
            prefs(context).edit().remove(KEY).apply()
            Log.d(TAG, "trail drain size=${out.size}")
        } catch (e: Exception) {
            Log.w(TAG, "trail drain failed: $e")
        }
        return out
    }
}
