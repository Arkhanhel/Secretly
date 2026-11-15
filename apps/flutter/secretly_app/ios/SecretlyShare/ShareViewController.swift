// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

import UIKit
import UniformTypeIdentifiers

/// «Поделиться → Secretly» (разбор медиа О8, 15.11.2026).
///
/// Расширение ничего не шифрует и никуда не отправляет: оно только копирует
/// то, чем поделились, в общую папку группы приложений
/// (`ShareInbox/<id>/` + `manifest.json`) и открывает Secretly. Само
/// приложение на переднем плане забирает папку и показывает тот же выбор
/// чата, что на Android (`secretly/share_intents`). Ключей, переписки и
/// сети у расширения нет — так меньше того, что может утечь.
final class ShareViewController: UIViewController {
  private let groupId = "group.com.secretly.messenger"
  private let label = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.96)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.numberOfLines = 0
    label.textAlignment = .center
    label.font = .preferredFont(forTextStyle: .headline)
    label.text = NSLocalizedString("share.preparing", value: "Secretly…", comment: "")
    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
    ])
    Task { await handle() }
  }

  private func handle() async {
    let fm = FileManager.default
    guard let items = extensionContext?.inputItems as? [NSExtensionItem],
      let root = fm.containerURL(forSecurityApplicationGroupIdentifier: groupId)
    else {
      finish()
      return
    }
    let id = UUID().uuidString
    let dir = root.appendingPathComponent("ShareInbox", isDirectory: true)
      .appendingPathComponent(id, isDirectory: true)
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

    var files: [[String: String]] = []
    var texts: [String] = []
    for item in items {
      for provider in item.attachments ?? [] {
        if let file = await copyFile(provider, into: dir, index: files.count) {
          files.append(file)
        } else if let text = await loadText(provider) {
          texts.append(text)
        }
      }
    }
    if files.isEmpty && texts.isEmpty {
      try? fm.removeItem(at: dir)
      finish()
      return
    }
    let manifest: [String: Any] = [
      "files": files,
      "text": texts.joined(separator: "\n"),
      "created_at_ms": Int(Date().timeIntervalSince1970 * 1000),
    ]
    if let data = try? JSONSerialization.data(withJSONObject: manifest) {
      try? data.write(to: dir.appendingPathComponent("manifest.json"), options: .atomic)
    }
    if openHostApp(URL(string: "secretly://share-inbox")!) {
      finish()
    } else {
      // iOS не дал открыть приложение из расширения — файлы ждут в папке и
      // будут забраны, как только Secretly откроют.
      label.text = NSLocalizedString(
        "share.openApp",
        value: "Готово. Откройте Secretly, чтобы выбрать чат.",
        comment: ""
      )
      try? await Task.sleep(nanoseconds: 1_600_000_000)
      finish()
    }
  }

  private func finish() {
    extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
  }

  /// Файл (снимок, ролик, документ) — копия в папку с исходным именем.
  /// Ссылка на страницу и простой текст — не файлы: вернёт `nil`.
  private func copyFile(
    _ provider: NSItemProvider,
    into dir: URL,
    index: Int
  ) async -> [String: String]? {
    let preferred: [UTType] = [.movie, .image, .pdf, .fileURL, .data]
    guard
      let type = preferred.first(where: { t in
        provider.registeredTypeIdentifiers.contains { id in
          guard let u = UTType(id) else { return false }
          // Ссылка на страницу (public.url без файла) и текст — не файл.
          if u.conforms(to: .url) && !u.conforms(to: .fileURL) { return false }
          if u.conforms(to: .plainText) { return false }
          return u.conforms(to: t)
        }
      })
    else { return nil }
    return await withCheckedContinuation { cont in
      _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
        guard let url else {
          cont.resume(returning: nil)
          return
        }
        let original = provider.suggestedName.flatMap { name -> String? in
          let ext = url.pathExtension
          if name.contains(".") || ext.isEmpty { return name }
          return "\(name).\(ext)"
        } ?? url.lastPathComponent
        let safe = original.replacingOccurrences(of: "/", with: "_")
        let dest = dir.appendingPathComponent("\(index)_\(safe)")
        do {
          try FileManager.default.copyItem(at: url, to: dest)
        } catch {
          cont.resume(returning: nil)
          return
        }
        let mime = UTType(filenameExtension: dest.pathExtension)?.preferredMIMEType ?? ""
        cont.resume(returning: ["path": dest.path, "name": original, "mime": mime])
      }
    }
  }

  private func loadText(_ provider: NSItemProvider) async -> String? {
    for type in [UTType.url, UTType.plainText] where provider.hasItemConformingToTypeIdentifier(type.identifier) {
      let value: String? = await withCheckedContinuation { cont in
        provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
          if let url = item as? URL {
            cont.resume(returning: url.absoluteString)
          } else if let text = item as? String {
            cont.resume(returning: text)
          } else if let data = item as? Data {
            cont.resume(returning: String(data: data, encoding: .utf8))
          } else {
            cont.resume(returning: nil)
          }
        }
      }
      if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return value
      }
    }
    return nil
  }

  /// Открыть Secretly. Прямого способа у расширения «Поделиться» нет; через
  /// цепочку ответчиков доходим до приложения и зовём его `open` динамически
  /// (iOS 18+), раньше — `openURL:`. Не вышло — `false`, и человек открывает
  /// приложение сам.
  private func openHostApp(_ url: URL) -> Bool {
    var responder: UIResponder? = self
    let modern = NSSelectorFromString("openURL:options:completionHandler:")
    let legacy = NSSelectorFromString("openURL:")
    while let r = responder {
      if r.isKind(of: NSClassFromString("UIApplication")!) {
        if r.responds(to: modern), let imp = r.method(for: modern) {
          typealias OpenFn = @convention(c) (
            AnyObject, Selector, URL, NSDictionary, ((Bool) -> Void)?
          ) -> Void
          let fn = unsafeBitCast(imp, to: OpenFn.self)
          fn(r, modern, url, NSDictionary(), nil)
          return true
        }
        if r.responds(to: legacy) {
          _ = r.perform(legacy, with: url)
          return true
        }
      }
      responder = r.next
    }
    return false
  }
}
