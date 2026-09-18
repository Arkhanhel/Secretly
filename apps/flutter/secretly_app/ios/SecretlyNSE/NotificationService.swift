//
//  NotificationService.swift
//  SecretlyNSE
//
//  DELIVERY-WAKE FIX (2026-07-17): Notification Service Extension. iOS in deep
//  sleep does not wake the app for a background push, so messages sit on the
//  relay until the user opens the app (proven in prod logs: 0 background drains
//  overnight). The NSE is the reliable fix — iOS launches it for EVERY alert
//  push (server sends mutable-content:1) and grants ~30s. Here we FETCH the
//  pending mailbox and STAGE the ciphertexts into the shared App Group
//  container; the Flutter app imports and applies them the instant it opens —
//  so the chat is already populated even after a full night asleep.
//
//  DESIGN: fetch-and-stage, NOT decrypt. The NSE never advances the ratchet or
//  acks — it only downloads and writes ciphertexts to a file the app imports
//  into its quarantine store (the existing replay driver applies them). This
//  is the exact model of the Android background fetcher, so cross-process
//  crypto races are impossible.
//
//  AUTH: the app mirrors device_id / profile_id / base_url / identity signing
//  seed into the App Group (see AppDelegate.syncNseConfig). The NSE signs
//  GET /v1/pending with Ed25519 (CryptoKit) exactly like the Dart client
//  (AuthSigner.relayHttpPendingMessage) — no dependency on flutter_secure_
//  storage's internal keychain layout.

import CryptoKit
import UserNotifications

private let kAppGroup = "group.com.secretly.messenger"
private let kStagedInboxFile = "nse_staged_inbox.jsonl"

// Поправка часов (17.09.2026). Зеркало Dart `ServerClock` +
// `sendSignedWithClockRetry`: сервер отвергает метку, разошедшуюся с его
// часами больше чем на 5 минут, а расширение подписывало сырым временем
// устройства — у человека со сбитыми часами каждый пуш будил расширение впустую.
private let kClockOffsetKey = "nse_clock_offset_ms"
private let kStampTrustedDriftMs = 4 * 60 * 1000
private let kMinMeaningfulSkewMs = 10 * 1000
private let kMaxTrustedSkewMs = 7 * 24 * 60 * 60 * 1000
// Повтор — только если отказ пришёл быстро: у расширения ~30 с на всё.
private let kRetryOnlyWithinSec: TimeInterval = 10

class NotificationService: UNNotificationServiceExtension {

  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?
  private let deliverLock = NSLock()
  private var delivered = false

  /// Баннер отдаётся системе ровно один раз — и при истечении времени, и при
  /// позднем ответе сервера (повтор после отказа по времени делает поздний
  /// ответ вероятнее).
  private func deliverOnce(_ content: UNNotificationContent) {
    deliverLock.lock()
    let first = !delivered
    delivered = true
    deliverLock.unlock()
    if first { contentHandler?(content) }
  }

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttemptContent =
      (request.content.mutableCopy() as? UNMutableNotificationContent)

