// ReceiptDetailView.swift
// StrukScan
//
// File ini berisi ReceiptDetailView, layar detail untuk satu struk
// yang sudah tersimpan. Menampilkan informasi lengkap struk dan
// memungkinkan pengguna untuk mengedit nama toko, tanggal, list
// barang, dan total. Juga menyediakan opsi untuk menghapus struk.

import SwiftUI

struct ReceiptDetailView: View {
    @State var receipt: Receipt
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ReceiptStore

    @State private var isEditing = false
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // ── Info Toko ──
                        GroupBox {
                            VStack(spacing: 12) {
                                HStack {
                                    Label("Nama Toko",
                                          systemImage: "storefront")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                if isEditing {
                                    TextField("Nama toko",
                                              text: $receipt.storeName)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    HStack {
                                        Text(receipt.storeName.isEmpty ?
                                             "Tidak diketahui" :
                                             receipt.storeName)
                                            .font(.headline)
                                        Spacer()
                                    }
                                }

                                Divider()

                                HStack {
                                    Label("Tanggal",
                                          systemImage: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                if isEditing {
                                    DatePicker("",
                                               selection: $receipt.tanggal,
                                               displayedComponents: [.date])
                                        .labelsHidden()
                                } else {
                                    HStack {
                                        Text(receipt.formattedDate)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // ── List Item ──
                        GroupBox {
                            VStack(spacing: 0) {
                                HStack {
                                    Text("NAMA BARANG")
                                        .font(.caption2.bold())
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("HARGA")
                                        .font(.caption2.bold())
                                        .foregroundColor(.secondary)
                                }
                                .padding(.bottom, 8)

                                Divider()

                                ForEach($receipt.items) { $item in
                                    VStack {
                                        HStack {
                                            if isEditing {
                                                VStack(spacing: 4) {
                                                    TextField("Nama",
                                                              text: $item.nama)
                                                    TextField(
                                                        "Harga",
                                                        value: $item.harga,
                                                        format: .number)
                                                        .keyboardType(.numberPad)
                                                        .foregroundColor(.secondary)
                                                        .font(.subheadline)
                                                }
                                                Button {
                                                    receipt.items.removeAll {
                                                        $0.id == item.id
                                                    }
                                                } label: {
                                                    Image(systemName:
                                                            "minus.circle.fill")
                                                        .foregroundColor(.red)
                                                }
                                            } else {
                                                Text(item.nama)
                                                    .frame(maxWidth: .infinity,
                                                           alignment: .leading)
                                                Text(formatRupiah(item.harga))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        Divider()
                                    }
                                }

                                if isEditing {
                                    Button {
                                        receipt.items.append(
                                            ReceiptItem(nama: "", harga: 0))
                                    } label: {
                                        Label("Tambah Item",
                                              systemImage: "plus.circle")
                                            .font(.subheadline)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        } label: {
                            Text("Belanjaan (\(receipt.items.count) item)")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal)

                        // ── Total ──
                        GroupBox {
                            HStack {
                                Text("TOTAL BELANJA")
                                    .font(.subheadline.bold())
                                Spacer()
                                if isEditing {
                                    TextField("Total",
                                              value: $receipt.total,
                                              format: .number)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 130)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    Text(receipt.formattedTotal)
                                        .font(.title3.bold())
                                        .foregroundColor(.green)
                                }
                            }
                            if isEditing {
                                Button {
                                    receipt.total = receipt.items
                                        .reduce(0) { $0 + $1.harga }
                                } label: {
                                    Label("Hitung dari Items",
                                          systemImage: "function")
                                        .font(.caption)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal)

                        // ── Delete ──
                        Button(role: .destructive) {
                            showDelete = true
                        } label: {
                            Label("Hapus Struk",
                                  systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(14)
                                .padding(.horizontal)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle(receipt.storeName.isEmpty ?
                             "Detail Struk" : receipt.storeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tutup") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Simpan" : "Edit") {
                        if isEditing { store.update(receipt) }
                        withAnimation { isEditing.toggle() }
                    }
                    .fontWeight(isEditing ? .bold : .regular)
                    .foregroundColor(isEditing ? .green : .blue)
                }
            }
            .confirmationDialog(
                "Hapus struk ini?",
                isPresented: $showDelete,
                titleVisibility: .visible
            ) {
                Button("Hapus", role: .destructive) {
                    store.delete(receipt)
                    dismiss()
                }
                Button("Batal", role: .cancel) {}
            }
        }
    }
}
