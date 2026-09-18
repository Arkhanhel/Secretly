// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

pub const STICKER_CATALOG_SCHEMA_VERSION: i64 = 1;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StickerCatalogDocument {
    pub schema_version: i64,
    #[serde(default)]
    pub generated_at_ms: i64,
    #[serde(default)]
    pub packs: Vec<StickerCatalogPackDocument>,
}

impl Default for StickerCatalogDocument {
    fn default() -> Self {
        Self {
            schema_version: STICKER_CATALOG_SCHEMA_VERSION,
            generated_at_ms: 0,
            packs: Vec::new(),
        }
    }
}

impl StickerCatalogDocument {
    pub fn from_json_str(raw: &str) -> Result<Self, String> {
        let parsed: Self = serde_json::from_str(raw).map_err(|e| e.to_string())?;
        parsed.validate()?;
        Ok(parsed)
    }

    pub fn find_pack(
        &self,
        pack_id: &str,
        pack_version: i64,
    ) -> Option<&StickerCatalogPackDocument> {
        self.packs
            .iter()
            .find(|pack| pack.pack_id == pack_id && pack.pack_version == pack_version)
    }

    pub fn asset_path_and_content_type(
        &self,
        root: &Path,
        pack_id: &str,
        pack_version: i64,
        sticker_id: &str,
    ) -> Result<(PathBuf, &'static str), String> {
        let pack = self
            .find_pack(pack_id, pack_version)
            .ok_or_else(|| "pack not found".to_string())?;
        let sticker = pack
            .stickers
            .iter()
            .find(|item| item.sticker_id == sticker_id)
            .ok_or_else(|| "sticker not found".to_string())?;
        let content_type = sticker.content_type();
        let path = root
            .join("packs")
            .join(&pack.pack_id)
            .join(pack.pack_version.to_string())
            .join("stickers")
            .join(&sticker.file_name);
        Ok((path, content_type))
    }

    fn validate(&self) -> Result<(), String> {
        if self.schema_version <= 0 {
            return Err("schema_version must be positive".into());
        }
        for pack in &self.packs {
            pack.validate()?;
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StickerCatalogPackDocument {
    pub pack_id: String,
    pub pack_version: i64,
    pub title: String,
    #[serde(default)]
    pub description: String,
    pub icon_sticker_id: String,
    #[serde(default)]
    pub icon_emoji_hint: String,
    #[serde(default)]
    pub featured_rank: Option<i64>,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub stickers: Vec<StickerCatalogStickerDocument>,
}

impl StickerCatalogPackDocument {
    fn validate(&self) -> Result<(), String> {
        if !is_safe_catalog_segment(&self.pack_id) {
            return Err(format!("unsafe pack_id: {}", self.pack_id));
        }
        if self.pack_version <= 0 {
            return Err(format!("bad pack_version for {}", self.pack_id));
        }
        if !is_safe_catalog_segment(&self.icon_sticker_id) {
            return Err(format!("unsafe icon_sticker_id: {}", self.icon_sticker_id));
        }
        if self.title.trim().is_empty() {
            return Err(format!("empty title for {}", self.pack_id));
        }
        for sticker in &self.stickers {
            sticker.validate(&self.pack_id)?;
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StickerCatalogStickerDocument {
    pub sticker_id: String,
    pub file_name: String,
    pub format: String,
    #[serde(default)]
    pub animated: bool,
    #[serde(default)]
    pub emoji_hint: String,
    #[serde(default)]
    pub label: String,
    #[serde(default)]
    pub keywords: Vec<String>,
    #[serde(default)]
    pub sha256_b64: String,
    #[serde(default)]
    pub size_bytes: i64,
}

impl StickerCatalogStickerDocument {
    fn validate(&self, pack_id: &str) -> Result<(), String> {
        if !is_safe_catalog_segment(&self.sticker_id) {
            return Err(format!(
                "unsafe sticker_id in {}: {}",
                pack_id, self.sticker_id
            ));
        }
        if !is_safe_file_name(&self.file_name) {
            return Err(format!(
                "unsafe file_name in {}: {}",
                pack_id, self.file_name
            ));
        }
        if self.format.trim().is_empty() {
            return Err(format!("empty format in {}:{}", pack_id, self.sticker_id));
        }
        Ok(())
    }

    pub fn content_type(&self) -> &'static str {
        match self.format.trim().to_ascii_lowercase().as_str() {
            "lottie" => "application/json",
            "webp" => "image/webp",
            _ => {
                if self.file_name.to_ascii_lowercase().ends_with(".webp") {
                    "image/webp"
                } else if self.file_name.to_ascii_lowercase().ends_with(".json") {
                    "application/json"
                } else {
                    "image/png"
                }
            }
        }
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
    fn parses_valid_catalog_and_resolves_asset_path() {
        let catalog = StickerCatalogDocument::from_json_str(
            r#"{
  "schema_version": 1,
  "generated_at_ms": 123,
  "packs": [
    {
      "pack_id": "winter_pack",
      "pack_version": 1,
      "title": "Winter",
      "icon_sticker_id": "winter_santa",
      "icon_emoji_hint": "🎅",
      "stickers": [
        {
          "sticker_id": "winter_santa",
          "file_name": "winter_santa.png",
          "format": "png",
          "animated": false,
          "emoji_hint": "🎅",
          "label": "Santa",
          "keywords": ["winter"]
        }
      ]
    }
  ]
}"#,
        )
        .unwrap();

        let (path, content_type) = catalog
            .asset_path_and_content_type(Path::new("catalog"), "winter_pack", 1, "winter_santa")
            .unwrap();
        assert_eq!(
            path,
            Path::new("catalog")
                .join("packs")
                .join("winter_pack")
                .join("1")
                .join("stickers")
                .join("winter_santa.png")
        );
        assert_eq!(content_type, "image/png");
    }

    #[test]
    fn rejects_unsafe_file_name() {
        let err = StickerCatalogDocument::from_json_str(
            r#"{
  "schema_version": 1,
  "packs": [
    {
      "pack_id": "unsafe_pack",
      "pack_version": 1,
      "title": "Unsafe",
      "icon_sticker_id": "unsafe_icon",
      "stickers": [
        {
          "sticker_id": "unsafe_icon",
          "file_name": "../escape.png",
          "format": "png"
        }
      ]
    }
  ]
}"#,
        )
        .unwrap_err();
        assert!(err.contains("unsafe file_name"));
    }
}
