// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
use std::path::Path;

use serde::{Deserialize, Serialize};
use tokio_rusqlite::Connection;
use tokio_rusqlite::params;
use tokio_rusqlite::rusqlite;
use tokio_rusqlite::rusqlite::OptionalExtension;

#[derive(Clone)]
pub struct KeysStore {
    conn: Connection,
    /// AUTO-HYGIENE (2026-07-19, closes audit F2 "keys never evicts a rotated
    /// device"). A device is advertised to senders only while its own activity
    /// is within this window of the profile's FRESHEST device. Relative-to-
    /// sibling by design: a quiet single-device profile is its own maximum and
    /// can never evict itself (the vacation case), while a rotated/abandoned
    /// id — frozen while its sibling keeps advancing — drops out of every
    /// sender's fanout after the window, automatically.
    ///
    /// Default 14 days (was a hard-coded 30): the relay mailbox TTL is 7 days,
    /// so a device silent for 14 has already lost a week of mail unread —
    /// encrypting more copies to it only fills a dead mailbox. Signal's
    /// linked-device auto-unlink (~30 d) is the same mechanism, one notch
    /// laxer. Env `SECRETLY_KEYS_DEVICE_LIVENESS_WINDOW_DAYS`, floored at 8
    /// (relay TTL + 1) so a typo can never evict a device that could still
    /// drain its mailbox.
    device_liveness_window_ms: i64,
}

/// 🔴 ВЫТЕСНЕНИЕ ЗАМЕНЁННОГО УСТРОЙСТВА (03.08.2026, полевой инцидент).
///
/// Тестировщик перешёл с ручной APK на сборку из Play. Подписи разные, поэтому
/// Android потребовал удалить приложение — и на первом запуске оно завело НОВЫЙ
/// device_id под тем же профилем. Старое устройство осталось опубликованным, и
/// собеседница продолжала слать сообщения и ЗВОНИТЬ в мёртвый ящик: 57 писем в
/// никуда и сорванный видеозвонок.
///
/// Окно жизни в 14 суток тут бессильно: устройство замолчало полтора часа назад
/// и проходит его с огромным запасом. Нужен другой признак — не «давно молчит»,
/// а «замолчало РОВНО ТОГДА, когда появилась замена».
///
/// Именно поэтому правило требует ОБА условия. Одного «молчит» мало: у честного
/// второго устройства (телефон + десктоп) старое продолжает опрашивать ящик и
/// после появления нового, поэтому под правило оно не попадает никогда.
///
/// Запас на передачу эстафеты: старое устройство могло опросить ящик ещё раз
/// уже после регистрации нового. Держим его МАЛЕНЬКИМ — чем он больше, тем
/// больше устройств правило признаёт заменёнными, а ошибаться здесь можно
/// только в сторону «оставить лишнее».
pub(crate) const SUPERSEDED_HANDOVER_GRACE_MS: i64 = 5 * 60 * 1000;

/// Сколько устройство должно молчать (ОТНОСИТЕЛЬНО самой свежей активности
/// профиля), чтобы считаться заменённым. Пятнадцать минут — компромисс: замена
/// распознаётся почти сразу, а телефон, который просто уснул на пару минут,
/// под правило не попадает.
pub(crate) const SUPERSEDED_SILENCE_MS: i64 = 15 * 60 * 1000;

pub(crate) fn device_liveness_window_ms_from_env() -> i64 {
    device_liveness_window_ms_from_days(
        std::env::var("SECRETLY_KEYS_DEVICE_LIVENESS_WINDOW_DAYS")
            .ok()
            .and_then(|v| v.trim().parse::<i64>().ok()),
    )
}

pub(crate) fn device_liveness_window_ms_from_days(days: Option<i64>) -> i64 {
    const DAY_MS: i64 = 24 * 60 * 60 * 1000;
    days.unwrap_or(14).max(8) * DAY_MS
}

#[cfg(test)]
mod tests {
    use super::*;

    // AUTO-HYGIENE (2026-07-19): the liveness window is sibling-relative and
    // now defaults to 14 days. These pin the two behaviors that must never
    // regress: a rotated/abandoned sibling drops out automatically, and a
    /// 🔴 БОЕВОЕ ОБНОВЛЕНИЕ: база СО СТАРОЙ схемой, открытая новым кодом.
    ///
    /// Все прочие тесты работают на свежей базе, а она получает новые столбцы из
    /// `CREATE TABLE` и потому НЕ доказывает ничего про прод. На проде база уже
    /// существует, столбцов в ней нет, и если бы `ALTER` не выполнился, то первый
    /// же `SELECT` с новыми столбцами упал бы с «no such column» — то есть выдача
    /// связок умерла бы, а вместе с ней доставка сообщений. Это единственный
    /// сценарий, который здесь по-настоящему страшен, и он проверяется тут.
    #[tokio::test]
    async fn a_database_created_before_account_identity_upgrades_and_still_serves() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("keys.db");

        // Ставим таблицу ровно в том виде, в каком она была ДО правки.
        {
            let pre = Connection::open(&path).await.unwrap();
            pre.call(|c| -> Result<(), rusqlite::Error> {
                c.execute_batch(
                    r#"
CREATE TABLE device_key_bundles (
  device_id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL,
  identity_key_pub_b64 TEXT NOT NULL,
  signed_prekey_pub_b64 TEXT NOT NULL,
  signed_prekey_sig_b64 TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
INSERT INTO device_key_bundles(device_id, profile_id, identity_key_pub_b64, signed_prekey_pub_b64, signed_prekey_sig_b64, updated_at_ms)
VALUES('D-old', 'P-old', 'ik-old', 'spk-old', 'sig-old', 1000);
"#,
                )?;
                Ok(())
            })
            .await
            .unwrap();
        }

        // Новый код открывает её: init() обязан дописать столбцы сам.
        let store = KeysStore::open(&path).await.unwrap();
        store.insert_profile("P-old", 1_000, None).await.unwrap();
        store
            .register_device("P-old", "D-old", Some("ik-old"), 1_000)
            .await
            .unwrap();

        // 🔴 И выдача связок обязана работать. Именно этот вызов и упал бы на
        // «no such column», не выполнись ALTER.
        let bundles = store.fetch_bundles_for_profile("P-old").await.unwrap();
        assert_eq!(bundles.len(), 1, "связка из старой базы обязана выдаваться");
        assert_eq!(bundles[0].device_id, "D-old");
        assert_eq!(bundles[0].identity_key_pub_b64, "ik-old");
        // Данных о личности аккаунта у неё нет, и это правильно — не выдумываем.
        assert!(bundles[0].account_identity_pub_b64.is_none());
        assert!(bundles[0].device_cert_b64.is_none());

        // Публикация в такую базу тоже обязана проходить.
        //
        // identity-ключ ОБЯЗАН совпадать с зарегистрированным: publish_key_bundle
        // отказывает при расхождении, и это правильная защита — устройство не
        // может опубликовать связку под личностью, которую не регистрировало.
        // Первая версия этого теста подсунула другой ключ и получила законный
        // отказ; ошибка была в тесте, а не в коде.
        let published = store
            .publish_key_bundle(
                "P-old",
                "D-old",
                "ik-old",
                "spk-new",
                "sig-new",
                vec![],
                2_000,
                Some("aik-new"),
                Some("cert-new"),
            )
            .await
            .unwrap();
        assert!(published);
        let after = store.fetch_bundles_for_profile("P-old").await.unwrap();
        assert_eq!(after[0].account_identity_pub_b64.as_deref(), Some("aik-new"));
        assert_eq!(after[0].device_cert_b64.as_deref(), Some("cert-new"));
    }

    // quiet single-device profile can never evict itself.
    #[tokio::test]
    async fn sibling_stale_device_drops_out_after_liveness_window() {
        const DAY: i64 = 24 * 60 * 60 * 1000;
        let dir = tempfile::tempdir().unwrap();
        let store = KeysStore::open(dir.path().join("keys.db")).await.unwrap();
        store.insert_profile("P", 1_000, None).await.unwrap();

        // The zombie registers once and never comes back.
        store
            .register_device("P", "ZOMBIE", Some("ik_z"), 1_000)
            .await
            .unwrap();
        // The live device keeps advancing 20 days past the zombie — outside
        // the 14d default (this exact case was VISIBLE under the old 30d).
        store
            .register_device("P", "LIVE", Some("ik_l"), 1_000)
            .await
            .unwrap();
        store
            .register_device("P", "LIVE", Some("ik_l"), 1_000 + 20 * DAY)
            .await
            .unwrap();

        let devices = store.list_devices("P").await.unwrap();
        assert_eq!(
            devices,
            vec!["LIVE".to_string()],
            "a sibling 20d staler than the freshest must drop at the 14d default"
        );

        // A sibling within the window stays advertised.
        store
            .register_device("P", "FRESH", Some("ik_f"), 1_000 + 10 * DAY)
            .await
            .unwrap();
        let devices = store.list_devices("P").await.unwrap();
        assert!(devices.contains(&"LIVE".to_string()));
        assert!(devices.contains(&"FRESH".to_string()));
        assert!(!devices.contains(&"ZOMBIE".to_string()));
    }

    /// 🔴 ПЕРЕУСТАНОВКА ПРИЛОЖЕНИЯ (полевой инцидент 03.08.2026).
    ///
    /// Точные числа того дня: старое устройство завели 29.07, оно замолчало в
    /// 14:54:34; новое появилось в 14:56:14 — через 100 секунд. Окно жизни в
    /// 14 суток такую замену не ловит вообще, и собеседница полтора часа слала
    /// сообщения и звонила в мёртвый ящик.
    #[tokio::test]
    async fn replaced_device_drops_out_within_minutes_not_days() {
        const MIN: i64 = 60 * 1000;
        let dir = tempfile::tempdir().unwrap();
        let store = KeysStore::open(dir.path().join("keys.db")).await.unwrap();
        store.insert_profile("P", 0, None).await.unwrap();

        // Старое устройство живёт своей жизнью и замолкает на отметке 100 мин.
        store.register_device("P", "OLD", Some("ik_o"), 0).await.unwrap();
        store
            .register_device("P", "OLD", Some("ik_o"), 100 * MIN)
            .await
            .unwrap();

        // Через 100 секунд появляется замена — ровно как при переустановке.
        let new_at = 100 * MIN + 100 * 1000;
        store.register_device("P", "NEW", Some("ik_n"), new_at).await.unwrap();

        // Сразу после замены старое ещё видно: молчит меньше порога, и это
        // правильно — вдруг это просто второе устройство, которое сейчас
        // проснётся.
        let devices = store.list_devices("P").await.unwrap();
        assert!(
            devices.contains(&"OLD".to_string()),
            "сразу после замены рано выносить приговор"
        );

        // Новое поработало 20 минут, старое так и молчит — замена доказана.
        store
            .register_device("P", "NEW", Some("ik_n"), new_at + 20 * MIN)
            .await
            .unwrap();
        assert_eq!(
            store.list_devices("P").await.unwrap(),
            vec!["NEW".to_string()],
            "заменённое устройство обязано уйти из выдачи за минуты, а не за 14 суток"
        );
    }

    /// 🔴 ВЫДАЧА СВЯЗОК ОБЯЗАНА СОГЛАСОВЫВАТЬСЯ СО СПИСКОМ УСТРОЙСТВ.
    ///
    /// Полевая потеря 06.08.2026: `list_devices` заменённое устройство
    /// исключал верно, а `fetch_bundles_for_profile` фильтровал по СВЕЖЕСТИ
    /// СВЯЗКИ и его связку отдавал. Отправитель брал мёртвый device_id из
    /// своего кэша, спрашивал связку по id, получал её и слал в ящик, который
    /// никто не вычерпывает. 21 сообщение ушло в никуда без единой ошибки.
    ///
    /// Два эндпоинта — два разных понятия «живой»; этот тест держит их вместе.
    #[tokio::test]
    async fn bundle_fetch_agrees_with_device_list_after_replacement() {
        const MIN: i64 = 60 * 1000;
        let dir = tempfile::tempdir().unwrap();
        let store = KeysStore::open(dir.path().join("keys.db")).await.unwrap();
        store.insert_profile("P", 0, None).await.unwrap();

        // Старое устройство публикует связку и замолкает на отметке 100 мин.
        store.register_device("P", "OLD", Some("ik_o"), 0).await.unwrap();
        store
            .publish_key_bundle("P", "OLD", "ik_o", "spk_o", "sig_o", vec![], 0,
                None,
                None,
            )
            .await
            .unwrap();
        store
            .register_device("P", "OLD", Some("ik_o"), 100 * MIN)
            .await
            .unwrap();

        // Замена: регистрируется и публикует свою связку.
        let new_at = 100 * MIN + 100 * 1000;
        store.register_device("P", "NEW", Some("ik_n"), new_at).await.unwrap();
        store
            .publish_key_bundle("P", "NEW", "ik_n", "spk_n", "sig_n", vec![], new_at,
                None,
                None,
            )
            .await
            .unwrap();
        store
            .register_device("P", "NEW", Some("ik_n"), new_at + 20 * MIN)
            .await
            .unwrap();

        let listed = store.list_devices("P").await.unwrap();
        let bundled: Vec<String> = store
            .fetch_bundles_for_profile("P")
            .await
            .unwrap()
            .into_iter()
            .map(|b| b.device_id)
            .collect();

        assert_eq!(listed, vec!["NEW".to_string()]);
        assert_eq!(
            bundled, listed,
            "связки обязаны выдаваться ровно тем устройствам, что перечислены; \
             иначе отправитель шифрует в мёртвый ящик"
        );
    }

