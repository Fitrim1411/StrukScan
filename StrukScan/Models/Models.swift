// Models.swift
// StrukScan
//
// File ini berisi definisi struktur data utama yang digunakan
// di seluruh aplikasi, meliputi:
// - ReceiptItem: model satu item/barang belanja (nama & harga)
// - Receipt: model satu struk lengkap (toko, tanggal, items, total)
// - formatRupiah: fungsi helper untuk format angka ke format Rupiah

import Foundation
import SwiftUI

// ── Data Models ──
struct ReceiptItem: Identifiable, Codable {
    var id    = UUID()
    var nama  : String
    var harga : Int
}

struct Receipt: Identifiable, Codable {
    var id        = UUID()
    var storeName : String
    var tanggal   : Date
    var items     : [ReceiptItem]
    var total     : Int

    var formattedDate: String {
        let f         = DateFormatter()
        f.dateStyle   = .medium
        f.timeStyle   = .short
        f.locale      = Locale(identifier: "id_ID")
        return f.string(from: tanggal)
    }

    var formattedTotal: String {
        formatRupiah(total)
    }
}

func formatRupiah(_ amount: Int) -> String {
    let f               = NumberFormatter()
    f.numberStyle       = .decimal
    f.groupingSeparator = "."
    f.minimumFractionDigits = 0
    return "Rp \(f.string(from: NSNumber(value: amount)) ?? "\(amount)")"
}
