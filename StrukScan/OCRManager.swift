//  OCRManager.swift
//  StrukScan

import UIKit

class OCRManager {

    static let shared = OCRManager()
    private init() {}

    // MARK: - Public

    func recognize(image: UIImage,
                   completion: @escaping (String, [ReceiptItem], Int) -> Void) {

        Task {
            do {
                let result = try await uploadReceipt(image: image)
                print("=== OCR RESULT ===")
                print(result)
                print("==================")

                let lines = result.components(separatedBy: "\n")
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                let (storeName, items, total) = parseReceipt(lines: lines)

                await MainActor.run {
                    completion(storeName, items, total)
                }
            } catch {
                print("OCR error: \(error)")
                await MainActor.run {
                    completion("", [], 0)
                }
            }
        }
    }

    // MARK: - API Call

    private func uploadReceipt(image: UIImage) async throws -> String {
        let url = URL(string: "https://surya2212-paddleocrreceipt.hf.space/ocr")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120

        let boundary = UUID().uuidString
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        let imageData: Data
        let fileName: String
        let mimeType: String

        if let pngData = image.pngData() {
            imageData = pngData
            fileName  = "receipt.png"
            mimeType  = "image/png"
        } else if let jpegData = image.jpegData(compressionQuality: 0.8) {
            imageData = jpegData
            fileName  = "receipt.jpg"
            mimeType  = "image/jpeg"
        } else {
            throw NSError(domain: "ImageEncoding", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Gagal encode gambar"])
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else { throw URLError(.badServerResponse) }

        // ← DEBUG PRINT
        let rawString = String(data: data, encoding: .utf8) ?? "nil"
        print("=== RAW API RESPONSE ===")
        print(rawString)
        print("========================")

        // Parse response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let text = json["text"] as? String { return text }
            if let text = json["result"] as? String { return text }
            if let lines = json["lines"] as? [String] { return lines.joined(separator: "\n") }
            if let dataArr = json["data"] as? [[String: Any]] {
                let texts = dataArr.compactMap { $0["text"] as? String }
                return texts.joined(separator: "\n")
            }
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Parsing

    private func parseReceipt(lines: [String])
        -> (storeName: String, items: [ReceiptItem], total: Int) {

        var storeName = ""
        var items: [ReceiptItem] = []
        var total = 0

        let pricePattern = try? NSRegularExpression(
            pattern: "(\\d{1,3}(?:[.,]\\d{3})*|\\d{4,})")

        let skipKeywords = [
            "subtotal", "payment", "bayar", "kembalian",
            "tax", "pajak", "ppn", "service", "charge",
            "thank", "terima", "kasih", "struk", "nota",
            "receipt", "debit", "kredit", "cash", "tunai",
            "void", "closed", "npwp", "www", "http", "@",
            "telp", "tel:", "no.", "check", "invoice",
            "jl.", "jalan", "ruko", "plaza", "mall"
        ]

        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower   = trimmed.lowercased()
            guard !trimmed.isEmpty else { continue }

            if storeName.isEmpty && idx < 4 {
                let hasPrice = pricePattern?.firstMatch(
                    in: trimmed,
                    range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
                let isSkip = skipKeywords.contains(where: { lower.contains($0) })
                if !hasPrice && !isSkip {
                    storeName = trimmed
                    continue
                }
            }

            if lower.contains("total") && !lower.contains("subtotal") {
                if let price = extractPrice(from: trimmed, pattern: pricePattern),
                   price > total {
                    total = price
                }
                continue
            }

            if skipKeywords.contains(where: { lower.contains($0) }) { continue }

            if let price = extractPrice(from: trimmed, pattern: pricePattern),
               price >= 500 {
                let priceStr = formatNumber(price)
                var nama = trimmed
                if let range = trimmed.range(of: priceStr) {
                    nama = String(trimmed[..<range.lowerBound])
                        .trimmingCharacters(in: .whitespaces)
                }
                nama = nama.replacingOccurrences(
                    of: "^[\\d\\s\\-\\.\\,\\*\\/]+",
                    with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)

                if !nama.isEmpty && nama.count >= 2 {
                    items.append(ReceiptItem(nama: nama, harga: price))
                }
            }
        }

        if total == 0 && !items.isEmpty {
            total = items.reduce(0) { $0 + $1.harga }
        }

        return (storeName, items, total)
    }

    private func extractPrice(from text: String,
                               pattern: NSRegularExpression?) -> Int? {
        guard let pattern else { return nil }
        let matches = pattern.matches(
            in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { m -> Int? in
            guard let r = Range(m.range, in: text) else { return nil }
            return Int(text[r]
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ""))
        }.max()
    }

    private func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.groupingSeparator = "."
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