    // Try to fetch+stage the mailbox within the NSE budget. Whatever happens,
    // we always deliver the banner (never swallow the notification).
    fetchAndStage { [weak self] _ in
      guard let self = self else { return }
      if let best = self.bestAttemptContent {
        // Badge policy: DO NOT touch `best.badge`. The relay already puts an
        // accurate `aps.badge` in the push (it counts only real undelivered
        // chat messages, excluding receipts / session-heal / self-mirror /
        // control envelopes). The NSE cannot decrypt, so it can't tell a
        // room's control envelope or a self-mirror copy from a user message —
        // counting staged ciphertexts over-counted (2 messages showed as 5)
        // and accumulated across wakes. We keep the relay's value and let the
        // foreground app reconcile to the exact unread total on next open.
        self.deliverOnce(best)
      } else {
        self.deliverOnce(request.content)
      }
    }
  }

  override func serviceExtensionTimeWillExpire() {
    // iOS is about to kill us — deliver the best attempt (banner) so the push
    // is never lost even if the fetch didn't finish.
    if let best = bestAttemptContent {
      deliverOnce(best)
    }
  }

  // MARK: - Fetch + stage

  private func fetchAndStage(completion: @escaping (Int) -> Void) {
    let defaults = UserDefaults(suiteName: kAppGroup)
    guard
      let deviceId = defaults?.string(forKey: "nse_device_id"),
      let profileId = defaults?.string(forKey: "nse_profile_id"),
      let baseUrl = defaults?.string(forKey: "nse_base_url"),
      let seedB64 = defaults?.string(forKey: "nse_identity_seed_b64"),
      !deviceId.isEmpty, !profileId.isEmpty, !baseUrl.isEmpty, !seedB64.isEmpty,
      let seed = Data(base64Encoded: seedB64),
      let signingKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: seed),
      let base = URL(string: baseUrl)
    else {
      completion(0)
      return
    }

    let storedSeq = defaults?.integer(forKey: "nse_next_seq") ?? 1
    let effectiveFromSeq = storedSeq > 0 ? storedSeq : 1
    // Поправка, выученная прошлым проходом; без неё — ноль (время устройства).
    let offsetMs = defaults?.integer(forKey: kClockOffsetKey) ?? 0
    fetchPending(
      base: base,
      deviceId: deviceId,
      fromSeq: effectiveFromSeq,
      signingKey: signingKey,
      offsetMs: offsetMs,
      mayRetry: true,
      startedAt: Date(),
      completion: completion
    )
  }

  private func fetchPending(
    base: URL,
    deviceId: String,
    fromSeq effectiveFromSeq: Int,
    signingKey: Curve25519.Signing.PrivateKey,
    offsetMs: Int,
    mayRetry: Bool,
    startedAt: Date,
    completion: @escaping (Int) -> Void
  ) {
    let limit = 200
    let tsMs = Int(Date().timeIntervalSince1970 * 1000) + offsetMs
    let nonceB64 = randomNonceB64()

    // Canonical must match AuthSigner.relayHttpPendingMessage EXACTLY.
    let canonical =
      "SECRETLY-RELAY-HTTP-PENDING-V1\n"
      + "device_id=\(deviceId)\n"
      + "from_seq=\(effectiveFromSeq)\n"
      + "limit=\(limit)\n"
      + "ts_ms=\(tsMs)\n"
      + "nonce_b64=\(nonceB64)\n"
    guard let sig = try? signingKey.signature(for: Data(canonical.utf8)) else {
      completion(0)
      return
    }
    let sigB64 = sig.base64EncodedString()

    var comps = URLComponents(
      url: base.appendingPathComponent("/v1/pending/\(deviceId)"),
      resolvingAgainstBaseURL: false
    )
    comps?.queryItems = [
      URLQueryItem(name: "from_seq", value: String(effectiveFromSeq)),
      URLQueryItem(name: "limit", value: String(limit)),
    ]
    guard let url = comps?.url else {
      completion(0)
      return
    }

    var req = URLRequest(url: url)
    req.httpMethod = "GET"
    // Повтор идёт после первого ответа — бюджет расширения (~30 с) не резиновый.
    req.timeoutInterval = mayRetry ? 22 : 8
    req.setValue(deviceId, forHTTPHeaderField: "x-secretly-device-id")
    req.setValue(String(tsMs), forHTTPHeaderField: "x-secretly-ts-ms")
    req.setValue(nonceB64, forHTTPHeaderField: "x-secretly-nonce-b64")
    req.setValue(sigB64, forHTTPHeaderField: "x-secretly-signature-b64")
    // Замер раскатки (22.08.2026). На iOS почтовый ящик часто выкачивает ЭТО
    // расширение, а не приложение, и до сих пор оно не называло сборку — такие
    // устройства попадали в графу «версии нет», по которой невозможно отличить
    // необновившегося от обычного пользователя на свежей сборке. Решение о
    // раскатке рукопожатия упиралось ровно в это.
    //
    // Расширение собирается с тем же CURRENT_PROJECT_VERSION, что и приложение
    // (проверено в собранном IPA), так что номер здесь — номер сборки приложения.
    // Заголовок вне подписи и ни на что, кроме счётчика, не влияет.
    if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
       !build.isEmpty {
      req.setValue(build, forHTTPHeaderField: "x-secretly-client-build")
    }

    let task = URLSession.shared.dataTask(with: req) { [weak self] data, resp, _ in
      guard let self = self, let http = resp as? HTTPURLResponse else {
        completion(0)
        return
      }
      // Отказ по времени: запоминаем поправку из `Date` и повторяем один раз.
      if http.statusCode == 401, mayRetry,
        Date().timeIntervalSince(startedAt) < kRetryOnlyWithinSec,
        let learned = self.clockOffset(from: http, signedTsMs: tsMs)
      {
        UserDefaults(suiteName: kAppGroup)?.set(learned, forKey: kClockOffsetKey)
        self.fetchPending(
          base: base,
          deviceId: deviceId,
          fromSeq: effectiveFromSeq,
          signingKey: signingKey,
          offsetMs: learned,
          mayRetry: false,
          startedAt: startedAt,
          completion: completion
        )
        return
      }
      guard
        (200..<300).contains(http.statusCode),
        let data = data,
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let items = json["items"] as? [[String: Any]]
      else {
        completion(0)
        return
      }
      let staged = self.stage(items: items, appGroup: kAppGroup)
      completion(staged)
    }
    task.resume()
  }

  /// Поправка часов из заголовка `Date` ответа 401 — или nil, если отказ не
  /// про время (метка сошлась с сервером) или сдвиг больше недели.
  private func clockOffset(from http: HTTPURLResponse, signedTsMs: Int) -> Int? {
    guard
      let raw = http.value(forHTTPHeaderField: "Date"),
      let serverDate = Self.httpDateFormatter.date(from: raw)
    else { return nil }
    let serverMs = Int(serverDate.timeIntervalSince1970 * 1000)
    guard abs(signedTsMs - serverMs) > kStampTrustedDriftMs else { return nil }
    let skew = serverMs - Int(Date().timeIntervalSince1970 * 1000)
    guard abs(skew) <= kMaxTrustedSkewMs else { return nil }
    return abs(skew) < kMinMeaningfulSkewMs ? 0 : skew
  }

  private static let httpDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "GMT")
    f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    return f
  }()

  /// Append one JSON line per pending item to the shared staging file. The app
  /// reads and clears this on launch and imports into its quarantine store.
  /// Deliberately no ack / no cursor write — the relay keeps every row until
  /// the MAIN app durably applies + acks it, so a wasted fetch loses nothing.
  private func stage(items: [[String: Any]], appGroup: String) -> Int {
    guard
      !items.isEmpty,
      let dir = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroup)
    else { return 0 }

    let fileURL = dir.appendingPathComponent(kStagedInboxFile)
    var lines = ""
    var count = 0
    for it in items {
      guard
        let msgId = it["msg_id"] as? String,
        let cipher = it["ciphertext_b64"] as? String,
        !msgId.isEmpty, !cipher.isEmpty
      else { continue }
      var obj: [String: Any] = ["msg_id": msgId, "ciphertext_b64": cipher]
      // ИД-1 / С-1 (17.09.2026): the relay's word on who sent it.
      if let from = it["from_device_id"] as? String, !from.isEmpty {
        obj["from_device_id"] = from
      }
      if let d = try? JSONSerialization.data(withJSONObject: obj),
        let s = String(data: d, encoding: .utf8)
      {
        lines += s + "\n"
        count += 1
      }
    }
    if count == 0 { return 0 }

    // Append (multiple pushes during one sleep accumulate; the app dedups by
    // msg_id via inbox_seen when importing).
    if FileManager.default.fileExists(atPath: fileURL.path),
      let handle = try? FileHandle(forWritingTo: fileURL)
    {
      handle.seekToEndOfFile()
      handle.write(Data(lines.utf8))
      try? handle.close()
    } else {
      try? Data(lines.utf8).write(to: fileURL, options: .atomic)
    }

    // Badge is owned by the relay's `aps.badge` (accurate) + the foreground
    // app's exact reconcile — the NSE deliberately does NOT track a count here.
    return count
  }

  private func randomNonceB64() -> String {
    var bytes = [UInt8](repeating: 0, count: 16)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    return Data(bytes).base64EncodedString()
  }
}
