// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
//! Receipt verification for App Store + Google Play (TZ-MONETIZE-01 §S-2).
//!
//! FAIL-CLOSED: an unverifiable or misconfigured receipt never grants a tier —
//! verification returns `Err` and the `/redeem` handler rejects. (Billing still
//! fails OPEN at the entitlement *read* layer — a down service must never block
//! messaging — but a *redeem* with a bad/forged receipt must NOT grant.)
//! Everything here is gated behind `monetization_enabled` and the human R3 step.
//!
//! ⚠️ LIVE VALIDATION REQUIRED BEFORE R3 (TZ §10): the cryptographic App Store
//! path and the Google Play Developer API path cannot be exercised end-to-end
//! without real sandbox/license-tester receipts. Run the §10 test matrix on
//! staging before flipping `monetization_enabled`. Required config (env):
//!   SECRETLY_APPSTORE_BUNDLE_ID            e.g. com.secretly.messenger
//!   SECRETLY_APPSTORE_ROOT_CERT_DER_B64    base64 of Apple Root CA - G3 (DER)
//!   SECRETLY_PLAY_PACKAGE                  e.g. com.secretly.secretly_app
//!   SECRETLY_PLAY_SERVICE_ACCOUNT_JSON     SA JSON content or a path to it
//!   SECRETLY_BILLING_APPSTORE_SANDBOX      allow (по умолчанию) | deny
//!
//! Anonymity (§0.2): only the opaque store transaction id and the profile id are
//! stored; nothing personal is extracted or logged from receipts.

#![allow(dead_code)] // wired into main.rs incrementally (S-2)

use base64::Engine as _;
use jsonwebtoken::{Algorithm, DecodingKey, Validation};
use serde::Deserialize;
use std::collections::HashSet;
use x509_parser::prelude::*;

/// Store product identifiers — must match the stores and the Flutter client.
pub const PRODUCT_MONTHLY: &str = "secretly_premium_monthly";
pub const PRODUCT_YEARLY: &str = "secretly_premium_yearly";
pub const PRODUCT_LIFETIME: &str = "secretly_premium_life";

/// A receipt that has been cryptographically verified against the store.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedPurchase {
    /// Opaque store transaction id — the dedup key (UNIQUE per entitlement). No PII.
    pub store_tx_id: String,
    /// "premium" | "lifetime" | "free" (free when the receipt is revoked/expired).
    pub tier: &'static str,
    /// "appstore" | "play".
    pub source: &'static str,
    /// Subscription expiry (epoch ms); None for lifetime / non-expiring.
    pub expires_at_ms: Option<i64>,
}

/// Maps a store product id to `(tier, is_subscription)`. Unknown id → None (reject).
pub fn tier_for_product(product_id: &str) -> Option<(&'static str, bool)> {
    match product_id {
        PRODUCT_MONTHLY | PRODUCT_YEARLY => Some(("premium", true)),
        PRODUCT_LIFETIME => Some(("lifetime", false)),
        _ => None,
    }
}

/// Verification failure. The `/redeem` handler maps these to 4xx and never grants.
#[derive(Debug)]
pub enum VerifyError {
    NotConfigured(&'static str),
    Malformed(String),
    Untrusted(String),
    Network(String),
    UnknownProduct(String),
}

impl std::fmt::Display for VerifyError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            VerifyError::NotConfigured(s) => write!(f, "verification not configured: {s}"),
            VerifyError::Malformed(s) => write!(f, "malformed receipt: {s}"),
            VerifyError::Untrusted(s) => write!(f, "untrusted receipt: {s}"),
            VerifyError::Network(s) => write!(f, "store api error: {s}"),
            VerifyError::UnknownProduct(s) => write!(f, "unknown product: {s}"),
        }
    }
}

// ── Config (loaded from env; absent → that platform's redeem fails closed) ────

#[derive(Deserialize, Clone)]
pub struct PlayServiceAccount {
    pub client_email: String,
    pub private_key: String,
    #[serde(default = "default_token_uri")]
    pub token_uri: String,
}

fn default_token_uri() -> String {
    "https://oauth2.googleapis.com/token".to_string()
}

/// 13.11.2026: покупки из песочницы Apple (TestFlight, тестовые сборки
/// владельца) подписаны тем же корнем Apple, что и настоящие. По умолчанию
/// `Allow` — как было до сих пор, владелец проверяет ими покупки; `Deny`
/// оператор включает сам, когда тесты на проде больше не нужны.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum AppStoreSandboxPolicy {
    #[default]
    Allow,
    Deny,
}

