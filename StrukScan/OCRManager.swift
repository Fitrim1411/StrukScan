//  OCRManager.swift
//  StrukScan

import UIKit

class OCRManager {

    static let shared = OCRManager()
    private init() {}

    func recognize(image: UIImage,
                   completion: @escaping (String, [ReceiptItem], Int) -> Void) {
        Task {
            do {
                let (storeName, items, total) = try await uploadAndParse(image: image)
                await MainActor.run { completion(storeName, items, total) }
            } catch {
                print("OCR error: \(error)")
                await MainActor.run { completion("", [], 0) }
            }
        }
    }

    // MARK: - API Call

    private func uploadAndParse(image: UIImage) async throws
        -> (storeName: String, items: [ReceiptItem], total: Int) {

        let url = URL(string: "https://surya2212-paddleocrreceipt.hf.space/ocr")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        let imageData: Data
        let fileName: String
        let mimeType: String

        if let png = image.pngData() {
            imageData = png; fileName = "receipt.png"; mimeType = "image/png"
        } else if let jpg = image.jpegData(compressionQuality: 0.8) {
            imageData = jpg; fileName = "receipt.jpg"; mimeType = "image/jpeg"
        } else {
            throw NSError(domain: "ImageEncoding", code: -1)
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else { throw URLError(.badServerResponse) }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw  = json["raw"] as? [[String: Any]]
        else { return ("", [], 0) }

        let texts = raw.compactMap { item -> String? in
            guard let text  = item["text"]  as? String,
                  let score = item["score"] as? Double,
                  score > 0.5
            else { return nil }
            return text.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }

        print("=== OCR TEXTS ===")
        texts.forEach { print($0) }
        print("=================")

        return parseReceipt(texts: texts)
    }

    // MARK: - Parsing

    private func parseReceipt(texts: [String])
        -> (storeName: String, items: [ReceiptItem], total: Int) {

        var storeName = ""
        var items: [ReceiptItem] = []
        var total = 0

        // Helper: cek apakah string adalah harga (angka dengan koma/titik)
        let isPrice: (String) -> Bool = { s in
            let clean = s.replacingOccurrences(of: ",", with: "")
                         .replacingOccurrences(of: ".", with: "")
            guard let n = Int(clean) else { return false }
            return n >= 500
        }

        let toInt: (String) -> Int? = { s in
            let clean = s.replacingOccurrences(of: ",", with: "")
                         .replacingOccurrences(of: ".", with: "")
            return Int(clean)
        }

        let isSkippable: (String) -> Bool = { s in
            let lower = s.lowercased()
            let skipKeywords = [
                "subtotal", "payment", "debit", "kredit", "tunai",
                "kembali", "kembalian", "bayar", "thank", "please",
                "come again", "pembelian", "gratis", "layanan",
                "konsumen", "www", "http", "jl.", "boulevard",
                "summarecon", "ruko", "plaza", "mall", "pos",
                "check", "closed", "ppn", "dpp", "npwp", "hemat"
            ]
            return skipKeywords.contains(where: { lower.contains($0) })
        }

        let isQtyOrSymbol: (String) -> Bool = { s in
            let clean = s.replacingOccurrences(of: ",", with: "")
                         .replacingOccurrences(of: ".", with: "")
            if let n = Int(clean), n < 100 { return true }
            if s == "-" || s == "x" || s == "X" { return true }
            return false
        }

        // Ambil nama toko (teks pertama yang bukan angka & bukan skippable)
        for text in texts.prefix(5) {
            let lower = text.lowercased()
            if !isPrice(text) && !isQtyOrSymbol(text) &&
               !isSkippable(text) && text.count > 2 &&
               !lower.contains("@") && !lower.contains("/") {
                storeName = text
                break
            }
        }

        // Parsing item: cari pola NAMA → HARGA
        var i = 0
        var itemsStarted = false

        while i < texts.count {
            let text  = texts[i]
            let lower = text.lowercased()

            // Deteksi total
            if lower.contains("total") && !lower.contains("subtotal") {
                if i + 1 < texts.count, let t = toInt(texts[i + 1]) {
                    total = t
                }
                i += 1; continue
            }

            // Skip keyword tidak relevan
            if isSkippable(text) || lower.contains("subtotal") {
                i += 1; continue
            }

            // Skip qty/simbol
            if isQtyOrSymbol(text) {
                i += 1; continue
            }

            // Kalau ini harga murni, skip (sudah dipakai di iterasi sebelumnya)
            if isPrice(text) {
                i += 1; continue
            }

            // Ini kemungkinan nama barang
            if text.count >= 3 && !lower.contains("@") {
                // Cek token berikutnya apakah harga
                var j = i + 1
                // Lewati qty/simbol di antara nama dan harga
                while j < texts.count && isQtyOrSymbol(texts[j]) {
                    j += 1
                }

                if j < texts.count && isPrice(texts[j]) {
                    let harga = toInt(texts[j]) ?? 0
                    // Pastikan ini bukan header/footer
                    if !isSkippable(text) && harga >= 500 {
                        itemsStarted = true
                        items.append(ReceiptItem(nama: text, harga: harga))
                        print("ITEM: \(text) = \(harga)")
                        i = j + 1
                        continue
                    }
                }
            }

            i += 1
        }

        if total == 0 && !items.isEmpty {
            total = items.reduce(0) { $0 + $1.harga }
        }

        return (storeName, items, total)
    }
}
