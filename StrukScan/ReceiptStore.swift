// ReceiptStore.swift
// StrukScan
//
// File ini berisi ReceiptStore, sebuah ObservableObject yang berfungsi
// sebagai penyimpanan data lokal (database) untuk seluruh struk belanja.
// Data disimpan secara permanen di UserDefaults sehingga tetap ada
// meski aplikasi ditutup. Menyediakan fungsi save, update, dan delete.

import SwiftUI
import Foundation
import Combine

class ReceiptStore: ObservableObject {
    @Published var receipts: [Receipt] = []

    private let key = "saved_receipts"

    init() { load() }

    func save(_ receipt: Receipt) {
        receipts.insert(receipt, at: 0)
        persist()
    }

    func update(_ receipt: Receipt) {
        if let idx = receipts.firstIndex(where: { $0.id == receipt.id }) {
            receipts[idx] = receipt
            persist()
        }
    }

    func delete(at offsets: IndexSet) {
        receipts.remove(atOffsets: offsets)
        persist()
    }

    func delete(_ receipt: Receipt) {
        receipts.removeAll { $0.id == receipt.id }
        persist()
    }

    var totalPengeluaran: Int {
        receipts.reduce(0) { $0 + $1.total }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(receipts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data    = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Receipt].self,
                                                      from: data)
        else { return }
        receipts = decoded
    }
}
