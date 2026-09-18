// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

pub const COSMETICS_CATALOG_SCHEMA_VERSION: i64 = 1;

/// Signed catalog of premium cosmetics (profile icons + chat wallpapers) served
/// by the relay as static assets. Mirrors the sticker-catalog pattern: a JSON
/// document + detached Ed25519 signature, with per-item thumbnail + full files
/// resolved under `<root>/<kind-dir>/<file>`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CosmeticsCatalogDocument {
    pub schema_version: i64,
    #[serde(default)]
    pub generated_at_ms: i64,
    #[serde(default)]
    pub items: Vec<CosmeticsCatalogItem>,
}

impl Default for CosmeticsCatalogDocument {
    fn default() -> Self {
        Self {
            schema_version: COSMETICS_CATALOG_SCHEMA_VERSION,
            generated_at_ms: 0,
            items: Vec::new(),
        }
    }
}

impl CosmeticsCatalogDocument {
    pub fn from_json_str(raw: &str) -> Result<Self, String> {
        let parsed: Self = serde_json::from_str(raw).map_err(|e| e.to_string())?;
        parsed.validate()?;
        Ok(parsed)
    }

    pub fn find_item(&self, id: &str) -> Option<&CosmeticsCatalogItem> {
        self.items.iter().find(|item| item.id == id)
    }

    /// Resolves the on-disk path + content-type for an item variant
    /// (`"thumb"` or `"full"`). Files live under `<root>/<icons|wallpapers>/<file>`.
    pub fn asset_path_and_content_type(
        &self,
        root: &Path,
        item_id: &str,
        variant: &str,
    ) -> Result<(PathBuf, &'static str), String> {
        let item = self
            .find_item(item_id)
            .ok_or_else(|| "cosmetic not found".to_string())?;
        let file = match variant {
            "thumb" => &item.thumb_file,
            "full" => &item.full_file,
            _ => return Err("bad variant".to_string()),
        };
        let path = root.join(item.kind_dir()).join(file);
        Ok((path, content_type_for(file)))
    }

    fn validate(&self) -> Result<(), String> {
        if self.schema_version <= 0 {
            return Err("schema_version must be positive".into());
        }
        for item in &self.items {
            item.validate()?;
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CosmeticsCatalogItem {
    pub id: String,
    /// `"icon"` or `"wallpaper"`.
    pub kind: String,
    /// Filename of the small preview within the kind directory.
    pub thumb_file: String,
    /// Filename of the full-resolution asset within the kind directory.
    pub full_file: String,
    #[serde(default)]
    pub title: String,
    /// Base64 SHA-256 of the FULL asset — clients verify the download integrity.
    #[serde(default)]
    pub sha256_b64: String,
    #[serde(default)]
    pub thumb_sha256_b64: String,
    #[serde(default)]
    pub size_bytes: i64,
}

impl CosmeticsCatalogItem {
    fn validate(&self) -> Result<(), String> {
        if !is_safe_catalog_segment(&self.id) {
            return Err(format!("unsafe cosmetic id: {}", self.id));
        }
        if self.kind != "icon" && self.kind != "wallpaper" {
            return Err(format!("unknown cosmetic kind for {}: {}", self.id, self.kind));
        }
        if !is_safe_file_name(&self.thumb_file) {
            return Err(format!("unsafe thumb_file for {}: {}", self.id, self.thumb_file));
        }
        if !is_safe_file_name(&self.full_file) {
            return Err(format!("unsafe full_file for {}: {}", self.id, self.full_file));
        }
        Ok(())
    }

    fn kind_dir(&self) -> &'static str {
        match self.kind.as_str() {
            "icon" => "icons",
            "wallpaper" => "wallpapers",
            _ => "misc",
        }
    }
}

fn content_type_for(file: &str) -> &'static str {
    let lower = file.to_ascii_lowercase();
    if lower.ends_with(".webp") {
        "image/webp"
    } else if lower.ends_with(".png") {
        "image/png"
    } else if lower.ends_with(".jpg") || lower.ends_with(".jpeg") {
        "image/jpeg"
    } else {
        "application/octet-stream"
    }
}

fn is_safe_catalog_segment(raw: &str) -> bool {
    let trimmed = raw.trim();
    !trimmed.is_empty()
        && trimmed.len() <= 128
        && !trimmed.contains("..")
        && trimmed
            .chars()
            .all(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '_' | '-'))
}

fn is_safe_file_name(raw: &str) -> bool {
    let trimmed = raw.trim();
    !trimmed.is_empty()
        && trimmed.len() <= 255
        && !trimmed.contains("..")
        && !trimmed.contains('/')
        && !trimmed.contains('\\')
        && trimmed
            .chars()
            .all(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '_' | '-' | '.'))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_and_resolves_variants() {
        let doc = CosmeticsCatalogDocument::from_json_str(
            r#"{
  "schema_version": 1,
  "generated_at_ms": 123,
  "items": [
    {"id": "icon_051", "kind": "icon", "thumb_file": "051_thumb.webp", "full_file": "051.webp", "title": "Rocket"},
    {"id": "wp_beach", "kind": "wallpaper", "thumb_file": "beach_thumb.webp", "full_file": "beach.webp"}
  ]
}"#,
        )
        .unwrap();
        let (p, ct) = doc
            .asset_path_and_content_type(Path::new("root"), "icon_051", "full")
            .unwrap();
        assert_eq!(p, Path::new("root").join("icons").join("051.webp"));
        assert_eq!(ct, "image/webp");
        let (p2, _) = doc
            .asset_path_and_content_type(Path::new("root"), "wp_beach", "thumb")
            .unwrap();
        assert_eq!(
            p2,
            Path::new("root").join("wallpapers").join("beach_thumb.webp")
        );
    }

    #[test]
    fn rejects_unsafe_file_name() {
        let err = CosmeticsCatalogDocument::from_json_str(
            r#"{"schema_version":1,"items":[{"id":"x","kind":"icon","thumb_file":"../e.webp","full_file":"x.webp"}]}"#,
        )
        .unwrap_err();
        assert!(err.contains("unsafe thumb_file"));
    }

    #[test]
    fn rejects_unknown_kind() {
        let err = CosmeticsCatalogDocument::from_json_str(
            r#"{"schema_version":1,"items":[{"id":"x","kind":"sticker","thumb_file":"x_t.webp","full_file":"x.webp"}]}"#,
        )
        .unwrap_err();
        assert!(err.contains("unknown cosmetic kind"));
    }

    #[test]
    fn rejects_bad_variant() {
        let doc = CosmeticsCatalogDocument::from_json_str(
            r#"{"schema_version":1,"items":[{"id":"x","kind":"icon","thumb_file":"x_t.webp","full_file":"x.webp"}]}"#,
        )
        .unwrap();
        assert!(doc
            .asset_path_and_content_type(Path::new("root"), "x", "bogus")
            .is_err());
    }
}