impl AppStoreSandboxPolicy {
    /// Только явное `deny` запрещает; пусто или опечатка — `Allow`, чтобы
    /// ошибка в настройке не отняла у людей купленное.
    pub fn parse(raw: Option<&str>) -> Self {
        match raw.map(|s| s.trim().to_ascii_lowercase()) {
            Some(ref v) if v == "deny" => AppStoreSandboxPolicy::Deny,
            _ => AppStoreSandboxPolicy::Allow,
        }
    }
}

#[derive(Clone, Default)]
pub struct BillingVerifyConfig {
    pub appstore_bundle_id: Option<String>,
    pub apple_root_der: Option<Vec<u8>>,
    pub appstore_sandbox: AppStoreSandboxPolicy,
    /// `true` только при `SECRETLY_BILLING_APPSTORE_CHAIN_OIDS=enforce`.
    pub appstore_enforce_chain_oids: bool,
    pub play_package: Option<String>,
    pub play_sa: Option<PlayServiceAccount>,
}

fn env_nonempty(key: &str) -> Option<String> {
    std::env::var(key)
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

fn load_play_sa(raw: &str) -> Option<PlayServiceAccount> {
    let json = if raw.trim_start().starts_with('{') {
        raw.to_string()
    } else {
        std::fs::read_to_string(raw).ok()?
    };
    serde_json::from_str(&json).ok()
}

impl BillingVerifyConfig {
    pub fn from_env() -> Self {
        BillingVerifyConfig {
            appstore_bundle_id: env_nonempty("SECRETLY_APPSTORE_BUNDLE_ID"),
            apple_root_der: env_nonempty("SECRETLY_APPSTORE_ROOT_CERT_DER_B64").and_then(|b| {
                base64::engine::general_purpose::STANDARD
                    .decode(b.trim())
                    .ok()
            }),
            appstore_sandbox: AppStoreSandboxPolicy::parse(
                env_nonempty("SECRETLY_BILLING_APPSTORE_SANDBOX").as_deref(),
            ),
            appstore_enforce_chain_oids: env_nonempty("SECRETLY_BILLING_APPSTORE_CHAIN_OIDS")
                .map(|v| v.trim().eq_ignore_ascii_case("enforce"))
                .unwrap_or(false),
            play_package: env_nonempty("SECRETLY_PLAY_PACKAGE"),
            play_sa: env_nonempty("SECRETLY_PLAY_SERVICE_ACCOUNT_JSON")
                .and_then(|raw| load_play_sa(&raw)),
        }
    }
}

// ── App Store: StoreKit2 signed-transaction JWS verification (offline) ────────

#[derive(Deserialize)]
struct AppStorePayload {
    #[serde(rename = "bundleId")]
    bundle_id: Option<String>,
    #[serde(rename = "productId")]
    product_id: String,
    #[serde(rename = "transactionId")]
    transaction_id: String,
    #[serde(rename = "originalTransactionId")]
    original_transaction_id: Option<String>,
    #[serde(rename = "expiresDate")]
    expires_date: Option<i64>,
    #[serde(rename = "revocationDate")]
    revocation_date: Option<i64>,
    /// "Production" | "Sandbox" | "Xcode" | "LocalTesting".
    environment: Option<String>,
}

/// 13.11.2026: OID расширений из требований Apple к проверке JWS StoreKit 2.
/// Без них к корню G3 сводится любой сертификат от Apple WWDR, в том числе
/// обычный сертификат разработчика, ключ которого есть у любого разработчика.
const APPLE_OID_RECEIPT_SIGNING_LEAF: &str = "1.2.840.113635.100.6.11.1";
const APPLE_OID_WWDR_INTERMEDIATE: &str = "1.2.840.113635.100.6.2.1";

/// Что не так с цепочкой x5c по правилам Apple, или `None`.
fn app_store_chain_oid_violation(certs: &[X509Certificate]) -> Option<&'static str> {
    if certs.len() != 3 {
        return Some("x5c chain is not leaf/intermediate/root");
    }
    if !has_extension_oid(&certs[0], APPLE_OID_RECEIPT_SIGNING_LEAF) {
        return Some("leaf lacks App Store receipt-signing OID");
    }
    if !has_extension_oid(&certs[1], APPLE_OID_WWDR_INTERMEDIATE) {
        return Some("intermediate lacks Apple WWDR OID");
    }
    None
}

fn has_extension_oid(cert: &X509Certificate, oid: &str) -> bool {
    cert.extensions()
        .iter()
        .any(|e| e.oid.to_id_string() == oid)
}

