package com.secretly.secretly_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Обновляет токен пушей после перезагрузки телефона и ПОСЛЕ ОБНОВЛЕНИЯ ПРИЛОЖЕНИЯ.
 *
 * 🔴 ПАДЕНИЕ ПРИ КАЖДОМ ОБНОВЛЕНИИ (Play Console, 20.08.2026 — 46% всех сбоев,
 * версии 446, 456, 468, 531).
 *
 * Здесь стояло `task.result` ДО проверки `task.isSuccessful`, а вокруг —
 * `try/finally` БЕЗ `catch`. `Task.getResult()` по договору бросает исключение,
 * когда задача провалилась, и оно улетало из лямбды прямо в систему: приложение
 * падало. Провал же тут обычен — на приёмник `MY_PACKAGE_REPLACED` мы попадаем
 * сразу после установки, когда сети может не быть вовсе, а сервисы Google ещё
 * поднимаются.
 *
 * Отсюда два правила:
 *  * сначала спросить `isSuccessful`, только потом трогать результат;
 *  * ловить ВСЁ: не бывает причины, по которой ненужный токен стоит падения
 *    приложения на глазах у человека, только что нажавшего «Обновить».
 *
 * ────────────────────────────────────────────────────────────────────────────
 *
 * 🔴 ЗАВИСАНИЕ ПРИ ОБНОВЛЕНИИ (Play Console, 09.09.2026, версия 544 и ещё одна):
 *
 * ```
 * Native method - android.os.MessageQueue.nativePollOnce
 * Broadcast of Intent { act=android.intent.action.MY_PACKAGE_REPLACED
 *                       cmp=com.secretly.secretly_app/.PushTokenBootReceiver }
 * ```
 *
 * Это ОТДЕЛЬНЫЙ дефект, а не остаток предыдущего: `goAsync()` стоял здесь и до
 * правки 20.08, и та правка его не касалась.
 *
 * Суть: `goAsync()` — обещание системе доработать в фоне и позвать `finish()`.
 * А `finish()` звался ТОЛЬКО из обработчика задачи Firebase. Условия, в которых
 * мы сюда попадаем, — те же самые: сразу после установки сети может не быть, а
 * сервисы Google ещё поднимаются. Firebase в таком состоянии умеет не отвечать
 * ВОВСЕ — ни успехом, ни отказом. Обработчик не срабатывает, `finish()` не
 * вызывается, и система поднимает ANR.
 *
 * Отсюда третье правило: **ожидание обязано быть ограничено по времени**.
 * Ниже — таймер на [FINISH_TIMEOUT_MS] и [AtomicBoolean], который делает
 * `finish()` идемпотентным: звать его дважды — само по себе исключение.
 *
 * Токен от этого не теряется: если Firebase ответит уже после таймера, а процесс
 * ещё жив, обработчик отработает и сохранит токен как обычно — от `finish()` он
 * не зависит. Если процесс к тому времени закрыт, токен обновится при следующем
 * запуске приложения, ровно как и сегодня при любом отказе Firebase.
 */
class PushTokenBootReceiver : BroadcastReceiver() {
    private companion object {
        /**
         * Предел системы для приёмника переднего плана — 10 с; берём с запасом.
         * Рабочий ответ Firebase укладывается в доли секунды, так что срезать
         * этим порогом мы можем только уже зависшее ожидание.
         */
        const val FINISH_TIMEOUT_MS = 8_000L
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        val pendingResult = goAsync()
        // Ровно один `finish()` за жизнь приёмника — сколько бы путей сюда ни
        // сошлось (ответ Firebase, таймер, бросок при самом вызове).
        val finished = AtomicBoolean(false)
        val finishOnce = {
            if (finished.compareAndSet(false, true)) {
                try {
                    pendingResult.finish()
                } catch (_: Throwable) {
                    // Система уже закрыла приёмник — заявлять не о чем.
                }
            }
        }

        // Страховка от молчащего Firebase: отпускаем приёмник сами, не дожидаясь
        // ANR. Если ответ придёт раньше — этот таймер уже ничего не сделает.
        Handler(Looper.getMainLooper()).postDelayed({
            if (!finished.get()) {
                Log.w(
                    "SecretlyFCM",
                    "FCM token boot refresh timed out after ${FINISH_TIMEOUT_MS}ms — releasing receiver"
                )
            }
            finishOnce()
        }, FINISH_TIMEOUT_MS)

        try {
            FirebaseMessaging.getInstance().token
                .addOnCompleteListener { task ->
                    try {
                        if (task.isSuccessful) {
                            // Результат читаем ТОЛЬКО у удавшейся задачи.
                            val token = task.result?.trim().orEmpty()
                            if (token.isNotEmpty()) {
                                SecretlyFirebaseMessagingService.storeFcmToken(context, token)
                                Log.d("SecretlyFCM", "FCM token refreshed after boot/package update")
                            }
                        } else {
                            Log.w(
                                "SecretlyFCM",
                                "FCM token boot refresh failed: ${task.exception?.message}"
                            )
                        }
                    } catch (t: Throwable) {
                        // Токен подождёт до следующего запуска приложения.
                        Log.w("SecretlyFCM", "FCM token boot refresh threw: ${t.message}")
                    } finally {
                        // Сохранение токена выше НЕ зависит от того, сработал ли
                        // таймер: даже опоздавший ответ доводится до конца.
                        finishOnce()
                    }
                }
        } catch (t: Throwable) {
            // Сам вызов Firebase может бросить, если сервисы недоступны.
            Log.w("SecretlyFCM", "FCM token boot refresh not started: ${t.message}")
            finishOnce()
        }
    }
}
