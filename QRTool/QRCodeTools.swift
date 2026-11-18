import UIKit
import CoreImage

enum QRCodeTools {
    static func qrImage(for string: String, size: CGFloat) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// One collage image per document: a grid of QR codes, each labelled
    /// with the tail of its URL (the box code) underneath.
    static func collageImage(urls: [String]) -> UIImage? {
        guard !urls.isEmpty else { return nil }
        let columns: Int
        let qrSize: CGFloat
        switch urls.count {
        case 1...4:
            columns = 2; qrSize = 220
        case 5...9:
            columns = 3; qrSize = 220
        case 10...16:
            columns = 4; qrSize = 200
        case 17...25:
            columns = 5; qrSize = 180
        case 26...49:
            columns = 6; qrSize = 160
        default:
            columns = 7; qrSize = 140
        }
        let labelHeight: CGFloat = max(24, qrSize * 0.16)
        let padding: CGFloat = 20
        let gap: CGFloat = 12
        let rows = (urls.count + columns - 1) / columns
        let cellW = qrSize + gap
        let cellH = qrSize + labelHeight + gap
        let width = padding * 2 + CGFloat(columns) * cellW - gap
        let height = padding * 2 + CGFloat(rows) * cellH - gap
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: width, height: height)))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .regular),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]
            for (index, url) in urls.enumerated() {
                let col = index % columns
                let row = index / columns
                let x = padding + CGFloat(col) * cellW
                let y = padding + CGFloat(row) * cellH
                if let qr = qrImage(for: url, size: qrSize) {
                    qr.draw(in: CGRect(x: x, y: y, width: qrSize, height: qrSize))
                }
                let labelRect = CGRect(x: x, y: y + qrSize + 4, width: qrSize, height: labelHeight)
                (tail(of: url) as NSString).draw(in: labelRect, withAttributes: attrs)
            }
        }
    }

    static func tail(of url: String) -> String {
        let parts = url.split(separator: "/")
        let last = parts.last.map(String.init) ?? url
        return last.count > 16 ? String(last.suffix(16)) : last
    }
}