/// Verifies a StoreKit2 signed transaction JWS:
///  1. ES256 signature over header.payload using the leaf cert's key,
///  2. x5c chain leaf←intermediate←root with the root pinned to Apple's root,
///  3. certificate validity windows,
///  4. Apple OIDs on leaf and intermediate,
///  5. bundleId present and matching,
///  6. environment against `sandbox` policy,
/// then maps productId → tier. A revoked/refunded receipt resolves to `free`.
pub fn verify_app_store_jws(
    jws: &str,
    expected_bundle_id: &str,
    apple_root_der: &[u8],
    sandbox: AppStoreSandboxPolicy,
) -> Result<VerifiedPurchase, VerifyError> {
    verify_app_store_jws_with(jws, expected_bundle_id, apple_root_der, sandbox, true)
}

/// То же, но проверку OID цепочки можно перевести в «только журнал»
/// (`enforce_chain_oids = false`). 13.11.2026: настоящего чека Apple в тестах
/// нет — проверка сверена с документацией и библиотекой Apple, но не с живой
/// покупкой. Ошибка здесь = человек заплатил и не получил Premium, поэтому на
/// проде сначала журнал (`SECRETLY_BILLING_APPSTORE_CHAIN_OIDS` пусто или
/// `warn`), после первых настоящих покупок без предупреждения — `enforce`.
pub fn verify_app_store_jws_with(
    jws: &str,
    expected_bundle_id: &str,
    apple_root_der: &[u8],
    sandbox: AppStoreSandboxPolicy,
    enforce_chain_oids: bool,
) -> Result<VerifiedPurchase, VerifyError> {
    let header = jsonwebtoken::decode_header(jws)
        .map_err(|e| VerifyError::Malformed(format!("header: {e}")))?;
    if header.alg != Algorithm::ES256 {
        return Err(VerifyError::Untrusted("alg != ES256".into()));
    }
    let x5c = header
        .x5c
        .ok_or_else(|| VerifyError::Untrusted("missing x5c".into()))?;
    if x5c.len() < 2 {
        return Err(VerifyError::Untrusted("short x5c chain".into()));
    }

    // x5c entries are STANDARD base64 DER certs ordered [leaf, intermediate, root].
    let der: Vec<Vec<u8>> = x5c
        .iter()
        .map(|b| base64::engine::general_purpose::STANDARD.decode(b))
        .collect::<Result<_, _>>()
        .map_err(|e| VerifyError::Malformed(format!("x5c b64: {e}")))?;
    let certs: Vec<X509Certificate> = der
        .iter()
        .map(|d| X509Certificate::from_der(d).map(|(_, c)| c))
        .collect::<Result<_, _>>()
        .map_err(|e| VerifyError::Malformed(format!("x5c der: {e}")))?;

    // Pin: the chain's root (last entry) must byte-equal the configured Apple root.
    if der.last().map(|d| d.as_slice()) != Some(apple_root_der) {
        return Err(VerifyError::Untrusted("chain root is not the pinned Apple root".into()));
    }
    // Each cert must be signed by the next one up the chain.
    for i in 0..certs.len() - 1 {
        certs[i]
            .verify_signature(Some(certs[i + 1].public_key()))
            .map_err(|e| VerifyError::Untrusted(format!("chain link {i}: {e}")))?;
    }
    // Validity windows.
    for c in &certs {
        if !c.validity().is_valid() {
            return Err(VerifyError::Untrusted("certificate expired or not yet valid".into()));
        }
    }
    // 13.11.2026: у Apple цепочка всегда из трёх [лист, WWDR, корень G3] —
    // так же проверяет их app-store-server-library. Лист обязан быть
    // сертификатом подписи покупок, промежуточный — WWDR.
    if let Some(why) = app_store_chain_oid_violation(&certs) {
        if enforce_chain_oids {
            return Err(VerifyError::Untrusted(why.into()));
        }
        tracing::warn!(
            "billing: App Store chain check would reject ({why}); accepted because SECRETLY_BILLING_APPSTORE_CHAIN_OIDS is not 'enforce'"
        );
    }

    // Verify the JWS ES256 signature with the leaf public key.
    // jsonwebtoken/ring's from_ec_der expects the RAW uncompressed EC point
    // (0x04||X||Y) — i.e. the SubjectPublicKey BIT STRING bytes — NOT the full
    // SubjectPublicKeyInfo DER. Passing `.raw` (SPKI) makes every real Apple JWS
    // fail with InvalidSignature.
    let key = DecodingKey::from_ec_der(&certs[0].public_key().subject_public_key.data);
    let mut validation = Validation::new(Algorithm::ES256);
    validation.required_spec_claims = HashSet::new();
    validation.validate_exp = false;
    validation.validate_aud = false;
    let payload = jsonwebtoken::decode::<AppStorePayload>(jws, &key, &validation)
        .map_err(|e| VerifyError::Untrusted(format!("jws signature: {e}")))?
        .claims;

    // 13.11.2026: в настоящей покупке StoreKit 2 bundleId есть всегда;
    // без него покупку нельзя привязать к нашему приложению.
    match payload.bundle_id.as_deref() {
        Some(b) if b == expected_bundle_id => {}
        Some(_) => return Err(VerifyError::Untrusted("bundleId mismatch".into())),
        None => return Err(VerifyError::Untrusted("missing bundleId".into())),
    }
    let store_tx_id = payload
        .original_transaction_id
        .clone()
        .unwrap_or_else(|| payload.transaction_id.clone());

    if payload.revocation_date.is_some() {
        return Ok(VerifiedPurchase {
            store_tx_id,
            tier: "free",
            source: "appstore",
            expires_at_ms: None,
        });
    }
    let (tier, _is_sub) = tier_for_product(&payload.product_id)
        .ok_or_else(|| VerifyError::UnknownProduct(payload.product_id.clone()))?;
    // 13.11.2026: песочница проверяется только там, где покупка что-то даёт;
    // отзыв выше проходит всегда — он только отнимает. Поле пустое — как
    // раньше, пропускаем: отказ мог бы задеть настоящую покупку.
    if let Some(env) = payload.environment.as_deref() {
        if env != "Production" {
            if sandbox == AppStoreSandboxPolicy::Deny {
                return Err(VerifyError::Untrusted(format!("environment {env} denied")));
            }
            tracing::warn!(
                "billing: App Store {} transaction accepted (product={}, policy=allow) — grants or extends an entitlement",
                env,
                payload.product_id
            );
        }
    }
    Ok(VerifiedPurchase {
        store_tx_id,
        tier,
        source: "appstore",
        expires_at_ms: payload.expires_date,
    })
}