    /// 🔴 ТРИ ФУНКЦИИ — ОДНО ПОНЯТИЕ «ЖИВОЕ УСТРОЙСТВО».
    ///
    /// Расхождение стоило 61 сообщения уже ПОСЛЕ того, как правило добавили в
    /// выдачу связок: список для рассылки берётся из `list_device_statuses`, а
    /// там правила не было. Этот тест держит все три вместе — если появится
    /// четвёртое место, оно обязано быть добавлено и сюда.
    #[tokio::test]
    async fn all_three_device_views_agree_after_replacement() {
        const MIN: i64 = 60 * 1000;
        let dir = tempfile::tempdir().unwrap();
        let store = KeysStore::open(dir.path().join("keys.db")).await.unwrap();
        store.insert_profile("P", 0, None).await.unwrap();

        store.register_device("P", "OLD", Some("ik_o"), 0).await.unwrap();
        store
            .publish_key_bundle("P", "OLD", "ik_o", "spk_o", "sig_o", vec![], 0,
                None,
                None,
            )
            .await
            .unwrap();
        store
            .register_device("P", "OLD", Some("ik_o"), 100 * MIN)
            .await
            .unwrap();

        let new_at = 100 * MIN + 100 * 1000;
        store.register_device("P", "NEW", Some("ik_n"), new_at).await.unwrap();
        store
            .publish_key_bundle("P", "NEW", "ik_n", "spk_n", "sig_n", vec![], new_at,
                None,
                None,
            )
            .await
            .unwrap();
        store
            .register_device("P", "NEW", Some("ik_n"), new_at + 20 * MIN)
            .await
            .unwrap();

        let listed = store.list_devices("P").await.unwrap();
        let bundled: Vec<String> = store
            .fetch_bundles_for_profile("P")
            .await
            .unwrap()
            .into_iter()
            .map(|b| b.device_id)
            .collect();
        let statuses: Vec<String> = store
            .list_device_statuses("P")
            .await
            .unwrap()
            .into_iter()
            .map(|s| s.device_id)
            .collect();

        assert_eq!(listed, vec!["NEW".to_string()]);
        assert_eq!(bundled, listed, "выдача связок разошлась со списком");
        assert_eq!(
            statuses, listed,
            "СПИСОК ДЛЯ РАССЫЛКИ разошёлся со списком — именно так терялись сообщения"
        );
    }

    /// И обратная защёлка для третьей функции: живое второе устройство обязано
    /// остаться в списке для рассылки, иначе многоустройственность умрёт молча.
    #[tokio::test]
    async fn device_statuses_keep_a_genuine_second_device() {
        const MIN: i64 = 60 * 1000;
        let dir = tempfile::tempdir().unwrap();
        let store = KeysStore::open(dir.path().join("keys.db")).await.unwrap();
        store.insert_profile("P", 0, None).await.unwrap();

        store.register_device("P", "PHONE", Some("ik_p"), 0).await.unwrap();
        let desk_at = 50 * MIN;
        store.register_device("P", "DESK", Some("ik_d"), desk_at).await.unwrap();
        store
            .register_device("P", "PHONE", Some("ik_p"), desk_at + 30 * MIN)
            .await
            .unwrap();

        let mut statuses: Vec<String> = store
            .list_device_statuses("P")
            .await
            .unwrap()
            .into_iter()
            .map(|s| s.device_id)
            .collect();
        statuses.sort();
        assert_eq!(statuses, vec!["DESK".to_string(), "PHONE".to_string()]);
    }

    /// Обратная сторона: связка ЖИВОГО второго устройства обязана выдаваться.
    /// Без этой проверки правило выше можно «починить» так, что многоустройст-
    /// венность умрёт молча.
    #[tokio::test]
    async fn bundle_fetch_keeps_a_genuine_second_device() {
        const MIN: i64 = 60 * 1000;
        let dir = tempfile::tempdir().unwrap();
        let store = KeysStore::open(dir.path().join("keys.db")).await.unwrap();
        store.insert_profile("P", 0, None).await.unwrap();

        store.register_device("P", "PHONE", Some("ik_p"), 0).await.unwrap();
        store
            .publish_key_bundle("P", "PHONE", "ik_p", "spk_p", "sig_p", vec![], 0,
                None,
                None,
            )
            .await
            .unwrap();

        // Позже привязали десктоп — и телефон ПРОДОЛЖАЕТ подавать признаки жизни.
        let desk_at = 50 * MIN;
        store.register_device("P", "DESK", Some("ik_d"), desk_at).await.unwrap();
        store
            .publish_key_bundle("P", "DESK", "ik_d", "spk_d", "sig_d", vec![], desk_at,
                None,
                None,
            )
            .await
            .unwrap();
        store
            .register_device("P", "PHONE", Some("ik_p"), desk_at + 30 * MIN)
            .await
            .unwrap();

        let mut bundled: Vec<String> = store
            .fetch_bundles_for_profile("P")
            .await
            .unwrap()
            .into_iter()
            .map(|b| b.device_id)
            .collect();
        bundled.sort();
        assert_eq!(
            bundled,
            vec!["DESK".to_string(), "PHONE".to_string()],
            "живой телефон обязан получать сообщения и после привязки десктопа"
        );
    }

    /// 🔴 ЧЕСТНОЕ ВТОРОЕ УСТРОЙСТВО НЕ ТРОГАЕМ. Это единственный способ
    /// сломать многоустройственность, поэтому проверяется отдельно: телефон
    /// продолжает опрашивать ящик и ПОСЛЕ того, как привязали десктоп — значит
    /// он не заменён, а просто старше.
    #[tokio::test]
    async fn genuine_second_device_is_never_treated_as_replaced() {
        const MIN: i64 = 60 * 1000;
        let dir = tempfile::tempdir().unwrap();
        let store = KeysStore::open(dir.path().join("keys.db")).await.unwrap();
        store.insert_profile("P", 0, None).await.unwrap();

        store.register_device("P", "PHONE", Some("ik_p"), 0).await.unwrap();
        // Десктоп привязали позже.
        store
            .register_device("P", "DESKTOP", Some("ik_d"), 60 * MIN)
            .await
            .unwrap();
        // И телефон продолжает жить ПОСЛЕ этого — вот отличие от переустановки.
        store
            .register_device("P", "PHONE", Some("ik_p"), 200 * MIN)
            .await
            .unwrap();
        store
            .register_device("P", "DESKTOP", Some("ik_d"), 210 * MIN)
            .await
            .unwrap();

        let devices = store.list_devices("P").await.unwrap();
        assert!(devices.contains(&"PHONE".to_string()), "телефон обязан остаться");
        assert!(devices.contains(&"DESKTOP".to_string()));
    }

    /// 🔴 СЛУЧАЙ ВЛАДЕЛЬЦА (11.09.2026): ДЕСКТОП НЕ ВЫТЕСНЯЕТ ТЕЛЕФОН.
    ///
    /// Отличие от [genuine_second_device_is_never_treated_as_replaced]: там
    /// телефон продолжал ходить на сервер ключей ПОСЛЕ появления десктопа, и
    /// правило его не трогало. Здесь телефон замолчал — как в жизни: он живёт
    /// на реле, а к серверу ключей обращается редко.
    ///
    /// На проде это выглядело так: телефон последний раз отметился в 19:05:07,
    /// десктоп зарегистрировался в 19:08:47 — три минуты. Оба порога пройдены,
    /// телефон объявлен заменённым и выпал из собственного профиля НАВСЕГДА:
    /// вытесненное устройство получает «device was removed» и не может обновить
    /// last_seen, поэтому условие «молчит» только крепнет.
    #[tokio::test]
    async fn desktop_never_supersedes_a_quiet_phone() {
        const MIN: i64 = 60 * 1000;
        let dir = tempfile::tempdir().unwrap();
        let store = KeysStore::open(dir.path().join("keys.db")).await.unwrap();
        store.insert_profile("P", 0, None).await.unwrap();

        store.register_device("P", "PHONE", Some("ik_p"), 0).await.unwrap();
        store
            .upsert_device_metadata("P", "PHONE", "mobile", Some("Android"), 0)
            .await
            .unwrap();

        // Три минуты спустя заводят десктоп — и телефон больше не отмечается.
        store
            .register_device("P", "DESKTOP", Some("ik_d"), 3 * MIN)
            .await
            .unwrap();
        store
            .upsert_device_metadata("P", "DESKTOP", "desktop", Some("macOS Desktop"), 3 * MIN)
            .await
            .unwrap();
        // Десктоп живёт дальше, телефон молчит намного дольше обоих порогов.
        store
            .register_device("P", "DESKTOP", Some("ik_d"), 3000 * MIN)
            .await
            .unwrap();

        let devices = store.list_devices("P").await.unwrap();
        assert!(
            devices.contains(&"PHONE".to_string()),
            "телефон обязан остаться: десктоп — ДРУГОЙ класс, это не замена. Выдача: {devices:?}"
        );
        assert!(devices.contains(&"DESKTOP".to_string()));
    }

    /// А вот замена В ПРЕДЕЛАХ КЛАССА обязана работать как прежде — ради неё
    /// правило и писалось 03.08 (переустановка APK на том же телефоне).
    #[tokio::test]
    async fn same_class_replacement_still_supersedes() {
        const MIN: i64 = 60 * 1000;
        let dir = tempfile::tempdir().unwrap();
        let store = KeysStore::open(dir.path().join("keys.db")).await.unwrap();
        store.insert_profile("P", 0, None).await.unwrap();

        store.register_device("P", "OLD_PHONE", Some("ik_o"), 0).await.unwrap();
        store
            .upsert_device_metadata("P", "OLD_PHONE", "mobile", Some("Android"), 0)
            .await
            .unwrap();
        store
            .register_device("P", "NEW_PHONE", Some("ik_n"), 3 * MIN)
            .await
            .unwrap();
        store
            .upsert_device_metadata("P", "NEW_PHONE", "mobile", Some("Android"), 3 * MIN)
            .await
            .unwrap();
        store
            .register_device("P", "NEW_PHONE", Some("ik_n"), 3000 * MIN)
            .await
            .unwrap();

        let devices = store.list_devices("P").await.unwrap();
        assert!(
            !devices.contains(&"OLD_PHONE".to_string()),
            "переустановка на том же телефоне обязана вытеснять по-прежнему. Выдача: {devices:?}"
        );
    }

    /// 🔴 Инвариант «никогда не отдавать ноль устройств» правило не нарушает:
    /// у самого нового собрата по определению нет, поэтому оно всегда живо.
    #[tokio::test]
    async fn supersession_never_empties_a_profile() {
        const MIN: i64 = 60 * 1000;
        let dir = tempfile::tempdir().unwrap();
        let store = KeysStore::open(dir.path().join("keys.db")).await.unwrap();
        store.insert_profile("P", 0, None).await.unwrap();
        // Цепочка из трёх переустановок подряд.
        store.register_device("P", "A", Some("ik_a"), 0).await.unwrap();
        store.register_device("P", "B", Some("ik_b"), 10 * MIN).await.unwrap();
        store.register_device("P", "C", Some("ik_c"), 20 * MIN).await.unwrap();
        store
            .register_device("P", "C", Some("ik_c"), 100 * MIN)
            .await
            .unwrap();
        assert_eq!(
            store.list_devices("P").await.unwrap(),
            vec!["C".to_string()],
            "остаётся ровно последнее, но НЕ ноль"
        );
    }

    #[tokio::test]
    async fn quiet_single_device_profile_never_self_evicts() {
        let dir = tempfile::tempdir().unwrap();
        let store = KeysStore::open(dir.path().join("keys.db")).await.unwrap();
        store.insert_profile("P", 1_000, None).await.unwrap();
        store
            .register_device("P", "ONLY", Some("ik"), 1_000)
            .await
            .unwrap();
        // The window is relative to the profile's own freshest device — a
        // vacationing single-device user is their own maximum and always
        // resolves, no matter how long ago last_seen was.
        assert_eq!(
            store.list_devices("P").await.unwrap(),
            vec!["ONLY".to_string()]
        );
    }

    #[test]
    fn liveness_window_floors_at_relay_ttl_plus_one_day() {
        const DAY: i64 = 24 * 60 * 60 * 1000;
        // A typo'd/short env value must never produce a window shorter than
        // the relay mailbox TTL (7d) + 1 — a device that could still drain its
        // mailbox must never be hidden from senders.
        assert_eq!(device_liveness_window_ms_from_days(Some(3)), 8 * DAY);
        assert_eq!(device_liveness_window_ms_from_days(Some(-1)), 8 * DAY);
        assert_eq!(device_liveness_window_ms_from_days(None), 14 * DAY);
        assert_eq!(device_liveness_window_ms_from_days(Some(30)), 30 * DAY);
    }

    #[tokio::test]
    async fn publish_and_fetch_pops_one_time_prekey() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("keys.db");
        let store = KeysStore::open(&path).await.unwrap();

        let profile_id = "P1";
        store
            .insert_profile(profile_id, 1_000_000, None)
            .await
            .unwrap();

        // New security rule: device must be registered and bound to its identity key
        // before it can publish key bundles.
        let reg_ok = store
            .register_device(profile_id, "D1", Some("ik"), 1_000_000)
            .await
            .unwrap();
        assert!(reg_ok);

        let ok = store
            .publish_key_bundle(
                profile_id,
                "D1",
                "ik",
                "spk",
                "spk_sig",
                vec![
                    OneTimePrekey {
                        prekey_id: 1,
                        prekey_pub_b64: "otk1".into(),
                    },
                    OneTimePrekey {
                        prekey_id: 2,
                        prekey_pub_b64: "otk2".into(),
                    },
                ],
                1_000_001,
                None,
                None,
            )
            .await
            .unwrap();
        assert!(ok);

        let b1 = store.fetch_bundles_for_profile(profile_id).await.unwrap();
        assert_eq!(b1.len(), 1);
        assert_eq!(b1[0].device_id, "D1");
        assert!(b1[0].one_time_prekey.is_some());
        assert_eq!(b1[0].one_time_prekey.as_ref().unwrap().prekey_id, 1);

        let b2 = store.fetch_bundles_for_profile(profile_id).await.unwrap();
        assert_eq!(b2.len(), 1);
        assert!(b2[0].one_time_prekey.is_some());
        assert_eq!(b2[0].one_time_prekey.as_ref().unwrap().prekey_id, 2);

