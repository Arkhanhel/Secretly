import FlutterMacOS
import PDFKit

/// ПОКАЗ PDF ВНУТРИ ОКНА.
///
/// 🔴 ЗАЧЕМ СВОЙ ПРОСМОТР. Полученный файл открывался чужой программой, а это
/// значит: расшифрованный документ уходит другому приложению, попадает в его
/// список недавних и в его кэш. Для переписки, которая шифруется от начала до
/// конца, это самое слабое место пути.
///
/// 🔴 ПОЧЕМУ СИСТЕМОЙ, А НЕ БИБЛИОТЕКОЙ. Библиотека для PDF потянула бы за
/// собой движок вроде pdfium — десятки мегабайт В КАЖДОЙ сборке, включая
/// мобильную, а она выпущена и заморожена. PDFKit уже есть в macOS: ни веса,
/// ни новой зависимости, ни влияния на телефон.
///
/// Страницы рисуются по одной, по запросу: документ на пятьсот страниц не
/// должен занимать память целиком.
final class PdfRenderBridge {
  private var channel: FlutterMethodChannel?
  private let queue = DispatchQueue(
    label: "secretly.pdf_render",
    qos: .userInitiated
  )

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "secretly/pdf_render",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      guard let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(FlutterError(code: "bad_args", message: nil, details: nil))
        return
      }
      switch call.method {
      case "info":
        self.queue.async {
          let pages = PdfRenderBridge.pageCount(path: path)
          DispatchQueue.main.async { result(pages) }
        }
      case "render":
        let page = (args["page"] as? NSNumber)?.intValue ?? 0
        let maxWidth = (args["maxWidth"] as? NSNumber)?.doubleValue ?? 1200
        self.queue.async {
          let data = PdfRenderBridge.render(
            path: path,
            page: page,
            maxWidth: maxWidth
          )
          DispatchQueue.main.async {
            result(data.map { FlutterStandardTypedData(bytes: $0) })
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Сколько страниц в документе; `nil` — файл не читается как PDF.
  private static func pageCount(path: String) -> Int? {
    guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else {
      return nil
    }
    return doc.pageCount
  }

  /// Страница [page] (с нуля) картинкой PNG шириной не больше [maxWidth].
  ///
  /// Ширину ограничиваем: страница плаката в натуральную величину — это
  /// сотни мегабайт пикселей на ровном месте.
  private static func render(
    path: String,
    page: Int,
    maxWidth: Double
  ) -> Data? {
    guard let doc = PDFDocument(url: URL(fileURLWithPath: path)),
      page >= 0,
      page < doc.pageCount,
      let pdfPage = doc.page(at: page)
    else {
      return nil
    }
    let box = pdfPage.bounds(for: .cropBox)
    guard box.width > 0, box.height > 0 else { return nil }
    let limit = max(200.0, min(maxWidth, 3000.0))
    let scale = min(limit / box.width, 4.0)
    let size = NSSize(
      width: max(1, box.width * scale),
      height: max(1, box.height * scale)
    )
    let image = pdfPage.thumbnail(of: size, for: .cropBox)
    guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
    else {
      return nil
    }
    return png
  }
}