/// Minimal RFC3339 → epoch-ms parser for Google Play `expiryTime` values
/// (e.g. "2026-06-14T10:48:12.000Z" or "2026-06-14T10:48:12Z"). Returns None on
/// anything it doesn't recognize. Self-contained to avoid a date-crate dep.
pub fn rfc3339_to_ms(s: &str) -> Option<i64> {
    let s = s.trim();
    let bytes = s.as_bytes();
    if bytes.len() < 20 || bytes[4] != b'-' || bytes[7] != b'-' || bytes[10] != b'T' {
        return None;
    }
    let year: i64 = s.get(0..4)?.parse().ok()?;
    let month: i64 = s.get(5..7)?.parse().ok()?;
    let day: i64 = s.get(8..10)?.parse().ok()?;
    let hour: i64 = s.get(11..13)?.parse().ok()?;
    let min: i64 = s.get(14..16)?.parse().ok()?;
    let sec: i64 = s.get(17..19)?.parse().ok()?;
    if !(1..=12).contains(&month) || !(1..=31).contains(&day) {
        return None;
    }
    // Days from 1970-01-01 to year-month-day (proleptic Gregorian).
    let days = days_from_civil(year, month, day);
    let total_secs = days * 86_400 + hour * 3600 + min * 60 + sec;
    Some(total_secs * 1000)
}

/// Howard Hinnant's days_from_civil: days since 1970-01-01 (UTC).
fn days_from_civil(y: i64, m: i64, d: i64) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

// ── Google Play: Developer API verification (live; needs the service account) ─

#[derive(Deserialize)]
struct OAuthToken {
    access_token: String,
}

/// Mints a service-account JWT (RS256) and exchanges it for an OAuth access token
/// scoped to the Android Publisher API.
async fn play_access_token(
    http: &reqwest::Client,
    sa: &PlayServiceAccount,
) -> Result<String, VerifyError> {
    let now = crate::now_ms() / 1000;
    let claims = serde_json::json!({
        "iss": sa.client_email,
        "scope": "https://www.googleapis.com/auth/androidpublisher",
        "aud": sa.token_uri,
        "iat": now,
        "exp": now + 3600,
    });
    let key = jsonwebtoken::EncodingKey::from_rsa_pem(sa.private_key.as_bytes())
        .map_err(|e| VerifyError::Untrusted(format!("play service-account key: {e}")))?;
    let header = jsonwebtoken::Header::new(Algorithm::RS256);
    let assertion = jsonwebtoken::encode(&header, &claims, &key)
        .map_err(|e| VerifyError::Untrusted(format!("play assertion: {e}")))?;
    let resp = http
        .post(&sa.token_uri)
        .form(&[
            ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
            ("assertion", assertion.as_str()),
        ])
        .send()
        .await
        .map_err(|e| VerifyError::Network(e.to_string()))?;
    if !resp.status().is_success() {
        return Err(VerifyError::Network(format!("oauth {}", resp.status())));
    }
    let tok: OAuthToken = resp
        .json()
        .await
        .map_err(|e| VerifyError::Network(e.to_string()))?;
    Ok(tok.access_token)
}

