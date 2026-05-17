// HistoryView.swift
// StrukScan
//
// File ini berisi HistoryView, layar yang menampilkan riwayat semua
// struk belanja yang pernah disimpan. Menampilkan total pengeluaran
// keseluruhan di bagian atas, diikuti daftar struk yang bisa di-tap
// untuk melihat detail, atau di-swipe untuk dihapus.

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var selectedReceipt : Receipt? = nil
    @State private var showEdit                   = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Total Card ──
                    TotalCard(total: store.totalPengeluaran)
                        .padding()

                    // ── List ──
                    if store.receipts.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName:
                                    "receipt.cutout")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Belum ada struk tersimpan")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Scan struk belanja kamu\ndan simpan ke history")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(store.receipts) { receipt in
                                ReceiptRow(receipt: receipt)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedReceipt = receipt
                                    }
                            }
                            .onDelete { store.delete(at: $0) }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("History")
            .sheet(item: $selectedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
                    .environmentObject(store)
            }
        }
    }
}

// ── Total Card ──
struct TotalCard: View {
    let total: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Pengeluaran")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatRupiah(total))
                    .font(.title2.bold())
                    .foregroundColor(.primary)
            }
            Spacer()
            Image(systemName: "chart.bar.fill")
                .font(.largeTitle)
                .foregroundColor(.green.opacity(0.4))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}

// ── Receipt Row ──
struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "receipt.cutout")
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.storeName.isEmpty ?
                     "Toko tidak diketahui" : receipt.storeName)
                    .font(.headline)
                HStack {
                    Text(receipt.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text("\(receipt.items.count) item")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(receipt.formattedTotal)
                .font(.subheadline.bold())
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}
