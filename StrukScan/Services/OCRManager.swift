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

        if let jpg = image.jpegData(compressionQuality: 0.6) {
            imageData = jpg; fileName = "receipt.jpg"; mimeType = "image/jpeg"
        } else if let png = image.pngData() {
            imageData = png; fileName = "receipt.png"; mimeType = "image/png"
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

        // ── Opsi 2: General parsing (aktif sekarang) ──
        let result = parseReceipt(texts: texts)

        // ── Opsi 2+3: AI fallback kalau parsing gagal (items kosong) ──
        // Cara aktifkan:
        // 1. Dapat API key gratis di aistudio.google.com
        // 2. Ganti YOUR_GEMINI_API_KEY_HERE di fungsi parseWithAI bawah
        // 3. Uncomment blok if di bawah ini
        //
//         if result.items.isEmpty {
//             print("Parsing gagal, coba AI fallback...")
//             if let aiResult = try? await parseWithAI(texts: texts) {
//                 return aiResult
//             }
//         }

        return result
    }

    // MARK: - Opsi 2: General Parsing

    private func parseReceipt(texts: [String])
        -> (storeName: String, items: [ReceiptItem], total: Int) {

        var storeName = ""
        var items: [ReceiptItem] = []
        var total = 0

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
                "check", "closed", "ppn", "dpp", "npwp", "hemat",
                "harga jual", "anda hemat", "diskon", "promo"
            ]
            return skipKeywords.contains(where: { lower.contains($0) })
        }

        let isQtyOrSymbol: (String) -> Bool = { s in
            let clean = s.replacingOccurrences(of: ",", with: "")
                         .replacingOccurrences(of: ".", with: "")
            if let n = Int(clean), n < 100 { return true }
            if ["-", "x", "X", "*"].contains(s) { return true }
            return false
        }

        // Nama toko
        for text in texts.prefix(5) {
            let lower = text.lowercased()
            if !isPrice(text) && !isQtyOrSymbol(text) &&
               !isSkippable(text) && text.count > 2 &&
               !lower.contains("@") && !lower.contains("/") {
                storeName = text
                break
            }
        }

        // Parsing item
        var i = 0
        while i < texts.count {
            let text  = texts[i]
            let lower = text.lowercased()

            if lower.contains("total") && !lower.contains("subtotal") {
                if i + 1 < texts.count, let t = toInt(texts[i + 1]) {
                    total = t
                }
                i += 1; continue
            }

            if isSkippable(text) || lower.contains("subtotal") {
                i += 1; continue
            }

            if isQtyOrSymbol(text) { i += 1; continue }
            if isPrice(text)       { i += 1; continue }

            if text.count >= 3 && !lower.contains("@") {
                var j = i + 1
                while j < texts.count && isQtyOrSymbol(texts[j]) { j += 1 }
                if j < texts.count && isPrice(texts[j]) {
                    let harga = toInt(texts[j]) ?? 0
                    if !isSkippable(text) && harga >= 500 {
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

    // MARK: - Opsi 3: AI Parsing (Gemini API - GRATIS)
    // Cara aktifkan:
    // 1. Dapat API key gratis di aistudio.google.com
    // 2. Ganti YOUR_GEMINI_API_KEY_HERE dengan key kamu
    // 3. Uncomment seluruh fungsi ini
    // 4. Uncomment blok "if result.items.isEmpty" di uploadAndParse
    //
//     private func parseWithAI(texts: [String]) async throws
//         -> (storeName: String, items: [ReceiptItem], total: Int) {
//    
//         let rawText = texts.joined(separator: "\n")
//    
//         let prompt =
//             "Berikut teks OCR struk belanja Indonesia:\n\n" +
//             rawText +
//             "\n\nEkstrak dalam JSON:\n" +
//             "{\"storeName\":\"nama toko\"," +
//             "\"items\":[{\"nama\":\"nama barang\",\"harga\":12000}]," +
//             "\"total\":17000}\n\n" +
//             "Rules: harga integer tanpa titik/koma, " +
//             "items hanya barang dibeli bukan subtotal/pajak/kembalian, " +
//             "Respond ONLY valid JSON no explanation no markdown."
//    
//         let apiKey = "AIzaSyCFlylLr1TwxKAaMrx5vaIxzCwUmubgqGo"
//         let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)"
//         let url    = URL(string: urlStr)!
//    
//         var request = URLRequest(url: url)
//         request.httpMethod = "POST"
//         request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//         request.timeoutInterval = 30
//    
//         let body: [String: Any] = [
//             "contents": [["parts": [["text": prompt]]]],
//             "generationConfig": ["temperature": 0.1, "maxOutputTokens": 1000]
//         ]
//    
//         request.httpBody = try JSONSerialization.data(withJSONObject: body)
//    
//         let (data, response) = try await URLSession.shared.data(for: request)
//    
//         guard let http = response as? HTTPURLResponse,
//               (200...299).contains(http.statusCode)
//         else {
//             let errStr = String(data: data, encoding: .utf8) ?? "unknown"
//             print("Gemini error: \(errStr)")
//             throw URLError(.badServerResponse)
//         }
//    
//         guard let json       = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//               let candidates = json["candidates"] as? [[String: Any]],
//               let first      = candidates.first,
//               let content    = first["content"] as? [String: Any],
//               let parts      = content["parts"] as? [[String: Any]],
//               let text       = parts.first?["text"] as? String
//         else { throw URLError(.cannotParseResponse) }
//    
//         let clean = text
//             .trimmingCharacters(in: .whitespacesAndNewlines)
//             .replacingOccurrences(of: "```json", with: "")
//             .replacingOccurrences(of: "```", with: "")
//             .trimmingCharacters(in: .whitespacesAndNewlines)
//    
//         print("Gemini response: \(clean)")
//    
//         guard let jsonData = clean.data(using: .utf8),
//               let parsed   = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
//         else { throw URLError(.cannotParseResponse) }
//    
//         let storeName = parsed["storeName"] as? String ?? ""
//         let total     = parsed["total"]     as? Int    ?? 0
//         let rawItems  = parsed["items"]     as? [[String: Any]] ?? []
//    
//         let items = rawItems.compactMap { item -> ReceiptItem? in
//             guard let nama  = item["nama"]  as? String,
//                   let harga = item["harga"] as? Int
//             else { return nil }
//             return ReceiptItem(nama: nama, harga: harga)
//         }
//    
//         print("AI parsed: \(storeName), \(items.count) items, total \(total)")
//         return (storeName, items, total)
//     }
}