/// Verifies a Google Play purchase via the Developer API. Subscriptions use
/// `purchases.subscriptionsv2`; one-time products use `purchases.products`. The
/// opaque `purchase_token` is the dedup id. Inactive/expired/cancelled-and-lapsed
/// or non-purchased → resolves to `free`.
pub async fn verify_play(
    http: &reqwest::Client,
    sa: &PlayServiceAccount,
    package: &str,
    product_id: &str,
    purchase_token: &str,
) -> Result<VerifiedPurchase, VerifyError> {
    let (tier, is_sub) = tier_for_product(product_id)
        .ok_or_else(|| VerifyError::UnknownProduct(product_id.to_string()))?;
    let token = play_access_token(http, sa).await?;
    let base = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";

    if is_sub {
        let url = format!("{base}/{package}/purchases/subscriptionsv2/tokens/{purchase_token}");
        let resp = http
            .get(&url)
            .bearer_auth(&token)
            .send()
            .await
            .map_err(|e| VerifyError::Network(e.to_string()))?;
        if !resp.status().is_success() {
            return Err(VerifyError::Untrusted(format!("play sub {}", resp.status())));
        }
        #[derive(Deserialize)]
        struct LineItem {
            #[serde(rename = "expiryTime")]
            expiry_time: Option<String>,
        }
        #[derive(Deserialize)]
        struct SubV2 {
            #[serde(rename = "subscriptionState")]
            subscription_state: Option<String>,
            #[serde(rename = "lineItems")]
            line_items: Option<Vec<LineItem>>,
        }
        let s: SubV2 = resp
            .json()
            .await
            .map_err(|e| VerifyError::Network(e.to_string()))?;
        // CANCELED is still valid until expiry; expiry is enforced by the client
        // grace logic + the next webhook/redeem.
        let active = matches!(
            s.subscription_state.as_deref(),
            Some("SUBSCRIPTION_STATE_ACTIVE")
                | Some("SUBSCRIPTION_STATE_IN_GRACE_PERIOD")
                | Some("SUBSCRIPTION_STATE_CANCELED")
        );
        let expires_at_ms = s
            .line_items
            .and_then(|li| li.into_iter().find_map(|l| l.expiry_time))
            .and_then(|t| rfc3339_to_ms(&t));
        Ok(VerifiedPurchase {
            store_tx_id: purchase_token.to_string(),
            tier: if active { tier } else { "free" },
            source: "play",
            expires_at_ms,
        })
    } else {
        let url = format!("{base}/{package}/purchases/products/{product_id}/tokens/{purchase_token}");
        let resp = http
            .get(&url)
            .bearer_auth(&token)
            .send()
            .await
            .map_err(|e| VerifyError::Network(e.to_string()))?;
        if !resp.status().is_success() {
            return Err(VerifyError::Untrusted(format!("play product {}", resp.status())));
        }
        #[derive(Deserialize)]
        struct ProductPurchase {
            #[serde(rename = "purchaseState")]
            purchase_state: Option<i64>, // 0 = purchased, 1 = cancelled, 2 = pending
        }
        let p: ProductPurchase = resp
            .json()
            .await
            .map_err(|e| VerifyError::Network(e.to_string()))?;
        Ok(VerifiedPurchase {
            store_tx_id: purchase_token.to_string(),
            tier: if p.purchase_state == Some(0) { tier } else { "free" },
            source: "play",
            expires_at_ms: None,
        })
    }
}

// ── Webhook payload parsing (ASSN V2 + Google RTDN) ───────────────────────────

/// Extracts `data.signedTransactionInfo` (the inner transaction JWS) from an
/// App Store Server Notification V2 outer JWS. The outer signature is NOT
/// trusted here — the caller cryptographically verifies the returned inner JWS
/// (which carries Apple's x5c chain), which is the trust anchor.
pub fn appstore_notification_inner_jws(outer_jws: &str) -> Option<String> {
    let payload_b64 = outer_jws.split('.').nth(1)?;
    let bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD
        .decode(payload_b64)
        .ok()?;
    let v: serde_json::Value = serde_json::from_slice(&bytes).ok()?;
    v.get("data")?
        .get("signedTransactionInfo")?
        .as_str()
        .map(|s| s.to_string())
}

/// A Google Play Real-Time Developer Notification, decoded from `message.data`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RtdnEvent {
    pub purchase_token: String,
    pub product_id: String,
}