        let b3 = store.fetch_bundles_for_profile(profile_id).await.unwrap();
        assert_eq!(b3.len(), 1);
        assert!(b3[0].one_time_prekey.is_none());
    }

    #[tokio::test]
    async fn delete_device_removes_registration_and_key_material() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("keys.db");
        let store = KeysStore::open(&path).await.unwrap();

        let profile_id = "P2";
        store
            .insert_profile(profile_id, 1_000_000, None)
            .await
            .unwrap();

        let reg_ok = store
            .register_device(profile_id, "D2", Some("ik2"), 1_000_000)
            .await
            .unwrap();
        assert!(reg_ok);

        let published = store
            .publish_key_bundle(
                profile_id,
                "D2",
                "ik2",
                "spk2",
                "spk_sig2",
                vec![OneTimePrekey {
                    prekey_id: 1,
                    prekey_pub_b64: "otk2".into(),
                }],
                1_000_001,
                None,
                None,
            )
            .await
            .unwrap();
        assert!(published);

        let deleted = store.delete_device(profile_id, "D2").await.unwrap();
        assert!(deleted);
        assert!(store.list_devices(profile_id).await.unwrap().is_empty());
        assert!(store.profile_id_for_device("D2").await.unwrap().is_none());
        assert!(
            store
                .fetch_bundles_for_profile(profile_id)
                .await
                .unwrap()
                .is_empty()
        );
    }

    #[tokio::test]
    async fn stalest_evictable_device_prefers_dead_then_oldest_and_excludes_self() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("keys.db");
        let store = KeysStore::open(&path).await.unwrap();

        let profile_id = "P_EVICT";
        store
            .insert_profile(profile_id, 1_000_000, None)
            .await
            .unwrap();

        // D_OLD_BUNDLE: oldest, but HAS a published bundle.
        store
            .register_device(profile_id, "D_OLD_BUNDLE", Some("ik_old"), 1_000)
            .await
            .unwrap();
        store
            .publish_key_bundle(
                profile_id,
                "D_OLD_BUNDLE",
                "ik_old",
                "spk",
                "spk_sig",
                vec![],
                1_001,
                None,
                None,
            )
            .await
            .unwrap();

        // D_NEWER_DEAD: newer than D_OLD_BUNDLE, but has NO bundle (dead) →
        // must be preferred for eviction over the older-but-bundled device.
        store
            .register_device(profile_id, "D_NEWER_DEAD", Some("ik_dead"), 5_000)
            .await
            .unwrap();

        // The device currently registering; must never be returned.
        store
            .register_device(profile_id, "D_REGISTERING", Some("ik_reg"), 9_000)
            .await
            .unwrap();

        let pick = store
            .stalest_evictable_device(profile_id, "D_REGISTERING")
            .await
            .unwrap();
        assert_eq!(
            pick.as_deref(),
            Some("D_NEWER_DEAD"),
            "dead (no-bundle) device must be evicted before an older bundled one"
        );

        // Drop the dead device, then the only non-self candidate left is the
        // bundled one — it should now be selected.
        store.delete_device(profile_id, "D_NEWER_DEAD").await.unwrap();
        let pick2 = store
            .stalest_evictable_device(profile_id, "D_REGISTERING")
            .await
            .unwrap();
        assert_eq!(pick2.as_deref(), Some("D_OLD_BUNDLE"));
    }

    #[tokio::test]
    async fn stalest_evictable_device_returns_none_when_only_self_remains() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("keys.db");
        let store = KeysStore::open(&path).await.unwrap();

        let profile_id = "P_EVICT_SOLO";
        store
            .insert_profile(profile_id, 1_000_000, None)
            .await
            .unwrap();
        store
            .register_device(profile_id, "D_ONLY", Some("ik"), 1_000)
            .await
            .unwrap();

        // Excluding the only device must yield None so the caller never evicts
        // to zero devices.
        let pick = store
            .stalest_evictable_device(profile_id, "D_ONLY")
            .await
            .unwrap();
        assert!(pick.is_none());
    }

    #[tokio::test]
    async fn stalest_evictable_device_uses_metadata_updated_at_for_recency() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("keys.db");
        let store = KeysStore::open(&path).await.unwrap();

        let profile_id = "P_EVICT_META";
        store
            .insert_profile(profile_id, 1_000_000, None)
            .await
            .unwrap();

        // A is created FIRST (older created_at_ms) but later records fresh
        // activity via device_metadata.updated_at_ms; B is created later but
        // never updates its metadata. Neither has a bundle, so recency decides:
        // A is more recent → B (the staler by activity) is the eviction target.
        store
            .register_device(profile_id, "D_META_A", Some("ik_a"), 1_000)
            .await
            .unwrap();
        store
            .register_device(profile_id, "D_META_B", Some("ik_b"), 2_000)
            .await
            .unwrap();
        store
            .upsert_device_metadata(profile_id, "D_META_A", "mobile", None, 9_999)
            .await
            .unwrap();

        let registering = "D_META_NEW";
        let pick = store
            .stalest_evictable_device(profile_id, registering)
            .await
            .unwrap();
        assert_eq!(
            pick.as_deref(),
            Some("D_META_B"),
            "device with the oldest recorded activity must be chosen"
        );
    }

    #[tokio::test]
    async fn cleanup_expired_inactive_profile_removes_profile_and_devices() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("keys.db");
        let store = KeysStore::open(&path).await.unwrap();

        let profile_id = "P3";
        store.insert_profile(profile_id, 1_000, None).await.unwrap();

        let reg_ok = store
            .register_device(profile_id, "D3", Some("ik3"), 1_100)
            .await
            .unwrap();
        assert!(reg_ok);

        let published = store
            .publish_key_bundle(
                profile_id,
                "D3",
                "ik3",
                "spk3",
                "spk_sig3",
                vec![OneTimePrekey {
                    prekey_id: 1,
                    prekey_pub_b64: "otk3".into(),
                }],
                1_200,
                None,
                None,
            )
            .await
            .unwrap();
        assert!(published);

        let set_ok = store
            .profile_inactivity_set(profile_id, Some(1), 1_300)
            .await
            .unwrap();
        assert!(set_ok);

        let deleted = store
            .delete_expired_inactive_profiles(1_300 + 30 * 24 * 60 * 60 * 1000 + 1)
            .await
            .unwrap();
        assert_eq!(deleted, vec![profile_id.to_string()]);
        assert!(!store.profile_exists(profile_id).await.unwrap());
        assert!(store.profile_id_for_device("D3").await.unwrap().is_none());
        assert!(
            store
                .fetch_bundles_for_profile(profile_id)
                .await
                .unwrap()
                .is_empty()
        );
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OneTimePrekey {
    pub prekey_id: i64,
    pub prekey_pub_b64: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceKeyBundle {
    pub device_id: String,
    pub identity_key_pub_b64: String,
    pub signed_prekey_pub_b64: String,
    pub signed_prekey_sig_b64: String,
    pub one_time_prekey: Option<OneTimePrekey>,
    /// Account identity of the device's owner, and this device's certificate
    /// signed by it (2026-08-08). `None` for anything published by a build from
    /// before this landed.
    ///
    /// 🔴 Omitted from the JSON when absent, so the wire stays byte-identical
    /// for old publishers — a client that never sent these must not start seeing
    /// nulls appear in its bundle responses.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub account_identity_pub_b64: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_cert_b64: Option<String>,
}

#[derive(Debug, Clone)]
pub struct DeviceStatusRow {
    pub device_id: String,
    pub has_bundle: bool,
    pub identity_key_pub_b64: Option<String>,
    pub signed_prekey_pub_b64: Option<String>,
    pub signed_prekey_sig_b64: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProfileSearchHit {
    pub profile_id: String,
    pub nickname: Option<String>,
    pub updated_at_ms: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProfileInactivityStatus {
    pub delete_after_inactivity_months: Option<i64>,
    pub last_active_at_ms: i64,
    /// Last EXPLICIT presence heartbeat (0 = never). Drives the online dot;
    /// `last_active_at_ms` drives the inactive-account deletion sweep.
    pub last_presence_at_ms: i64,
}

/// Monetization entitlement row (TZ-MONETIZE-01 §S-1). Anonymity rule (§0.2):
/// only `store_tx_id` (an opaque transaction pseudonym) and `profile_id` are
/// stored — never anything personally identifying extracted from receipts.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EntitlementRecord {
    pub profile_id: String,
    /// free|premium|lifetime|legacy|team
    pub tier: String,
    /// appstore|play|stripe|legacy|none
    pub source: String,
    /// Opaque store transaction id; UNIQUE so one receipt maps to one profile.
    pub store_tx_id: Option<String>,
    pub expires_at_ms: Option<i64>,
    pub grace_until_ms: Option<i64>,
    pub updated_at_ms: i64,
}

/// 🔴 Возраст профиля, в котором перенос подписки — ход свежей установки, а не
/// решение человека (25.09.2026).
///
/// Телефон заводит серверный профиль при первом запуске, ещё до выбора
/// «восстановить / создать», и в ту же секунду молча предъявляет чек магазина.
/// Если такой перенос взводит защиту от перекидывания, настоящий профиль,
/// восстановленный через минуту, сутки остаётся без подписки: так было у двух
/// человек — 24.09 (профиль-однодневка прожил на сервере одну секунду) и 20.09
/// (33 часа без премиума).
pub const RECEIPT_CLAIM_FRESH_PROFILE_MS: i64 = 10 * 60 * 1000;

/// Outcome of [`KeysStore::entitlement_claim_by_receipt`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReceiptClaim {
    /// Moved; the anti-flap window now runs from this move.
    Moved,
    /// Moved into a profile created minutes ago — the automatic claim of a
    /// fresh install. The window is NOT armed, so the profile restored right
    /// after it takes the purchase back at once.
    MovedToFreshProfile,
    /// Blocked by the anti-flap window, or the target profile is unknown.
    Refused,
}

impl ReceiptClaim {
    pub fn moved(self) -> bool {
        !matches!(self, ReceiptClaim::Refused)
    }
}

/// Outcome of [`KeysStore::entitlement_rebind`].
pub enum EntitlementRebind {
    /// The entitlement was moved; carries the row under its new `profile_id`.
    Moved(EntitlementRecord),
    /// The source profile had no entitlement to move.
    NoSource,
    /// The target `profile_id` does not exist in `profiles`.
    UnknownTarget,
}

/// Момент, до которого профиль заперт после `attempts` неудач подряд.
///
/// SEC-01, Э-2. Первые девять попыток бесплатны — человек мог ошибиться в
/// пароле. С десятой задержка удваивается от минуты и упирается в сутки.
///
/// 🔴 Вынесено отдельной функцией НАМЕРЕННО: это единственная арифметика во
/// всём этапе, и проверять её через переменные окружения и живую базу значило
/// бы не проверять вовсе.
pub fn backup_access_lock_deadline_ms(attempts: i64, now_ms: i64) -> i64 {
    const FREE_ATTEMPTS: i64 = 10;
    const BASE_DELAY_MS: i64 = 60_000;
    const MAX_DELAY_MS: i64 = 24 * 60 * 60 * 1000;
    if attempts < FREE_ATTEMPTS {
        return 0;
    }
    let steps = (attempts - FREE_ATTEMPTS).min(40) as u32;
    let delay = BASE_DELAY_MS.saturating_mul(1i64.checked_shl(steps).unwrap_or(i64::MAX));
    now_ms + delay.clamp(BASE_DELAY_MS, MAX_DELAY_MS)
}

impl KeysStore {
    pub async fn open(path: impl AsRef<Path>) -> Result<Self, String> {
        let conn = Connection::open(path).await.map_err(|e| e.to_string())?;
        let store = Self {
            conn,
            device_liveness_window_ms: device_liveness_window_ms_from_env(),
        };
        store.init().await?;
        Ok(store)
    }

    async fn init(&self) -> Result<(), String> {
        self.conn
            .call(|c| -> Result<(), rusqlite::Error> {
                c.execute_batch(
                    r#"
CREATE TABLE IF NOT EXISTS profiles (
  profile_id TEXT PRIMARY KEY,
  created_at_ms INTEGER NOT NULL,
  -- Stores sha256(profile_secret_bytes) as base64.
    profile_secret_sha256_b64 TEXT,
    inactive_delete_after_months INTEGER,
    last_active_at_ms INTEGER NOT NULL DEFAULT 0,
    -- PRESENCE, not account liveness. `last_active_at_ms` is bumped by any
    -- device touch (publishing keys on launch, registering, backups) because
    -- its job is "this account is not abandoned" for the deletion sweep. That
    -- is the wrong signal for the online dot: a push that merely WAKES a
    -- peer's phone makes it republish keys, which lit them up as «Онлайн»
    -- while nobody touched the device (2026-07-21 report, reproduced on a
    -- Pixel where FCM wakes reliably). This column is written ONLY by the
    -- explicit presence heartbeat the app sends while a human has it open.
    last_presence_at_ms INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS profile_meta (
  profile_id TEXT PRIMARY KEY,
  nickname TEXT,
  avatar_png_b64 TEXT,
    bio TEXT,
    privacy_audience_json TEXT,
    searchable_by_nickname INTEGER NOT NULL DEFAULT 1,
    frame_id TEXT,
    cover_id TEXT,
    cover_png_b64 TEXT,
    emoji_status TEXT,
    premium_badge TEXT,
  updated_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS devices (
  device_id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  identity_key_pub_b64 TEXT
);

CREATE INDEX IF NOT EXISTS devices_profile_idx ON devices(profile_id);

CREATE TABLE IF NOT EXISTS device_metadata (
    device_id TEXT PRIMARY KEY,
    profile_id TEXT NOT NULL,
    device_class TEXT NOT NULL DEFAULT 'mobile',
    device_label TEXT,
    updated_at_ms INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS device_metadata_profile_class_idx ON device_metadata(profile_id, device_class);

CREATE TABLE IF NOT EXISTS profile_companion_entitlements (
    profile_id TEXT PRIMARY KEY,
    desktop_companion_limit INTEGER NOT NULL DEFAULT 0,
    updated_at_ms INTEGER NOT NULL DEFAULT 0,
    source TEXT
);

CREATE TABLE IF NOT EXISTS device_key_bundles (
  device_id TEXT PRIMARY KEY,
  profile_id TEXT NOT NULL,
  identity_key_pub_b64 TEXT NOT NULL,
  signed_prekey_pub_b64 TEXT NOT NULL,
  signed_prekey_sig_b64 TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  -- Account identity (2026-08-08): one safety number per PERSON instead of one
  -- per device. NULLABLE on purpose — a client built before this ships neither,
  -- and requiring them would kill delivery to every existing install.
  --
  -- The account key is duplicated onto each device row DELIBERATELY: the
  -- certificate and the key that signed it then travel together, so a receiver
  -- verifies them as a pair without cross-referencing another row. A device on
  -- an old build has neither, which correctly reads as "no certificate".
  account_identity_pub_b64 TEXT,
  device_cert_b64 TEXT
);

CREATE INDEX IF NOT EXISTS device_key_bundles_profile_idx ON device_key_bundles(profile_id);

CREATE TABLE IF NOT EXISTS one_time_prekeys (
  device_id TEXT NOT NULL,
  prekey_id INTEGER NOT NULL,
  prekey_pub_b64 TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY(device_id, prekey_id)
);

CREATE INDEX IF NOT EXISTS one_time_prekeys_device_created_idx ON one_time_prekeys(device_id, created_at_ms);

CREATE TABLE IF NOT EXISTS profile_backups (
    profile_id TEXT PRIMARY KEY,
    payload TEXT NOT NULL,
    payload_sha256_b64 TEXT NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    -- Э-0 (25.08.2026): опора для токена доступа к архиву (SEC-01).
    -- Соль публична, проверочное значение выводится из пароля владельца.
    -- Пока НЕ используются для решения о выдаче — этап Э-0 только готовит
    -- место и делает происходящее видимым.
    access_salt_b64 TEXT,
    access_verifier_b64 TEXT,
    -- Счётчик неудачных предъявлений токена и время, до которого профиль
    -- закрыт. Ограничение считается ПО ПРОФИЛЮ: лимит по адресу обходится
    -- сменой адреса и подбор просто переезжает в онлайн.
    failed_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until_ms INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS entitlements (
    profile_id TEXT PRIMARY KEY,
    tier TEXT NOT NULL DEFAULT 'free',
    source TEXT NOT NULL DEFAULT 'none',
    store_tx_id TEXT,
    expires_at_ms INTEGER,
    grace_until_ms INTEGER,
    updated_at_ms INTEGER NOT NULL DEFAULT 0,
    migrated_at_ms INTEGER NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS entitlements_store_tx_idx
  ON entitlements(store_tx_id) WHERE store_tx_id IS NOT NULL;
"#,
                )?;

                // Best-effort migrations for existing DBs.
                let _ = c.execute(
                    "ALTER TABLE profiles ADD COLUMN profile_secret_sha256_b64 TEXT",
                    [],
                );
                let _ = c.execute(
                    "ALTER TABLE profiles ADD COLUMN inactive_delete_after_months INTEGER",
                    [],
                );
                let _ = c.execute(
                    "ALTER TABLE profiles ADD COLUMN last_active_at_ms INTEGER NOT NULL DEFAULT 0",
                    [],
                );
                let _ = c.execute(
                    "UPDATE profiles SET last_active_at_ms = created_at_ms WHERE last_active_at_ms IS NULL OR last_active_at_ms <= 0",
                    [],
                );
                // Deliberately NOT backfilled from last_active_at_ms: that
                // value is exactly the lie we are removing. Unknown presence
                // reads as offline until the owner's next heartbeat, which an
                // app in the foreground sends within ~45 s.
                let _ = c.execute(
                    "ALTER TABLE profiles ADD COLUMN last_presence_at_ms INTEGER NOT NULL DEFAULT 0",
                    [],
                );
                // When a receipt moves to the profile that presents it, stamp
                // the move. Without a field of its own the anti-flap check
                // would have to read updated_at_ms, which store webhooks bump
                // for their own reasons — a renewal arriving seconds before a
                // reinstall would then block the very migration it should allow.
                let _ = c.execute(
                    "ALTER TABLE entitlements ADD COLUMN migrated_at_ms INTEGER NOT NULL DEFAULT 0",
                    [],
                );
                let _ = c.execute(
                    "ALTER TABLE devices ADD COLUMN identity_key_pub_b64 TEXT",
                    [],
                );
                // 🔴 Account identity (2026-08-08) — added in BOTH places, the
                // base CREATE above and here. The schema has two creation paths:
                // a fresh database gets the column from CREATE, an existing one
                // only from this ALTER. Touching one of them leaves half the
                // installs without the column (the Wave-2 scar, 07-06).
                let _ = c.execute(
                    "ALTER TABLE device_key_bundles ADD COLUMN account_identity_pub_b64 TEXT",
                    [],
                );
                let _ = c.execute(
                    "ALTER TABLE device_key_bundles ADD COLUMN device_cert_b64 TEXT",
                    [],
                );
                let _ = c.execute(
                    "ALTER TABLE profile_backups ADD COLUMN payload_sha256_b64 TEXT",
                    [],
                );
                // Э-0 (25.08.2026), SEC-01. Обе половины схемы правятся вместе:
                // свежая база берёт колонки из CREATE выше, существующая —
                // только отсюда. Правка одной половины оставляет часть
                // установок без колонок (шрам Wave-2, 06.07).
                let _ = c.execute(
                    "ALTER TABLE profile_backups ADD COLUMN access_salt_b64 TEXT",
                    [],
                );
                let _ = c.execute(
                    "ALTER TABLE profile_backups ADD COLUMN access_verifier_b64 TEXT",
                    [],
                );
                let _ = c.execute(
                    "ALTER TABLE profile_backups ADD COLUMN failed_attempts INTEGER NOT NULL DEFAULT 0",
                    [],
                );
                let _ = c.execute(
                    "ALTER TABLE profile_backups ADD COLUMN locked_until_ms INTEGER NOT NULL DEFAULT 0",
                    [],
                );
                let _ = c.execute(
                    "ALTER TABLE profile_meta ADD COLUMN searchable_by_nickname INTEGER NOT NULL DEFAULT 1",
                    [],
                );
                let _ = c.execute("ALTER TABLE profile_meta ADD COLUMN bio TEXT", []);
                let _ = c.execute(
                    "ALTER TABLE profile_meta ADD COLUMN privacy_audience_json TEXT",
                    [],
                );
                let _ = c.execute("ALTER TABLE profile_meta ADD COLUMN frame_id TEXT", []);
                let _ = c.execute("ALTER TABLE profile_meta ADD COLUMN cover_id TEXT", []);
                let _ =
                    c.execute("ALTER TABLE profile_meta ADD COLUMN cover_png_b64 TEXT", []);
                let _ =
                    c.execute("ALTER TABLE profile_meta ADD COLUMN emoji_status TEXT", []);
                let _ =
                    c.execute("ALTER TABLE profile_meta ADD COLUMN premium_badge TEXT", []);
                let _ = c.execute(
                    "ALTER TABLE device_metadata ADD COLUMN device_label TEXT",
                    [],
                );
                let _ = c.execute(
                    r#"
INSERT INTO device_metadata(device_id, profile_id, device_class, updated_at_ms)
SELECT d.device_id, d.profile_id, 'mobile', d.created_at_ms
FROM devices d
WHERE NOT EXISTS (
  SELECT 1 FROM device_metadata m WHERE m.device_id = d.device_id
)
"#,
                    [],
                );
                // FIX-SERVER-1 (zombie devices): per-device liveness signal.
                // Device discovery (list_devices / fetch_bundle) returned EVERY
                // device_id a profile ever had, with no liveness filter, so a
                // rotated/abandoned device_id stayed discoverable forever and
                // peers kept fanning messages + routing calls to a dead mailbox.
                // `last_seen_ms` is stamped on register/publish/heartbeat and is
                // the basis for the discovery filter + liveness-ranked eviction.
                let _ = c.execute(
                    "ALTER TABLE devices ADD COLUMN last_seen_ms INTEGER NOT NULL DEFAULT 0",
                    [],
                );
                let _ = c.execute(
                    "CREATE INDEX IF NOT EXISTS devices_profile_lastseen_idx ON devices(profile_id, last_seen_ms)",
                    [],
                );
                // Backfill existing devices to "seen now" so NONE are hidden the
                // moment this deploys — every device gets a full TTL grace
                // window from deploy time. Live devices keep re-stamping; only a
                // device that never checks in again ages out and drops from
                // discovery. (SQLite clock so the migration stays self-contained.)
                let _ = c.execute(
                    "UPDATE devices SET last_seen_ms = CAST(strftime('%s','now') AS INTEGER) * 1000 WHERE last_seen_ms = 0",
                    [],
                );
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub async fn backup_set(
        &self,
        profile_id: &str,
        payload: &str,
        payload_sha256_b64: &str,
        now_ms: i64,
    ) -> Result<bool, String> {
        let pid = profile_id.to_string();
        let pl = payload.to_string();
        let sh = payload_sha256_b64.to_string();
        let ok = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let changed = c.execute(
                    r#"
INSERT INTO profile_backups(profile_id, payload, payload_sha256_b64, updated_at_ms)
VALUES(?1, ?2, ?3, ?4)
ON CONFLICT(profile_id) DO UPDATE SET
  payload=excluded.payload,
  payload_sha256_b64=excluded.payload_sha256_b64,
  updated_at_ms=excluded.updated_at_ms
"#,
                    params![pid, pl, sh, now_ms],
                )?;
                Ok(changed > 0)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(ok)
    }

    pub async fn backup_get(
        &self,
        profile_id: &str,
    ) -> Result<Option<(String, String, i64)>, String> {
        let pid = profile_id.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<Option<(String, String, i64)>, rusqlite::Error> {
                let row: Option<(String, String, i64)> = c
                    .query_row(
                        "SELECT payload, payload_sha256_b64, updated_at_ms FROM profile_backups WHERE profile_id = ?1",
                        params![pid],
                        |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
                    )
                    .optional()?;
                Ok(row)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    /// Э-1 (SEC-01): записать опору токена доступа ВМЕСТЕ с архивом.
    ///
    /// 🔴 Отдельной записи проверочного значения быть не должно. Смена пароля
    /// в настройках НЕ перезаливает архив, поэтому обновлённое проверочное
    /// значение при старом содержимом даёт худший исход: владелец пройдёт
    /// проверку доступа новым паролем, скачает архив и не сможет его
    /// расшифровать — отказ случится ПОСЛЕ успешной проверки и будет выглядеть
    /// как порча архива.
    pub async fn backup_access_set(
        &self,
        profile_id: &str,
        access_salt_b64: &str,
        access_verifier_b64: &str,
    ) -> Result<(), String> {
        let pid = profile_id.to_string();
        let salt = access_salt_b64.to_string();
        let ver = access_verifier_b64.to_string();
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "UPDATE profile_backups SET access_salt_b64 = ?2, access_verifier_b64 = ?3,                      failed_attempts = 0, locked_until_ms = 0 WHERE profile_id = ?1",
                    params![pid, salt, ver],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())
    }

    /// Соль и проверочное значение профиля. `None` — опоры нет: профиль ещё не
    /// пересохранял архив новым клиентом, значит обслуживается прежним путём.
    pub async fn backup_access_get(
        &self,
        profile_id: &str,
    ) -> Result<Option<(Option<String>, Option<String>)>, String> {
        let pid = profile_id.to_string();
        self.conn
            .call(
                move |c| -> Result<Option<(Option<String>, Option<String>)>, rusqlite::Error> {
                    c.query_row(
                        "SELECT access_salt_b64, access_verifier_b64 FROM profile_backups                          WHERE profile_id = ?1",
                        params![pid],
                        |r| Ok((r.get(0)?, r.get(1)?)),
                    )
                    .optional()
                },
            )
            .await
            .map_err(|e| e.to_string())
    }

    /// До какого момента профиль заперт после неудачных попыток токена.
    ///
    /// SEC-01, Э-2. Лимит по IP обходится сменой адреса, поэтому счёт ведётся
    /// ПО ПРОФИЛЮ: подбор токена — это подбор пароля архива, и он должен
    /// упираться в стену независимо от того, откуда идут запросы.
    pub async fn backup_access_lock_until_ms(&self, profile_id: &str) -> Result<i64, String> {
        let pid = profile_id.to_string();
        self.conn
            .call(move |c| -> Result<i64, rusqlite::Error> {
                c.query_row(
                    "SELECT locked_until_ms FROM profile_backups WHERE profile_id = ?1",
                    params![pid],
                    |r| r.get(0),
                )
                .optional()
                .map(|v| v.unwrap_or(0))
            })
            .await
            .map_err(|e| e.to_string())
    }

    /// Отмечает неудачную попытку и возвращает новое число неудач подряд.
    ///
    /// Запирание начинается с десятой и удваивается, упираясь в сутки. Успех
    /// сбрасывает счёт (см. [`backup_access_note_success`]), как и сохранение
    /// нового архива — владелец, поменявший пароль, не должен ждать.
    pub async fn backup_access_note_failure(
        &self,
        profile_id: &str,
        now_ms: i64,
    ) -> Result<i64, String> {
        let pid = profile_id.to_string();
        self.conn
            .call(move |c| -> Result<i64, rusqlite::Error> {
                let attempts: i64 = c
                    .query_row(
                        "SELECT failed_attempts FROM profile_backups WHERE profile_id = ?1",
                        params![&pid],
                        |r| r.get(0),
                    )
                    .optional()?
                    .unwrap_or(0)
                    + 1;
                let lock_ms = backup_access_lock_deadline_ms(attempts, now_ms);
                c.execute(
                    "UPDATE profile_backups SET failed_attempts = ?2, locked_until_ms = ?3 \
                     WHERE profile_id = ?1",
                    params![&pid, attempts, lock_ms],
                )?;
                Ok(attempts)
            })
            .await
            .map_err(|e| e.to_string())
    }

    /// Сбрасывает счёт неудач после верного токена.
    pub async fn backup_access_note_success(&self, profile_id: &str) -> Result<(), String> {
        let pid = profile_id.to_string();
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "UPDATE profile_backups SET failed_attempts = 0, locked_until_ms = 0 \
                     WHERE profile_id = ?1",
                    params![pid],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn profile_secret_sha256_b64(
        &self,
        profile_id: &str,
    ) -> Result<Option<String>, String> {
        let pid = profile_id.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<Option<String>, rusqlite::Error> {
                let v: Option<String> = c
                    .query_row(
                        "SELECT profile_secret_sha256_b64 FROM profiles WHERE profile_id = ?1",
                        params![pid],
                        |row| row.get(0),
                    )
                    .optional()?;
                Ok(v)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    pub async fn profile_meta_get(
        &self,
        profile_id: &str,
    ) -> Result<
        Option<(
            Option<String>,
            Option<String>,
            Option<String>,
            Option<String>,
            bool,
            Option<String>,
            Option<String>,
            Option<String>,
            Option<String>,
            Option<String>,
            i64,
        )>,
        String,
    > {
        let pid = profile_id.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<Option<(Option<String>, Option<String>, Option<String>, Option<String>, bool, Option<String>, Option<String>, Option<String>, Option<String>, Option<String>, i64)>, rusqlite::Error> {
                let row: Option<(Option<String>, Option<String>, Option<String>, Option<String>, bool, Option<String>, Option<String>, Option<String>, Option<String>, Option<String>, i64)> = c
                    .query_row(
                        "SELECT nickname, avatar_png_b64, bio, privacy_audience_json, searchable_by_nickname, frame_id, cover_id, cover_png_b64, emoji_status, premium_badge, updated_at_ms FROM profile_meta WHERE profile_id = ?1",
                        params![pid],
                        |r| {
                            let searchable_i: i64 = r.get(4)?;
                            Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, searchable_i != 0, r.get(5)?, r.get(6)?, r.get(7)?, r.get(8)?, r.get(9)?, r.get(10)?))
                        },
                    )
                    .optional()?;
                Ok(row)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    pub async fn profile_meta_set(
        &self,
        profile_id: &str,
        nickname: Option<&str>,
        avatar_png_b64: Option<&str>,
        bio: Option<&str>,
        privacy_audience_json: Option<&str>,
        searchable_by_nickname: bool,
        frame_id: Option<&str>,
        cover_id: Option<&str>,
        cover_png_b64: Option<&str>,
        emoji_status: Option<&str>,
        premium_badge: Option<&str>,
        now_ms: i64,
    ) -> Result<bool, String> {
        let pid = profile_id.to_string();
        let nick = nickname.map(|s| s.to_string());
        let avatar = avatar_png_b64.map(|s| s.to_string());
        let bio_value = bio.map(|s| s.to_string());
        let privacy_value = privacy_audience_json.map(|s| s.to_string());
        let frame_value = frame_id.map(|s| s.to_string());
        let cover_value = cover_id.map(|s| s.to_string());
        let cover_png_value = cover_png_b64.map(|s| s.to_string());
        let emoji_value = emoji_status.map(|s| s.to_string());
        let badge_value = premium_badge.map(|s| s.to_string());
        let searchable = if searchable_by_nickname { 1i64 } else { 0i64 };

        let ok = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let exists: i64 = c.query_row(
                    "SELECT EXISTS(SELECT 1 FROM profiles WHERE profile_id = ?1)",
                    params![pid.clone()],
                    |r| r.get(0),
                )?;
                if exists == 0 {
                    return Ok(false);
                }

                c.execute(
                    "INSERT INTO profile_meta(profile_id, nickname, avatar_png_b64, bio, privacy_audience_json, searchable_by_nickname, frame_id, cover_id, cover_png_b64, emoji_status, premium_badge, updated_at_ms) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
                     ON CONFLICT(profile_id) DO UPDATE SET
                       -- COALESCE, not plain assignment: a client that sends
                       -- no nickname means it has no opinion, and this used to
                       -- read that as make it blank. One publish with an empty
                       -- local value therefore erased the name and photo every
                       -- contact sees. Absent now preserves; an explicit empty
                       -- string still clears.
                       nickname=COALESCE(excluded.nickname, profile_meta.nickname),
                       avatar_png_b64=COALESCE(excluded.avatar_png_b64, profile_meta.avatar_png_b64),
                       bio=COALESCE(excluded.bio, profile_meta.bio),
                       privacy_audience_json=excluded.privacy_audience_json,
                       searchable_by_nickname=excluded.searchable_by_nickname,
                       frame_id=excluded.frame_id,
                       cover_id=excluded.cover_id,
                       cover_png_b64=COALESCE(excluded.cover_png_b64, profile_meta.cover_png_b64),
                       emoji_status=excluded.emoji_status,
                       premium_badge=excluded.premium_badge,
                       updated_at_ms=excluded.updated_at_ms",
                    params![pid, nick, avatar, bio_value, privacy_value, searchable, frame_value, cover_value, cover_png_value, emoji_value, badge_value, now_ms],
                )?;
                Ok(true)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(ok)
    }

    pub async fn search_profiles_by_nickname(
        &self,
        query: &str,
        limit: usize,
    ) -> Result<Vec<ProfileSearchHit>, String> {
        let q = query.trim().to_string();
        if q.is_empty() {
            return Ok(Vec::new());
        }
        let lim = limit.clamp(1, 50) as i64;
        let out = self
            .conn
            .call(move |c| -> Result<Vec<ProfileSearchHit>, rusqlite::Error> {
                let mut stmt = c.prepare(
                    "SELECT profile_id, nickname, updated_at_ms
                     FROM profile_meta
                     WHERE nickname IS NOT NULL
                       AND TRIM(nickname) <> ''
                                             AND searchable_by_nickname = 1
                       AND INSTR(LOWER(nickname), LOWER(?1)) > 0
                     ORDER BY CASE WHEN INSTR(LOWER(nickname), LOWER(?1)) = 1 THEN 0 ELSE 1 END,
                              updated_at_ms DESC
                     LIMIT ?2",
                )?;
                let mut rows = stmt.query(params![q, lim])?;
                let mut res = Vec::new();
                while let Some(row) = rows.next()? {
                    res.push(ProfileSearchHit {
                        profile_id: row.get(0)?,
                        nickname: row.get(1)?,
                        updated_at_ms: row.get(2)?,
                    });
                }
                Ok(res)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    pub async fn insert_profile(
        &self,
        profile_id: &str,
        created_at_ms: i64,
        profile_secret_sha256_b64: Option<&str>,
    ) -> Result<(), String> {
        let pid = profile_id.to_string();
        let sec = profile_secret_sha256_b64.map(|s| s.to_string());
        self.conn
            .call(move |c| -> Result<(), rusqlite::Error> {
                c.execute(
                    "INSERT INTO profiles(profile_id, created_at_ms, profile_secret_sha256_b64, inactive_delete_after_months, last_active_at_ms) VALUES(?1, ?2, ?3, NULL, ?2)",
                    params![pid, created_at_ms, sec],
                )?;
                Ok(())
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub async fn profile_exists(&self, profile_id: &str) -> Result<bool, String> {
        let pid = profile_id.to_string();
        let v = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let exists: i64 = c.query_row(
                    "SELECT EXISTS(SELECT 1 FROM profiles WHERE profile_id = ?1)",
                    params![pid],
                    |row| row.get(0),
                )?;
                Ok(exists != 0)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(v)
    }

    pub async fn profile_inactivity_get(
        &self,
        profile_id: &str,
    ) -> Result<Option<ProfileInactivityStatus>, String> {
        let pid = profile_id.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<Option<ProfileInactivityStatus>, rusqlite::Error> {
                let row: Option<ProfileInactivityStatus> = c
                    .query_row(
                        "SELECT inactive_delete_after_months, CASE WHEN last_active_at_ms IS NULL OR last_active_at_ms <= 0 THEN created_at_ms ELSE last_active_at_ms END, COALESCE(last_presence_at_ms, 0) FROM profiles WHERE profile_id = ?1",
                        params![pid],
                        |r| {
                            Ok(ProfileInactivityStatus {
                                delete_after_inactivity_months: r.get(0)?,
                                last_active_at_ms: r.get(1)?,
                                last_presence_at_ms: r.get(2)?,
                            })
                        },
                    )
                    .optional()?;
                Ok(row)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    pub async fn profile_inactivity_set(
        &self,
        profile_id: &str,
        delete_after_inactivity_months: Option<i64>,
        now_ms: i64,
    ) -> Result<bool, String> {
        let pid = profile_id.to_string();
        let ok = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let changed = c.execute(
                    "UPDATE profiles SET inactive_delete_after_months = ?2, last_active_at_ms = ?3 WHERE profile_id = ?1",
                    params![pid, delete_after_inactivity_months, now_ms],
                )?;
                Ok(changed > 0)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(ok)
    }

    /// Records a HUMAN presence heartbeat. Called from exactly one place — the
    /// presence heartbeat endpoint — unlike `mark_profile_active`, which every
    /// device touch legitimately bumps for the deletion sweep.
    pub async fn mark_profile_present(&self, profile_id: &str, now_ms: i64) -> Result<bool, String> {
        let pid = profile_id.to_string();
        let ok = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let changed = c.execute(
                    "UPDATE profiles SET last_presence_at_ms = ?2 WHERE profile_id = ?1",
                    params![pid, now_ms],
                )?;
                Ok(changed > 0)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(ok)
    }

    pub async fn mark_profile_active(&self, profile_id: &str, now_ms: i64) -> Result<bool, String> {
        let pid = profile_id.to_string();
        let ok = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let changed = c.execute(
                    "UPDATE profiles SET last_active_at_ms = ?2 WHERE profile_id = ?1",
                    params![pid, now_ms],
                )?;
                Ok(changed > 0)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(ok)
    }

    pub async fn delete_expired_inactive_profiles(
        &self,
        now_ms: i64,
    ) -> Result<Vec<String>, String> {
        let deleted = self
            .conn
            .call(move |c| -> Result<Vec<String>, rusqlite::Error> {
                let mut stmt = c.prepare(
                    "SELECT profile_id, inactive_delete_after_months, CASE WHEN last_active_at_ms IS NULL OR last_active_at_ms <= 0 THEN created_at_ms ELSE last_active_at_ms END FROM profiles WHERE inactive_delete_after_months IS NOT NULL AND inactive_delete_after_months > 0",
                )?;
                let mut rows = stmt.query([])?;
                let mut expired_profile_ids = Vec::new();
                while let Some(row) = rows.next()? {
                    let profile_id: String = row.get(0)?;
                    let delete_after_months: i64 = row.get(1)?;
                    let last_active_at_ms: i64 = row.get(2)?;
                    let retention_ms = delete_after_months * 30 * 24 * 60 * 60 * 1000;
                    if now_ms.saturating_sub(last_active_at_ms) >= retention_ms {
                        expired_profile_ids.push(profile_id);
                    }
                }
                drop(rows);
                drop(stmt);

                if expired_profile_ids.is_empty() {
                    return Ok(Vec::new());
                }

                let tx = c.transaction()?;
                for profile_id in &expired_profile_ids {
                    tx.execute(
                        "DELETE FROM one_time_prekeys WHERE device_id IN (SELECT device_id FROM devices WHERE profile_id = ?1)",
                        params![profile_id],
                    )?;
                    tx.execute(
                        "DELETE FROM device_key_bundles WHERE profile_id = ?1",
                        params![profile_id],
                    )?;
                    tx.execute(
                        "DELETE FROM devices WHERE profile_id = ?1",
                        params![profile_id],
                    )?;
                    tx.execute(
                        "DELETE FROM profile_meta WHERE profile_id = ?1",
                        params![profile_id],
                    )?;
                    tx.execute(
                        "DELETE FROM profile_backups WHERE profile_id = ?1",
                        params![profile_id],
                    )?;
                    tx.execute(
                        "DELETE FROM device_metadata WHERE profile_id = ?1",
                        params![profile_id],
                    )?;
                    tx.execute(
                        "DELETE FROM profile_companion_entitlements WHERE profile_id = ?1",
                        params![profile_id],
                    )?;
                    tx.execute(
                        "DELETE FROM profiles WHERE profile_id = ?1",
                        params![profile_id],
                    )?;
                }
                tx.commit()?;
                Ok(expired_profile_ids)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(deleted)
    }

    pub async fn register_device(
        &self,
        profile_id: &str,
        device_id: &str,
        identity_key_pub_b64: Option<&str>,
        created_at_ms: i64,
    ) -> Result<bool, String> {
        let pid = profile_id.to_string();
        let did = device_id.to_string();
        let ik = identity_key_pub_b64.map(|s| s.to_string());

        let ok = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let exists: i64 = c.query_row(
                    "SELECT EXISTS(SELECT 1 FROM profiles WHERE profile_id = ?1)",
                    params![pid.clone()],
                    |row| row.get(0),
                )?;
                if exists == 0 {
                    return Ok(false);
                }

                // Idempotent: if this (device_id, profile_id) pair is already registered,
                // ensure the identity key binding cannot be silently changed.
                // Scoped to the same profile: a device switching profiles (cross-profile
                // migration) has been evicted beforehand by register_device_proof, so no
                // stale key from another profile blocks re-registration here.
                let existing_ik: Option<String> = c
                    .query_row(
                        "SELECT identity_key_pub_b64 FROM devices WHERE device_id = ?1 AND profile_id = ?2",
                        params![did.clone(), pid.clone()],
                        |row| row.get(0),
                    )
                    .optional()?;

                if let (Some(existing), Some(ref new_ik)) = (existing_ik, ik.as_ref()) {
                    if !existing.is_empty() && existing != new_ik.as_str() {
                        return Ok(false);
                    }
                }

                c.execute(
                    "INSERT OR IGNORE INTO devices(device_id, profile_id, created_at_ms, identity_key_pub_b64, last_seen_ms) VALUES(?1, ?2, ?3, ?4, ?3)",
                    params![did.clone(), pid.clone(), created_at_ms, ik.clone()],
                )?;

                // If the row exists but identity key is not set yet, set it.
                if let Some(ref new_ik) = ik {
                    let _ = c.execute(
                        "UPDATE devices SET identity_key_pub_b64 = ?2 WHERE device_id = ?1 AND (identity_key_pub_b64 IS NULL OR identity_key_pub_b64 = '')",
                        params![did.clone(), new_ik],
                    )?;
                }

                // FIX-SERVER-1: stamp last_seen on EVERY (re-)registration — the
                // client re-registers on each launch, so this is the primary
                // liveness heartbeat that keeps a live device discoverable and
                // lets a quiet/abandoned (zombie) device age out of discovery.
                // Monotonic guard so an out-of-order/replayed call can't rewind it.
                let _ = c.execute(
                    "UPDATE devices SET last_seen_ms = ?2 WHERE device_id = ?1 AND last_seen_ms < ?2",
                    params![did.clone(), created_at_ms],
                )?;

                Ok(true)
            })
            .await
            .map_err(|e| e.to_string())?;

        Ok(ok)
    }

    pub async fn upsert_device_metadata(
        &self,
        profile_id: &str,
        device_id: &str,
        device_class: &str,
        device_label: Option<&str>,
        updated_at_ms: i64,
    ) -> Result<bool, String> {
        let pid = profile_id.to_string();
        let did = device_id.to_string();
        let dclass = device_class.to_string();
        let dlabel = device_label.map(|value| value.to_string());

        let ok = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let exists: i64 = c.query_row(
                    "SELECT EXISTS(SELECT 1 FROM devices WHERE device_id = ?1 AND profile_id = ?2)",
                    params![did.clone(), pid.clone()],
                    |row| row.get(0),
                )?;
                if exists == 0 {
                    return Ok(false);
                }

                let changed = c.execute(
                    r#"
INSERT INTO device_metadata(device_id, profile_id, device_class, device_label, updated_at_ms)
VALUES(?1, ?2, ?3, ?4, ?5)
ON CONFLICT(device_id) DO UPDATE SET
  profile_id = excluded.profile_id,
  device_class = excluded.device_class,
  device_label = excluded.device_label,
  updated_at_ms = excluded.updated_at_ms
"#,
                    params![did, pid, dclass, dlabel, updated_at_ms],
                )?;

                Ok(changed > 0)
            })
            .await
            .map_err(|e| e.to_string())?;

        Ok(ok)
    }

    pub async fn list_devices(&self, profile_id: &str) -> Result<Vec<String>, String> {
        let pid = profile_id.to_string();
        let window_ms = self.device_liveness_window_ms;
        let out = self
            .conn
            .call(move |c| -> Result<Vec<String>, rusqlite::Error> {
                // FIX-SERVER-1 (zombie devices): only advertise LIVE devices.
                // Liveness is RELATIVE to the profile's own freshest activity —
                // a device is live if its last_seen is within the liveness
                // window of the newest device's last_seen. This self-calibrates
                // (no wall-clock dependency) and the freshest device always
                // passes (>= MAX - window), upholding the "never return zero
                // devices" invariant for a quiet single-device profile. A
                // rotated/abandoned device_id, whose last_seen is frozen while
                // the live device keeps advancing, drops out after the window —
                // the zombie. Window: see KeysStore.device_liveness_window_ms.
                //
                // ВТОРОЕ УСЛОВИЕ (03.08.2026) — вытеснение заменённого
                // устройства. Окно выше ловит «давно молчит», а это — «замолчало
                // ровно тогда, когда появилась замена». Второе быстрее на две
                // недели и именно оно нужно после переустановки приложения.
                //
                // Самое новое устройство под правило не попадает НИКОГДА: у него
                // нет более позднего собрата, поэтому NOT EXISTS для него всегда
                // истинен. Инвариант «никогда не возвращать ноль устройств»
                // сохраняется без отдельной проверки.
                let mut stmt = c.prepare(
                    "SELECT d.device_id FROM devices d WHERE d.profile_id = ?1
                       AND d.last_seen_ms >= (SELECT MAX(last_seen_ms) FROM devices WHERE profile_id = ?1) - ?2
                       AND NOT EXISTS (
                             SELECT 1 FROM devices n
                              WHERE n.profile_id = d.profile_id
                                AND n.created_at_ms > d.created_at_ms
                                -- 🔴 ЗАМЕНА ТОЛЬКО В ПРЕДЕЛАХ ОДНОГО КЛАССА (11.09.2026).
                                -- Десктоп не заменяет телефон. Инцидент 03.08, ради которого
                                -- правило писалось, был про переустановку ТОГО ЖЕ приложения
                                -- на ТОМ ЖЕ телефоне — там классы совпадают, польза цела.
                                -- Без условия регистрация десктопа вытесняла телефон владельца
                                -- из собственного профиля: он замолчал на сервере ключей за три
                                -- минуты до появления десктопа (19:05 против 19:08) и прошёл оба
                                -- порога. Выхода из этого не было: вытесненное устройство не
                                -- может обновить last_seen, и условие только крепнет.
                                -- Класс по умолчанию 'mobile' — как в схеме device_metadata.
                                AND COALESCE((SELECT device_class FROM device_metadata WHERE device_id = n.device_id), 'mobile')
                                  = COALESCE((SELECT device_class FROM device_metadata WHERE device_id = d.device_id), 'mobile')
                                AND d.last_seen_ms <= n.created_at_ms + ?3
                                AND (SELECT MAX(last_seen_ms) FROM devices WHERE profile_id = ?1)
                                    - d.last_seen_ms > ?4
                           )
                     ORDER BY d.created_at_ms ASC",
                )?;
                let mut rows = stmt.query(params![
                    pid,
                    window_ms,
                    SUPERSEDED_HANDOVER_GRACE_MS,
                    SUPERSEDED_SILENCE_MS
                ])?;
                let mut out = Vec::new();
                while let Some(row) = rows.next()? {
                    let did: String = row.get(0)?;
                    out.push(did);
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    /// Picks the single stalest device for a profile that is safe to evict when
    /// the per-profile device cap is hit, EXCLUDING `exclude_device_id` (the
    /// device currently registering — it must never be evicted).
    ///
    /// Selection order:
    ///   1. Devices with NO `device_key_bundles` row (never-published / dead)
    ///      are preferred over devices that have a published bundle.
    ///   2. Within each group, the stalest by recorded activity:
    ///      `COALESCE(device_metadata.updated_at_ms, devices.created_at_ms) ASC`,
    ///      then `devices.created_at_ms ASC`, then `device_id` for determinism.
    ///
    /// Returns `Ok(None)` when no other device exists for the profile. Callers
    /// rely on this `None` to uphold the "never leave a profile with zero
    /// devices" invariant — eviction is only ever attempted while ADDING a new
    /// device, so a successful evict-then-register keeps the count at the cap.
    pub async fn stalest_evictable_device(
        &self,
        profile_id: &str,
        exclude_device_id: &str,
    ) -> Result<Option<String>, String> {
        let pid = profile_id.to_string();
        let exclude = exclude_device_id.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<Option<String>, rusqlite::Error> {
                c.query_row(
                    r#"
SELECT d.device_id
FROM devices d
LEFT JOIN device_key_bundles b
  ON b.profile_id = d.profile_id AND b.device_id = d.device_id
LEFT JOIN device_metadata m
  ON m.device_id = d.device_id
WHERE d.profile_id = ?1 AND d.device_id <> ?2
ORDER BY
  CASE WHEN b.device_id IS NULL THEN 0 ELSE 1 END ASC,
  -- FIX-SERVER-1: rank by the freshest of (last_seen, metadata activity,
  -- created) so eviction targets the genuinely DEAD device — never a live
  -- device that simply registered long ago. Without last_seen, a year-old live
  -- device looked "staler" than a week-old zombie and could be wrongly evicted.
  MAX(COALESCE(m.updated_at_ms, 0), d.last_seen_ms, d.created_at_ms) ASC,
  d.created_at_ms ASC,
  d.device_id ASC
LIMIT 1
"#,
                    params![pid, exclude],
                    |row| row.get::<_, String>(0),
                )
                .optional()
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    pub async fn list_device_statuses(
        &self,
        profile_id: &str,
    ) -> Result<Vec<DeviceStatusRow>, String> {
        let pid = profile_id.to_string();
        let window_ms = self.device_liveness_window_ms;
        let out = self
            .conn
            .call(move |c| -> Result<Vec<DeviceStatusRow>, rusqlite::Error> {
                // FIX-SERVER-1 (zombie devices): same relative liveness filter as
                // list_devices — a device is live if its last_seen is within the
                // liveness window of the profile's freshest device; the freshest
                // always passes, so a quiet profile never resolves to zero.
                let mut stmt = c.prepare(
                    "SELECT d.device_id,
                            CASE WHEN b.device_id IS NULL THEN 0 ELSE 1 END AS has_bundle,
                            b.identity_key_pub_b64,
                            b.signed_prekey_pub_b64,
                            b.signed_prekey_sig_b64
                     FROM devices d
                     LEFT JOIN device_key_bundles b
                       ON b.profile_id = d.profile_id AND b.device_id = d.device_id
                     WHERE d.profile_id = ?1
                       AND d.last_seen_ms >= (SELECT MAX(last_seen_ms) FROM devices WHERE profile_id = ?1) - ?2
                       -- 🔴 ВЫТЕСНЕНИЕ (06.08.2026). Это ТРЕТЬЕ место, где
                       -- решается «живо ли устройство», и до сих пор
                       -- единственное без этого правила — при том что именно
                       -- отсюда клиент берёт СПИСОК ДЛЯ РАССЫЛКИ
                       -- (`/v1/profile/{id}/devices`). `list_devices` правило
                       -- имел, выдача связок получила его часом раньше, а
                       -- отправка всё это время ходила мимо обоих.
                       --
                       -- Цена расхождения измерена: 61 сообщение ушло в ящик
                       -- заменённого устройства уже ПОСЛЕ того, как правило
                       -- добавили в выдачу связок. Связка нужна только для
                       -- ПЕРВОГО рукопожатия; у кого сессия уже есть, тот шлёт
                       -- по ратчету и связку не спрашивает вовсе — поэтому
                       -- фильтр там мёртвому адресу не мешал.
                       --
                       -- Правило дословно то же, три условия обязательны вместе.
                       AND NOT EXISTS (
                             SELECT 1 FROM devices n
                              WHERE n.profile_id = d.profile_id
                                AND n.created_at_ms > d.created_at_ms
                                -- 🔴 ЗАМЕНА ТОЛЬКО В ПРЕДЕЛАХ ОДНОГО КЛАССА (11.09.2026).
                                -- Десктоп не заменяет телефон. Инцидент 03.08, ради которого
                                -- правило писалось, был про переустановку ТОГО ЖЕ приложения
                                -- на ТОМ ЖЕ телефоне — там классы совпадают, польза цела.
                                -- Без условия регистрация десктопа вытесняла телефон владельца
                                -- из собственного профиля: он замолчал на сервере ключей за три
                                -- минуты до появления десктопа (19:05 против 19:08) и прошёл оба
                                -- порога. Выхода из этого не было: вытесненное устройство не
                                -- может обновить last_seen, и условие только крепнет.
                                -- Класс по умолчанию 'mobile' — как в схеме device_metadata.
                                AND COALESCE((SELECT device_class FROM device_metadata WHERE device_id = n.device_id), 'mobile')
                                  = COALESCE((SELECT device_class FROM device_metadata WHERE device_id = d.device_id), 'mobile')
                                AND d.last_seen_ms <= n.created_at_ms + ?3
                                AND (SELECT MAX(last_seen_ms) FROM devices WHERE profile_id = ?1)
                                    - d.last_seen_ms > ?4
                           )
                     ORDER BY d.created_at_ms ASC",
                )?;
                let mut rows = stmt.query(params![
                    pid,
                    window_ms,
                    SUPERSEDED_HANDOVER_GRACE_MS,
                    SUPERSEDED_SILENCE_MS
                ])?;
                let mut out = Vec::new();
                while let Some(row) = rows.next()? {
                    out.push(DeviceStatusRow {
                        device_id: row.get(0)?,
                        has_bundle: row.get::<_, i64>(1)? != 0,
                        identity_key_pub_b64: row.get(2)?,
                        signed_prekey_pub_b64: row.get(3)?,
                        signed_prekey_sig_b64: row.get(4)?,
                    });
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    /// Состояние ОДНОГО устройства профиля — без окна живости (25.09.2026, Н-2).
    ///
    /// Нужна ровно для одного случая: устройство спрашивает роспись своего же
    /// профиля, а окно его уже скрыло. Клиент при запуске сверяет роспись ДО
    /// регистрации и, не найдя себя, объявляет «удалено» — ПК показывает
    /// ложное «доступ отозван», телефон — «сбросьте профиль», а регистрации,
    /// которая вернула бы устройство в окно, так и не случается. Отсюда оно
    /// узнаёт, что зарегистрировано. `None` — такого устройства у профиля нет.
    pub async fn device_status_for_profile(
        &self,
        profile_id: &str,
        device_id: &str,
    ) -> Result<Option<DeviceStatusRow>, String> {
        let pid = profile_id.to_string();
        let did = device_id.to_string();
        self.conn
            .call(move |c| -> Result<Option<DeviceStatusRow>, rusqlite::Error> {
                c.query_row(
                    "SELECT d.device_id,
                            CASE WHEN b.device_id IS NULL THEN 0 ELSE 1 END AS has_bundle,
                            b.identity_key_pub_b64,
                            b.signed_prekey_pub_b64,
                            b.signed_prekey_sig_b64
                     FROM devices d
                     LEFT JOIN device_key_bundles b
                       ON b.profile_id = d.profile_id AND b.device_id = d.device_id
                     WHERE d.profile_id = ?1 AND d.device_id = ?2",
                    params![pid, did],
                    |row| {
                        Ok(DeviceStatusRow {
                            device_id: row.get(0)?,
                            has_bundle: row.get::<_, i64>(1)? != 0,
                            identity_key_pub_b64: row.get(2)?,
                            signed_prekey_pub_b64: row.get(3)?,
                            signed_prekey_sig_b64: row.get(4)?,
                        })
                    },
                )
                .optional()
            })
            .await
            .map_err(|e| e.to_string())
    }

    /// Отмечает, что устройство на связи (25.09.2026, Н-2). Раньше
    /// `last_seen_ms` двигали только регистрация и публикация ключей, то есть
    /// запуск приложения: работающий, но не перезапускаемый ПК через 14 суток
    /// скрывался окном от собеседников, хотя всё это время был онлайн.
    /// Возвращает, изменилась ли строка. Частоту ограничивает вызывающий.
    pub async fn touch_device_last_seen(&self, device_id: &str, now_ms: i64) -> Result<bool, String> {
        let did = device_id.to_string();
        let n = self
            .conn
            .call(move |c| -> Result<usize, rusqlite::Error> {
                c.execute(
                    "UPDATE devices SET last_seen_ms = ?2 WHERE device_id = ?1 AND last_seen_ms < ?2",
                    params![did, now_ms],
                )
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(n > 0)
    }

    #[cfg(test)]
    pub async fn device_last_seen_ms(&self, device_id: &str) -> Result<Option<i64>, String> {
        let did = device_id.to_string();
        self.conn
            .call(move |c| -> Result<Option<i64>, rusqlite::Error> {
                c.query_row(
                    "SELECT last_seen_ms FROM devices WHERE device_id = ?1",
                    params![did],
                    |row| row.get(0),
                )
                .optional()
            })
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn list_companion_devices(&self, profile_id: &str) -> Result<Vec<String>, String> {
        let pid = profile_id.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<Vec<String>, rusqlite::Error> {
                let mut stmt = c.prepare(
                    r#"
SELECT d.device_id
FROM devices d
LEFT JOIN device_metadata m ON m.device_id = d.device_id
WHERE d.profile_id = ?1
  AND COALESCE(m.device_class, 'mobile') IN ('desktop', 'web')
ORDER BY d.created_at_ms ASC
"#,
                )?;
                let mut rows = stmt.query(params![pid])?;
                let mut out = Vec::new();
                while let Some(row) = rows.next()? {
                    let did: String = row.get(0)?;
                    out.push(did);
                }
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    pub async fn desktop_companion_limit(&self, profile_id: &str) -> Result<Option<usize>, String> {
        let pid = profile_id.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<Option<usize>, rusqlite::Error> {
                let v: Option<i64> = c
                    .query_row(
                        "SELECT desktop_companion_limit FROM profile_companion_entitlements WHERE profile_id = ?1",
                        params![pid],
                        |row| row.get(0),
                    )
                    .optional()?;
                Ok(v.and_then(|value| usize::try_from(value).ok()))
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    pub async fn set_desktop_companion_limit(
        &self,
        profile_id: &str,
        desktop_companion_limit: usize,
        updated_at_ms: i64,
        source: Option<&str>,
    ) -> Result<bool, String> {
        let pid = profile_id.to_string();
        let limit = i64::try_from(desktop_companion_limit).unwrap_or(i64::MAX);
        let src = source.map(|value| value.to_string());

        let ok = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let exists: i64 = c.query_row(
                    "SELECT EXISTS(SELECT 1 FROM profiles WHERE profile_id = ?1)",
                    params![pid.clone()],
                    |row| row.get(0),
                )?;
                if exists == 0 {
                    return Ok(false);
                }

                let changed = c.execute(
                    r#"
INSERT INTO profile_companion_entitlements(profile_id, desktop_companion_limit, updated_at_ms, source)
VALUES(?1, ?2, ?3, ?4)
ON CONFLICT(profile_id) DO UPDATE SET
  desktop_companion_limit = excluded.desktop_companion_limit,
  updated_at_ms = excluded.updated_at_ms,
  source = excluded.source
"#,
                    params![pid, limit, updated_at_ms, src],
                )?;
                Ok(changed > 0)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(ok)
    }

    /// Reads the monetization entitlement row for a profile (TZ §S-1).
    /// Returns None when the profile has never been granted any entitlement —
    /// callers treat that as the default `free` tier.
    pub async fn entitlement_get(
        &self,
        profile_id: &str,
    ) -> Result<Option<EntitlementRecord>, String> {
        let pid = profile_id.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<Option<EntitlementRecord>, rusqlite::Error> {
                c.query_row(
                    r#"
SELECT profile_id, tier, source, store_tx_id, expires_at_ms, grace_until_ms, updated_at_ms
FROM entitlements WHERE profile_id = ?1
"#,
                    params![pid],
                    |row| {
                        Ok(EntitlementRecord {
                            profile_id: row.get(0)?,
                            tier: row.get(1)?,
                            source: row.get(2)?,
                            store_tx_id: row.get(3)?,
                            expires_at_ms: row.get(4)?,
                            grace_until_ms: row.get(5)?,
                            updated_at_ms: row.get(6)?,
                        })
                    },
                )
                .optional()
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    /// Admin revoke: drop a profile's entitlement row so it reverts to free and
    /// its store_tx binding is released. Returns true if a row was removed. An
    /// active store subscription simply re-grants on the next redeem — this is
    /// for removing comps / stale grants, not for denying a paid subscription.
    pub async fn entitlement_revoke(&self, profile_id: &str) -> Result<bool, String> {
        let profile_id = profile_id.to_string();
        self.conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let n = c.execute(
                    "DELETE FROM entitlements WHERE profile_id = ?1",
                    params![profile_id],
                )?;
                Ok(n > 0)
            })
            .await
            .map_err(|e| e.to_string())
    }

    /// Returns the profile that owns a given store transaction id, if any. Used
    /// by S-2 webhooks (renewal/refund) to locate the entitlement to update, and
    /// by /redeem to reject a receipt already bound to a different profile.
    pub async fn entitlement_profile_for_store_tx(
        &self,
        store_tx_id: &str,
    ) -> Result<Option<String>, String> {
        let tx = store_tx_id.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<Option<String>, rusqlite::Error> {
                c.query_row(
                    "SELECT profile_id FROM entitlements WHERE store_tx_id = ?1",
                    params![tx],
                    |row| row.get(0),
                )
                .optional()
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    /// Upserts the monetization entitlement row for a profile (used by S-2 redeem
    /// and S-4 legacy_claim). The profile must already exist. `store_tx_id` is
    /// UNIQUE — a unique-constraint violation surfaces as an Err so the caller can
    /// reject a receipt that is already bound to a different profile.
    pub async fn entitlement_upsert(
        &self,
        rec: EntitlementRecord,
    ) -> Result<bool, String> {
        let ok = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let exists: i64 = c.query_row(
                    "SELECT EXISTS(SELECT 1 FROM profiles WHERE profile_id = ?1)",
                    params![rec.profile_id.clone()],
                    |row| row.get(0),
                )?;
                if exists == 0 {
                    return Ok(false);
                }
                let changed = c.execute(
                    r#"
INSERT INTO entitlements(profile_id, tier, source, store_tx_id, expires_at_ms, grace_until_ms, updated_at_ms)
VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7)
ON CONFLICT(profile_id) DO UPDATE SET
  tier = excluded.tier,
  source = excluded.source,
  store_tx_id = excluded.store_tx_id,
  expires_at_ms = excluded.expires_at_ms,
  grace_until_ms = excluded.grace_until_ms,
  updated_at_ms = excluded.updated_at_ms
"#,
                    params![
                        rec.profile_id,
                        rec.tier,
                        rec.source,
                        rec.store_tx_id,
                        rec.expires_at_ms,
                        rec.grace_until_ms,
                        rec.updated_at_ms,
                    ],
                )?;
                Ok(changed > 0)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(ok)
    }

    /// Hands the entitlement to the profile that has just proved, with a
    /// store-verified receipt, that it owns the purchase — unless it changed
    /// hands too recently.
    ///
    /// Without accounts, the receipt is the only durable proof of purchase a
    /// person carries: it survives reinstalls, new phones and a lost database,
    /// where a profile_id does not. Refusing to move it meant that reinstalling
    /// without restoring the profile silently forfeited a live subscription,
    /// while the app told the buyer no purchase existed. Possession of a
    /// verified receipt is the strongest claim this design can observe, so it
    /// wins.
    ///
    /// [min_interval_ms] is the anti-flap guard: two people sharing one store
    /// account can pass the entitlement back and forth at most once per window,
    /// rather than fighting over it on every launch. The first move is always
    /// allowed, which is the reinstall case.
    ///
    /// A move INTO a profile younger than [`RECEIPT_CLAIM_FRESH_PROFILE_MS`]
    /// does not arm the window: that is the phone's automatic claim on first
    /// launch, made before the person could restore their real profile. The
    /// real profile, restored a minute later, then takes the purchase straight
    /// back — and its move arms the window, so the next throwaway profile of a
    /// reinstall within a day is refused instead.
    ///
    /// Returns [`ReceiptClaim::Refused`] when the guard blocks the move or the
    /// target profile is unknown; the caller then keeps the old refusal.
    pub async fn entitlement_claim_by_receipt(
        &self,
        from: &str,
        to: &str,
        now_ms: i64,
        min_interval_ms: i64,
    ) -> Result<ReceiptClaim, String> {
        let from = from.to_string();
        let to = to.to_string();
        self.conn
            .call(move |c| -> Result<ReceiptClaim, rusqlite::Error> {
                let tx = c.transaction()?;
                let last_move: i64 = tx.query_row(
                    "SELECT COALESCE((SELECT migrated_at_ms FROM entitlements WHERE profile_id = ?1), 0)",
                    params![from.clone()],
                    |row| row.get(0),
                )?;
                if last_move > 0 && now_ms.saturating_sub(last_move) < min_interval_ms {
                    return Ok(ReceiptClaim::Refused);
                }
                let target_created: Option<i64> = tx
                    .query_row(
                        "SELECT created_at_ms FROM profiles WHERE profile_id = ?1",
                        params![to.clone()],
                        |row| row.get(0),
                    )
                    .optional()?;
                let Some(target_created) = target_created else {
                    return Ok(ReceiptClaim::Refused);
                };
                // A profile "created" after `now_ms` is a clock artefact, not a
                // fresh install — it keeps the old behaviour and arms the window.
                let fresh = target_created > 0
                    && now_ms >= target_created
                    && now_ms - target_created < RECEIPT_CLAIM_FRESH_PROFILE_MS;
                let armed_at_ms = if fresh { 0 } else { now_ms };
                // The target's own row (if any) loses to the receipt: a free or
                // expired row must not block the purchase it does not own.
                tx.execute(
                    "DELETE FROM entitlements WHERE profile_id = ?1",
                    params![to.clone()],
                )?;
                let moved = tx.execute(
                    "UPDATE entitlements SET profile_id = ?1, migrated_at_ms = ?2, updated_at_ms = ?3 \
                     WHERE profile_id = ?4",
                    params![to, armed_at_ms, now_ms, from],
                )?;
                tx.commit()?;
                Ok(if moved == 0 {
                    ReceiptClaim::Refused
                } else if fresh {
                    ReceiptClaim::MovedToFreshProfile
                } else {
                    ReceiptClaim::Moved
                })
            })
            .await
            .map_err(|e| e.to_string())
    }

    /// Atomically moves an entitlement row from `from` to `to`, preserving
    /// tier/source/store_tx_id/expiry so the (UNIQUE) receipt binding follows the
    /// new profile. Any pre-existing entitlement on `to` is replaced, and the old
    /// `from` row is removed. Used by the admin "I lost my profile" rebind so a
    /// paid user who created a new Secretly ID keeps their premium without anyone
    /// hand-editing keys.db.
    pub async fn entitlement_rebind(
        &self,
        from: &str,
        to: &str,
        now_ms: i64,
    ) -> Result<EntitlementRebind, String> {
        let from = from.to_string();
        let to = to.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<EntitlementRebind, rusqlite::Error> {
                let tx = c.transaction()?;
                // The target profile must exist (mirrors entitlement_upsert).
                let target_exists: i64 = tx.query_row(
                    "SELECT EXISTS(SELECT 1 FROM profiles WHERE profile_id = ?1)",
                    params![to],
                    |row| row.get(0),
                )?;
                if target_exists == 0 {
                    return Ok(EntitlementRebind::UnknownTarget);
                }
                let src: Option<EntitlementRecord> = tx
                    .query_row(
                        r#"
SELECT profile_id, tier, source, store_tx_id, expires_at_ms, grace_until_ms, updated_at_ms
FROM entitlements WHERE profile_id = ?1
"#,
                        params![from],
                        |row| {
                            Ok(EntitlementRecord {
                                profile_id: row.get(0)?,
                                tier: row.get(1)?,
                                source: row.get(2)?,
                                store_tx_id: row.get(3)?,
                                expires_at_ms: row.get(4)?,
                                grace_until_ms: row.get(5)?,
                                updated_at_ms: row.get(6)?,
                            })
                        },
                    )
                    .optional()?;
                let Some(mut rec) = src else {
                    return Ok(EntitlementRebind::NoSource);
                };
                // Replace any entitlement currently on the target, then move the
                // source row over (UPDATE of the PK keeps store_tx_id unique).
                tx.execute("DELETE FROM entitlements WHERE profile_id = ?1", params![to])?;
                tx.execute(
                    "UPDATE entitlements SET profile_id = ?1, updated_at_ms = ?2 WHERE profile_id = ?3",
                    params![to, now_ms, from],
                )?;
                tx.commit()?;
                rec.profile_id = to;
                rec.updated_at_ms = now_ms;
                Ok(EntitlementRebind::Moved(rec))
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    /// Removes a device registration for a profile (best-effort; returns true if deleted).
    /// Used to evict stale/old devices when the per-profile device limit is reached,
    /// so a new legitimate device can always register with valid profile credentials.
    pub async fn delete_device(&self, profile_id: &str, device_id: &str) -> Result<bool, String> {
        let pid = profile_id.to_string();
        let did = device_id.to_string();
        let pid_for_bundle = pid.clone();
        let did_for_bundle = did.clone();
        let did_for_prekeys = did.clone();
        let deleted = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let tx = c.transaction()?;
                let n = tx.execute(
                    "DELETE FROM devices WHERE profile_id = ?1 AND device_id = ?2",
                    params![pid, did],
                )?;
                tx.execute(
                    "DELETE FROM device_metadata WHERE device_id = ?1",
                    params![did_for_prekeys.clone()],
                )?;
                tx.execute(
                    "DELETE FROM device_key_bundles WHERE profile_id = ?1 AND device_id = ?2",
                    params![pid_for_bundle, did_for_bundle],
                )?;
                tx.execute(
                    "DELETE FROM one_time_prekeys WHERE device_id = ?1",
                    params![did_for_prekeys],
                )?;
                tx.commit()?;
                Ok(n > 0)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(deleted)
    }

    pub async fn delete_profile(&self, profile_id: &str) -> Result<bool, String> {
        let pid = profile_id.to_string();
        let deleted = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let tx = c.transaction()?;
                let mut deleted_rows = 0usize;
                deleted_rows += tx.execute(
                    "DELETE FROM one_time_prekeys WHERE device_id IN (SELECT device_id FROM devices WHERE profile_id = ?1)",
                    params![pid.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM device_key_bundles WHERE profile_id = ?1",
                    params![pid.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM devices WHERE profile_id = ?1",
                    params![pid.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM profile_meta WHERE profile_id = ?1",
                    params![pid.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM profile_backups WHERE profile_id = ?1",
                    params![pid.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM device_metadata WHERE profile_id = ?1",
                    params![pid.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM profile_companion_entitlements WHERE profile_id = ?1",
                    params![pid.clone()],
                )?;
                deleted_rows += tx.execute(
                    "DELETE FROM profiles WHERE profile_id = ?1",
                    params![pid],
                )?;
                tx.commit()?;
                Ok(deleted_rows > 0)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(deleted)
    }

    pub async fn profile_id_for_device(&self, device_id: &str) -> Result<Option<String>, String> {
        let did = device_id.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<Option<String>, rusqlite::Error> {
                let v: Option<String> = c
                    .query_row(
                        "SELECT profile_id FROM devices WHERE device_id = ?1",
                        params![did],
                        |row| row.get(0),
                    )
                    .optional()?;
                Ok(v)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    pub async fn identity_key_for_device(&self, device_id: &str) -> Result<Option<String>, String> {
        let did = device_id.to_string();
        let out = self
            .conn
            .call(move |c| -> Result<Option<String>, rusqlite::Error> {
                let v: Option<String> = c
                    .query_row(
                        "SELECT identity_key_pub_b64 FROM devices WHERE device_id = ?1",
                        params![did],
                        |row| row.get(0),
                    )
                    .optional()?;
                Ok(v)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(out)
    }

    pub async fn publish_key_bundle(
        &self,
        profile_id: &str,
        device_id: &str,
        identity_key_pub_b64: &str,
        signed_prekey_pub_b64: &str,
        signed_prekey_sig_b64: &str,
        one_time_prekeys: Vec<OneTimePrekey>,
        now_ms: i64,
        account_identity_pub_b64: Option<&str>,
        device_cert_b64: Option<&str>,
    ) -> Result<bool, String> {
        let pid = profile_id.to_string();
        let did = device_id.to_string();
        let ik = identity_key_pub_b64.to_string();
        let spk = signed_prekey_pub_b64.to_string();
        let spk_sig = signed_prekey_sig_b64.to_string();
        // Empty string and absent mean the same thing here: nothing to record.
        let aik = account_identity_pub_b64
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string);
        let cert = device_cert_b64
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string);

        let ok = self
            .conn
            .call(move |c| -> Result<bool, rusqlite::Error> {
                let tx = c.transaction()?;
                let exists: i64 = tx.query_row(
                    "SELECT EXISTS(SELECT 1 FROM profiles WHERE profile_id = ?1)",
                    params![pid.clone()],
                    |row| row.get(0),
                )?;
                if exists == 0 {
                    tx.commit()?;
                    return Ok(false);
                }

                // Device must already be registered and bound to this profile (and identity key).
                let device_profile: Option<String> = tx
                    .query_row(
                        "SELECT profile_id FROM devices WHERE device_id = ?1",
                        params![did.clone()],
                        |row| row.get(0),
                    )
                    .optional()?;
                if device_profile.as_deref() != Some(pid.as_str()) {
                    tx.commit()?;
                    return Ok(false);
                }

                let device_ik: Option<String> = tx
                    .query_row(
                        "SELECT identity_key_pub_b64 FROM devices WHERE device_id = ?1",
                        params![did.clone()],
                        |row| row.get(0),
                    )
                    .optional()?;
                if device_ik.as_deref() != Some(ik.as_str()) {
                    tx.commit()?;
                    return Ok(false);
                }

                tx.execute(
                    // 🔴 New columns belong in the DO UPDATE list too. This
                    // enumerates columns by hand — the same shape as
                    // ConflictAlgorithm.replace on the client — so a column left
                    // out here would silently keep a stale value forever, and the
                    // client republishes roughly every 12 hours.
                    "INSERT INTO device_key_bundles(device_id, profile_id, identity_key_pub_b64, signed_prekey_pub_b64, signed_prekey_sig_b64, updated_at_ms, account_identity_pub_b64, device_cert_b64)
                     VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
                     ON CONFLICT(device_id) DO UPDATE SET
                       profile_id=excluded.profile_id,
                       identity_key_pub_b64=excluded.identity_key_pub_b64,
                       signed_prekey_pub_b64=excluded.signed_prekey_pub_b64,
                       signed_prekey_sig_b64=excluded.signed_prekey_sig_b64,
                       updated_at_ms=excluded.updated_at_ms,
                       account_identity_pub_b64=excluded.account_identity_pub_b64,
                       device_cert_b64=excluded.device_cert_b64",
                    params![did.clone(), pid.clone(), ik, spk, spk_sig, now_ms, aik, cert],
                )?;

                // FIX-SERVER-1: a key publish (client republishes ~every 12h and
                // on launch) is a liveness heartbeat — stamp the device's
                // last_seen so a live device stays discoverable between
                // re-registrations. Monotonic guard against out-of-order calls.
                let _ = tx.execute(
                    "UPDATE devices SET last_seen_ms = ?2 WHERE device_id = ?1 AND last_seen_ms < ?2",
                    params![did.clone(), now_ms],
                )?;

                for otk in one_time_prekeys {
                    tx.execute(
                        "INSERT OR IGNORE INTO one_time_prekeys(device_id, prekey_id, prekey_pub_b64, created_at_ms) VALUES(?1, ?2, ?3, ?4)",
                        params![did.clone(), otk.prekey_id, otk.prekey_pub_b64, now_ms],
                    )?;
                }

                tx.commit()?;
                Ok(true)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(ok)
    }

    /// Fetch bundles for a profile. For each device, returns the latest bundle plus
    /// at most one one-time prekey (popped atomically).
    pub async fn fetch_bundles_for_profile(
        &self,
        profile_id: &str,
    ) -> Result<Vec<DeviceKeyBundle>, String> {
        let pid = profile_id.to_string();
        let window_ms = self.device_liveness_window_ms;
        let bundles = self
            .conn
            .call(move |c| -> Result<Vec<DeviceKeyBundle>, rusqlite::Error> {
                let tx = c.transaction()?;

                let out = {
                    // FIX-SERVER-1 (zombie devices): only hand out bundles for
                    // LIVE devices, relative to the profile's freshest bundle
                    // (republished within the liveness window). The freshest
                    // always passes so a quiet single-device profile still
                    // resolves; a rotated/abandoned device's bundle goes stale
                    // (never republished) and drops once a fresher device
                    // exists. Window: KeysStore.device_liveness_window_ms.
                    // 🔴 ВТОРОЕ УСЛОВИЕ — ВЫТЕСНЕНИЕ (06.08.2026, полевая потеря
                    // 21 сообщения).
                    //
                    // Условие выше меряет свежесть СВЯЗКИ, а `list_devices` —
                    // молчание УСТРОЙСТВА. Это два разных понятия «живой», и
                    // путь отправки ходил через то, где вытеснения нет.
                    //
                    // Полевой случай: человек восстановился из копии, старое
                    // устройство заменилось новым. `list_devices` его исключил
                    // правильно — а здесь его связка (на 4 часа старше свежей)
                    // спокойно проходила окно и выдавалась. Отправитель брал
                    // мёртвый device_id из своего кэша, спрашивал связку ПО ID,
                    // получал её и слал в ящик, который никто не вычерпывает.
                    // Реле принимало без возражений, квитанции не приходило —
                    // «отправилось, но не пришло», без ошибки где бы то ни было.
                    //
                    // Правило дословно то же, что в `list_devices`: устройство
                    // вытеснено, если есть БОЛЕЕ НОВОЕ, и это замолчало ровно
                    // тогда, когда новое появилось, и молчит дольше окна тишины.
                    // Все три условия обязательны вместе — по одному только
                    // молчанию отбрасывать нельзя, иначе телефон, полежавший
                    // полчаса в кармане, выпадет из выдачи, и сообщения ему
                    // перестанут класть вовсе. Это было бы хуже чинимого.
                    //
                    // Самое новое устройство под правило не попадает никогда:
                    // более позднего собрата у него нет. Инвариант «никогда не
                    // возвращать ноль» сохраняется без отдельной проверки.
                    let mut stmt = tx.prepare(
                        "SELECT b.device_id, b.identity_key_pub_b64, b.signed_prekey_pub_b64, b.signed_prekey_sig_b64,
                                b.account_identity_pub_b64, b.device_cert_b64
                         FROM device_key_bundles b
                         JOIN devices d ON d.device_id = b.device_id
                         WHERE b.profile_id = ?1
                           AND b.updated_at_ms >= (SELECT MAX(updated_at_ms) FROM device_key_bundles WHERE profile_id = ?1) - ?2
                           AND NOT EXISTS (
                                 SELECT 1 FROM devices n
                                  WHERE n.profile_id = d.profile_id
                                    AND n.created_at_ms > d.created_at_ms
                                    -- 🔴 ЗАМЕНА ТОЛЬКО В ПРЕДЕЛАХ ОДНОГО КЛАССА (11.09.2026).
                                    -- Десктоп не заменяет телефон. Инцидент 03.08, ради которого
                                    -- правило писалось, был про переустановку ТОГО ЖЕ приложения
                                    -- на ТОМ ЖЕ телефоне — там классы совпадают, польза цела.
                                    -- Без условия регистрация десктопа вытесняла телефон владельца
                                    -- из собственного профиля: он замолчал на сервере ключей за три
                                    -- минуты до появления десктопа (19:05 против 19:08) и прошёл оба
                                    -- порога. Выхода из этого не было: вытесненное устройство не
                                    -- может обновить last_seen, и условие только крепнет.
                                    -- Класс по умолчанию 'mobile' — как в схеме device_metadata.
                                    AND COALESCE((SELECT device_class FROM device_metadata WHERE device_id = n.device_id), 'mobile')
                                      = COALESCE((SELECT device_class FROM device_metadata WHERE device_id = d.device_id), 'mobile')
                                    AND d.last_seen_ms <= n.created_at_ms + ?3
                                    AND (SELECT MAX(last_seen_ms) FROM devices WHERE profile_id = d.profile_id)
                                        - d.last_seen_ms > ?4
                               )
                         ORDER BY b.updated_at_ms DESC",
                    )?;
                    let mut rows = stmt.query(params![
                        pid,
                        window_ms,
                        SUPERSEDED_HANDOVER_GRACE_MS,
                        SUPERSEDED_SILENCE_MS
                    ])?;
                    let mut out = Vec::new();

                    while let Some(row) = rows.next()? {
                        let device_id: String = row.get(0)?;
                        let identity_key_pub_b64: String = row.get(1)?;
                        let signed_prekey_pub_b64: String = row.get(2)?;
                        let signed_prekey_sig_b64: String = row.get(3)?;
                        let account_identity_pub_b64: Option<String> = row.get(4)?;
                        let device_cert_b64: Option<String> = row.get(5)?;

                        // Pop one OTK (oldest).
                        let otk: Option<OneTimePrekey> = tx
                            .query_row(
                                "SELECT prekey_id, prekey_pub_b64 FROM one_time_prekeys WHERE device_id = ?1 ORDER BY created_at_ms ASC LIMIT 1",
                                params![device_id.clone()],
                                |r| {
                                    Ok(OneTimePrekey {
                                        prekey_id: r.get(0)?,
                                        prekey_pub_b64: r.get(1)?,
                                    })
                                },
                            )
                            .optional()?;

                        if let Some(ref k) = otk {
                            tx.execute(
                                "DELETE FROM one_time_prekeys WHERE device_id = ?1 AND prekey_id = ?2",
                                params![device_id.clone(), k.prekey_id],
                            )?;
                        }

                        out.push(DeviceKeyBundle {
                            device_id,
                            identity_key_pub_b64,
                            signed_prekey_pub_b64,
                            signed_prekey_sig_b64,
                            one_time_prekey: otk,
                            account_identity_pub_b64,
                            device_cert_b64,
                        });
                    }

                    out
                };

                tx.commit()?;
                Ok(out)
            })
            .await
            .map_err(|e| e.to_string())?;
        Ok(bundles)
    }
}
