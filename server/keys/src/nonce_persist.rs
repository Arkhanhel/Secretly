// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
//
// Журнал использованных одноразовых меток (nonce) подписанных запросов
// переживает перезапуск службы.
//
// Аудит 21.10.2026: метки жили только в памяти. Подпись запроса верна
// ±5 минут, поэтому запрос, перехваченный до перезапуска, можно было повторить
// сразу после него — сервер его «не видел». Теперь журнал раз в две секунды
// (только если изменился) пишется в файл рядом с базой и читается при старте.
// Если служба упала без записи, теряется не больше двух последних секунд.
//
// Файл — `{"device:nonce": срок_мс, …}`; просроченные записи не пишутся и не
// читаются. Запись атомарная: временный файл и переименование.
// Тот же модуль лежит в `server/relay/src/nonce_persist.rs`.
use dashmap::DashMap;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;

/// Путь к журналу: переменная окружения или `<база>.nonces.json`.
pub fn nonce_file_path(env_var: &str, db_path: &str) -> PathBuf {
    match std::env::var(env_var) {
        Ok(v) if !v.trim().is_empty() => PathBuf::from(v.trim()),
        _ => PathBuf::from(format!("{db_path}.nonces.json")),
    }
}

/// Читает журнал в [map]; возвращает число загруженных непросроченных меток.
/// Любая ошибка чтения — 0: служба поднимается и без журнала.
pub fn load(path: &Path, now_ms: i64, map: &DashMap<String, i64>) -> usize {
    let Ok(raw) = std::fs::read(path) else {
        return 0;
    };
    let Ok(entries) = serde_json::from_slice::<HashMap<String, i64>>(&raw) else {
        return 0;
    };
    let mut n = 0;
    for (k, exp) in entries {
        if exp > now_ms {
            map.insert(k, exp);
            n += 1;
        }
    }
    n
}

/// Записывает непросроченные метки (атомарно).
pub fn save(path: &Path, now_ms: i64, map: &DashMap<String, i64>) -> std::io::Result<()> {
    let snapshot: HashMap<String, i64> = map
        .iter()
        .filter(|e| *e.value() > now_ms)
        .map(|e| (e.key().clone(), *e.value()))
        .collect();
    let body = serde_json::to_vec(&snapshot).map_err(std::io::Error::other)?;
    let tmp = path.with_extension("json.tmp");
    std::fs::write(&tmp, body)?;
    std::fs::rename(&tmp, path)
}

/// Отпечаток содержимого: меняется при добавлении или удалении метки.
fn fingerprint(map: &DashMap<String, i64>) -> (usize, i64) {
    let mut sum: i64 = 0;
    for e in map.iter() {
        sum = sum.wrapping_add(*e.value());
    }
    (map.len(), sum)
}

/// Раз в две секунды сохраняет журнал, если он изменился.
pub fn spawn_flusher(path: PathBuf, map: Arc<DashMap<String, i64>>, now_ms: fn() -> i64) {
    tokio::spawn(async move {
        let mut last = fingerprint(&map);
        let mut tick = tokio::time::interval(std::time::Duration::from_secs(2));
        tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        loop {
            tick.tick().await;
            let fp = fingerprint(&map);
            if fp == last {
                continue;
            }
            last = fp;
            let path = path.clone();
            let map = map.clone();
            let now = now_ms();
            let res = tokio::task::spawn_blocking(move || save(&path, now, &map)).await;
            if let Ok(Err(e)) = res {
                tracing::warn!(error = %e, "nonce journal save failed");
            }
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn journal_round_trip_drops_expired_entries() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("x.db.nonces.json");
        let map = DashMap::new();
        map.insert("dev1:aaa".to_string(), 2_000);
        map.insert("dev1:old".to_string(), 500);
        save(&path, 1_000, &map).unwrap();

        let loaded = DashMap::new();
        assert_eq!(load(&path, 1_000, &loaded), 1);
        assert_eq!(loaded.get("dev1:aaa").map(|v| *v), Some(2_000));
        assert!(loaded.get("dev1:old").is_none());
        // После срока ничего не загружается.
        let later = DashMap::new();
        assert_eq!(load(&path, 3_000, &later), 0);
    }

    #[test]
    fn missing_or_broken_journal_is_not_fatal() {
        let dir = tempfile::tempdir().unwrap();
        let map = DashMap::new();
        assert_eq!(load(&dir.path().join("none.json"), 0, &map), 0);
        let bad = dir.path().join("bad.json");
        std::fs::write(&bad, b"{not json").unwrap();
        assert_eq!(load(&bad, 0, &map), 0);
    }
}