/// Parses a Pub/Sub push body `{message:{data: base64(json)}}` into the purchase
/// token + product id (subscription or one-time). None if not a purchase event.
pub fn parse_rtdn(body: &serde_json::Value) -> Option<RtdnEvent> {
    let data_b64 = body.get("message")?.get("data")?.as_str()?;
    let bytes = base64::engine::general_purpose::STANDARD
        .decode(data_b64.trim())
        .ok()?;
    let v: serde_json::Value = serde_json::from_slice(&bytes).ok()?;
    if let Some(sub) = v.get("subscriptionNotification") {
        return Some(RtdnEvent {
            purchase_token: sub.get("purchaseToken")?.as_str()?.to_string(),
            product_id: sub.get("subscriptionId")?.as_str()?.to_string(),
        });
    }
    if let Some(otp) = v.get("oneTimeProductNotification") {
        return Some(RtdnEvent {
            purchase_token: otp.get("purchaseToken")?.as_str()?.to_string(),
            product_id: otp.get("sku")?.as_str()?.to_string(),
        });
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn product_mapping_covers_all_skus() {
        assert_eq!(tier_for_product(PRODUCT_MONTHLY), Some(("premium", true)));
        assert_eq!(tier_for_product(PRODUCT_YEARLY), Some(("premium", true)));
        assert_eq!(tier_for_product(PRODUCT_LIFETIME), Some(("lifetime", false)));
        assert_eq!(tier_for_product("not_a_product"), None);
        assert_eq!(tier_for_product(""), None);
    }

    #[test]
    fn app_store_rejects_garbage_jws() {
        let err = verify_app_store_jws(
            "not.a.jws",
            "com.secretly.messenger",
            b"root",
            AppStoreSandboxPolicy::Allow,
        );
        assert!(matches!(err, Err(VerifyError::Malformed(_))));
    }

    #[test]
    fn rfc3339_parses_known_instants() {
        // 1970-01-01T00:00:00Z == 0
        assert_eq!(rfc3339_to_ms("1970-01-01T00:00:00Z"), Some(0));
        // 2000-01-01T00:00:00Z == 946684800000
        assert_eq!(rfc3339_to_ms("2000-01-01T00:00:00Z"), Some(946_684_800_000));
        // a fractional-seconds suffix is ignored (sub-second precision dropped)
        assert_eq!(
            rfc3339_to_ms("2026-06-14T10:48:12.000Z"),
            rfc3339_to_ms("2026-06-14T10:48:12Z"),
        );
        assert!(rfc3339_to_ms("2026-06-14T10:48:12Z").unwrap() > 0);
        assert_eq!(rfc3339_to_ms("garbage"), None);
        assert_eq!(rfc3339_to_ms(""), None);
    }

    #[test]
    fn parse_rtdn_subscription_and_one_time() {
        let sub = r#"{"subscriptionNotification":{"purchaseToken":"tok123","subscriptionId":"secretly_premium_yearly"}}"#;
        let body = serde_json::json!({
            "message": { "data": base64::engine::general_purpose::STANDARD.encode(sub) }
        });
        let ev = parse_rtdn(&body).expect("sub event");
        assert_eq!(ev.purchase_token, "tok123");
        assert_eq!(ev.product_id, "secretly_premium_yearly");

        let otp = r#"{"oneTimeProductNotification":{"purchaseToken":"tokLife","sku":"secretly_premium_life"}}"#;
        let body = serde_json::json!({
            "message": { "data": base64::engine::general_purpose::STANDARD.encode(otp) }
        });
        assert_eq!(parse_rtdn(&body).unwrap().product_id, "secretly_premium_life");
    }

    #[test]
    fn parse_rtdn_ignores_non_purchase_and_garbage() {
        let test = r#"{"testNotification":{"version":"1.0"}}"#;
        let body = serde_json::json!({
            "message": { "data": base64::engine::general_purpose::STANDARD.encode(test) }
        });
        assert!(parse_rtdn(&body).is_none());
        assert!(parse_rtdn(&serde_json::json!({})).is_none());
    }

    #[test]
    fn appstore_inner_jws_extraction() {
        let payload = r#"{"data":{"signedTransactionInfo":"INNER.JWS.HERE"}}"#;
        let p = base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(payload);
        let outer = format!("aGVhZA.{p}.c2ln");
        assert_eq!(
            appstore_notification_inner_jws(&outer).as_deref(),
            Some("INNER.JWS.HERE")
        );
        assert_eq!(appstore_notification_inner_jws("garbage"), None);
    }

    /// Синтетическая цепочка в форме Apple: корень → промежуточный → лист.
    /// `leaf_oid` / `int_oid` — ставить ли OID Apple на лист и промежуточный.
    struct TestChain {
        root_der: Vec<u8>,
        x5c: Vec<String>,
        leaf_key: rcgen::KeyPair,
    }

    fn apple_like_chain(leaf_oid: bool, int_oid: bool) -> TestChain {
        use rcgen::{BasicConstraints, CertificateParams, CustomExtension, IsCa, KeyPair};
        let b64 = |d: &[u8]| base64::engine::general_purpose::STANDARD.encode(d);
        // Apple кладёт в эти расширения DER NULL.
        let marker = |arc: &[u64]| CustomExtension::from_oid_content(arc, vec![0x05, 0x00]);

        let root_key = KeyPair::generate().unwrap();
        let mut root_params = CertificateParams::new(vec!["Test Root".to_string()]).unwrap();
        root_params.is_ca = IsCa::Ca(BasicConstraints::Unconstrained);
        let root_cert = root_params.self_signed(&root_key).unwrap();

        let int_key = KeyPair::generate().unwrap();
        let mut int_params = CertificateParams::new(vec!["Test WWDR".to_string()]).unwrap();
        int_params.is_ca = IsCa::Ca(BasicConstraints::Unconstrained);
        if int_oid {
            int_params
                .custom_extensions
                .push(marker(&[1, 2, 840, 113635, 100, 6, 2, 1]));
        }
        let int_cert = int_params.signed_by(&int_key, &root_cert, &root_key).unwrap();

        let leaf_key = KeyPair::generate().unwrap();
        let mut leaf_params = CertificateParams::new(vec!["leaf".to_string()]).unwrap();
        if leaf_oid {
            leaf_params
                .custom_extensions
                .push(marker(&[1, 2, 840, 113635, 100, 6, 11, 1]));
        }
        let leaf_cert = leaf_params.signed_by(&leaf_key, &int_cert, &int_key).unwrap();

        TestChain {
            root_der: root_cert.der().to_vec(),
            x5c: vec![
                b64(leaf_cert.der()),
                b64(int_cert.der()),
                b64(root_cert.der()),
            ],
            leaf_key,
        }
    }

    fn sign_tx(chain: &TestChain, x5c: Vec<String>, claims: serde_json::Value) -> String {
        use jsonwebtoken::{Algorithm, EncodingKey, Header};
        let enc = EncodingKey::from_ec_pem(chain.leaf_key.serialize_pem().as_bytes()).unwrap();
        let mut header = Header::new(Algorithm::ES256);
        header.x5c = Some(x5c);
        jsonwebtoken::encode(&header, &claims, &enc).unwrap()
    }

    fn tx_claims(environment: Option<&str>) -> serde_json::Value {
        let mut c = serde_json::json!({
            "bundleId": "com.secretly.messenger",
            "productId": PRODUCT_MONTHLY,
            "transactionId": "2000000000000001",
        });
        if let Some(e) = environment {
            c["environment"] = serde_json::json!(e);
        }
        c
    }

    const ALLOW: AppStoreSandboxPolicy = AppStoreSandboxPolicy::Allow;
    const DENY: AppStoreSandboxPolicy = AppStoreSandboxPolicy::Deny;

    /// Regression for the InvalidSignature bug: build a real ES256 x5c chain
    /// (root → intermediate → leaf, Apple OIDs set), sign a StoreKit2-style JWS
    /// with the leaf key, and assert verify_app_store_jws actually validates the
    /// signature, maps the product to a tier, and rejects a wrong bundle / wrong
    /// pinned root.
    #[test]
    fn app_store_verifies_real_chain_signature() {
        use rcgen::{CertificateParams, KeyPair};
        let chain = apple_like_chain(true, true);
        let jws = sign_tx(&chain, chain.x5c.clone(), tx_claims(Some("Production")));

        let ok = verify_app_store_jws(&jws, "com.secretly.messenger", &chain.root_der, ALLOW)
            .expect("valid chain + signature must verify");
        assert_eq!(ok.tier, "premium");
        assert_eq!(ok.store_tx_id, "2000000000000001");
        // Боевая покупка проходит и при deny.
        assert!(verify_app_store_jws(&jws, "com.secretly.messenger", &chain.root_der, DENY).is_ok());

        // Wrong bundle id → rejected.
        assert!(verify_app_store_jws(&jws, "com.evil.app", &chain.root_der, ALLOW).is_err());

        // Different pinned root → rejected (chain root not pinned).
        let other_key = KeyPair::generate().unwrap();
        let other_root = CertificateParams::new(vec!["Other".to_string()])
            .unwrap()
            .self_signed(&other_key)
            .unwrap();
        let other_der = other_root.der().to_vec();
        assert!(verify_app_store_jws(&jws, "com.secretly.messenger", &other_der, ALLOW).is_err());
    }

    /// 13.11.2026: лист без OID подписи покупок (например, сертификат
    /// разработчика от WWDR) отклоняется, даже если вся цепочка до корня цела.
    #[test]
    fn app_store_rejects_leaf_without_receipt_signing_oid() {
        let chain = apple_like_chain(false, true);
        let jws = sign_tx(&chain, chain.x5c.clone(), tx_claims(Some("Production")));
        let err = verify_app_store_jws(&jws, "com.secretly.messenger", &chain.root_der, ALLOW);
        assert!(matches!(err, Err(VerifyError::Untrusted(ref m)) if m.contains("leaf")));
    }

    #[test]
    fn app_store_rejects_intermediate_without_wwdr_oid() {
        let chain = apple_like_chain(true, false);
        let jws = sign_tx(&chain, chain.x5c.clone(), tx_claims(Some("Production")));
        let err = verify_app_store_jws(&jws, "com.secretly.messenger", &chain.root_der, ALLOW);
        assert!(matches!(err, Err(VerifyError::Untrusted(ref m)) if m.contains("intermediate")));
    }

    /// Режим «только журнал» (по умолчанию на проде до первых живых покупок):
    /// нарушение OID не отказывает, но подпись и закреплённый корень — как
    /// прежде, их режим не ослабляет.
    #[test]
    fn app_store_chain_oids_warn_mode_accepts_but_keeps_root_and_signature() {
        let chain = apple_like_chain(false, false);
        let jws = sign_tx(&chain, chain.x5c.clone(), tx_claims(Some("Production")));
        assert!(verify_app_store_jws_with(
            &jws,
            "com.secretly.messenger",
            &chain.root_der,
            ALLOW,
            false,
        )
        .is_ok());
        assert!(verify_app_store_jws_with(
            &jws,
            "com.secretly.messenger",
            &chain.root_der,
            ALLOW,
            true,
        )
        .is_err());
        let other = apple_like_chain(true, true);
        assert!(verify_app_store_jws_with(
            &jws,
            "com.secretly.messenger",
            &other.root_der,
            ALLOW,
            false,
        )
        .is_err());
    }

    /// Цепочка не из трёх звеньев (лист прямо под корнем) — не форма Apple.
    #[test]
    fn app_store_rejects_two_cert_chain() {
        let chain = apple_like_chain(true, true);
        let short = vec![chain.x5c[0].clone(), chain.x5c[2].clone()];
        let jws = sign_tx(&chain, short, tx_claims(Some("Production")));
        assert!(verify_app_store_jws(&jws, "com.secretly.messenger", &chain.root_der, ALLOW).is_err());
    }

    #[test]
    fn app_store_rejects_missing_bundle_id() {
        let chain = apple_like_chain(true, true);
        let mut claims = tx_claims(Some("Production"));
        claims.as_object_mut().unwrap().remove("bundleId");
        let jws = sign_tx(&chain, chain.x5c.clone(), claims);
        let err = verify_app_store_jws(&jws, "com.secretly.messenger", &chain.root_der, ALLOW);
        assert!(matches!(err, Err(VerifyError::Untrusted(ref m)) if m.contains("missing bundleId")));
    }

    /// Песочница: allow (по умолчанию) — выдаёт как раньше; deny — отказ.
    /// Отзыв из песочницы проходит при любой политике: он только отнимает.
    #[test]
    fn app_store_sandbox_policy() {
        let chain = apple_like_chain(true, true);
        let sandbox = sign_tx(&chain, chain.x5c.clone(), tx_claims(Some("Sandbox")));
        let ok = verify_app_store_jws(&sandbox, "com.secretly.messenger", &chain.root_der, ALLOW)
            .expect("sandbox allowed by default");
        assert_eq!(ok.tier, "premium");
        assert!(verify_app_store_jws(&sandbox, "com.secretly.messenger", &chain.root_der, DENY).is_err());

        let mut revoked = tx_claims(Some("Sandbox"));
        revoked["revocationDate"] = serde_json::json!(1_700_000_000_000i64);
        let revoked = sign_tx(&chain, chain.x5c.clone(), revoked);
        let r = verify_app_store_jws(&revoked, "com.secretly.messenger", &chain.root_der, DENY)
            .expect("revocation passes under deny");
        assert_eq!(r.tier, "free");

        // Поля environment нет — как раньше, пропускаем при любой политике.
        let no_env = sign_tx(&chain, chain.x5c.clone(), tx_claims(None));
        assert!(verify_app_store_jws(&no_env, "com.secretly.messenger", &chain.root_der, DENY).is_ok());
    }

    #[test]
    fn app_store_sandbox_policy_parse() {
        assert_eq!(AppStoreSandboxPolicy::parse(None), ALLOW);
        assert_eq!(AppStoreSandboxPolicy::parse(Some("allow")), ALLOW);
        assert_eq!(AppStoreSandboxPolicy::parse(Some(" DENY ")), DENY);
        assert_eq!(AppStoreSandboxPolicy::parse(Some("dney")), ALLOW);
        assert_eq!(BillingVerifyConfig::default().appstore_sandbox, ALLOW);
    }
}
