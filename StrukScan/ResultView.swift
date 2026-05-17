// ResultView.swift
// StrukScan
//
// File ini berisi ResultView, layar yang menampilkan hasil scan struk.
// Menjalankan proses OCR pada foto yang dipilih, lalu menampilkan
// data struk berupa nama toko, tanggal, list barang beserta harga,
// dan total belanja. Semua data dapat diedit sebelum disimpan
// ke ReceiptStore sebagai history.

import SwiftUI

struct ResultView: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ReceiptStore

    @State private var storeName = ""
    @State private var tanggal   = Date()
    @State private var items     : [ReceiptItem] = []
    @State private var total     = 0
    @State private var isEditing = false
    @State private var showSaved = false
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    // Loading state
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Membaca struk...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {

                            // ── Preview Foto ──
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(12)
                                .padding(.horizontal)

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
                                                  text: $storeName)
                                            .textFieldStyle(.roundedBorder)
                                    } else {
                                        HStack {
                                            Text(storeName.isEmpty ?
                                                 "Tidak terdeteksi" :
                                                 storeName)
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
                                                   selection: $tanggal,
                                                   displayedComponents: [.date])
                                            .labelsHidden()
                                    } else {
                                        HStack {
                                            Text(tanggal.formatted(
                                                date: .abbreviated,
                                                time: .omitted))
                                            Spacer()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)

                            // ── List Item ──
                            GroupBox {
                                VStack(spacing: 0) {
                                    // Header
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

                                    if items.isEmpty {
                                        Text("Tidak ada item terdeteksi")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding(.vertical, 20)
                                    } else {
                                        ForEach($items) { $item in
                                            VStack {
                                                HStack {
                                                    if isEditing {
                                                        VStack(spacing: 4) {
                                                            TextField(
                                                                "Nama barang",
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
                                                            items.removeAll {
                                                                $0.id == item.id
                                                            }
                                                        } label: {
                                                            Image(
                                                                systemName:
                                                                "minus.circle.fill")
                                                                .foregroundColor(.red)
                                                        }
                                                    } else {
                                                        Text(item.nama)
                                                            .frame(
                                                                maxWidth: .infinity,
                                                                alignment: .leading)
                                                        Text(formatRupiah(item.harga))
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                                Divider()
                                            }
                                        }
                                    }

                                    if isEditing {
                                        Button {
                                            items.append(
                                                ReceiptItem(nama: "",
                                                             harga: 0))
                                        } label: {
                                            Label("Tambah Item",
                                                  systemImage: "plus.circle")
                                                .font(.subheadline)
                                        }
                                        .padding(.top, 8)
                                    }
                                }
                            } label: {
                                Text("Belanjaan (\(items.count) item)")
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
                                                  value: $total,
                                                  format: .number)
                                            .keyboardType(.numberPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 130)
                                            .textFieldStyle(.roundedBorder)
                                    } else {
                                        Text(formatRupiah(total))
                                            .font(.title3.bold())
                                            .foregroundColor(.green)
                                    }
                                }

                                if isEditing {
                                    Button {
                                        total = items.reduce(0) {
                                            $0 + $1.harga
                                        }
                                    } label: {
                                        Label("Hitung dari Items",
                                              systemImage: "function")
                                            .font(.caption)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.horizontal)

                            // ── Tombol Simpan ──
                            if !isEditing {
                                Button {
                                    saveReceipt()
                                } label: {
                                    Label("Simpan ke History",
                                          systemImage: "square.and.arrow.down")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .cornerRadius(14)
                                        .padding(.horizontal)
                                }
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(.top)
                    }
                }

                // ── Saved overlay ──
                if showSaved {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("Tersimpan!")
                            .font(.title2.bold())
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }
            }
            .navigationTitle("Hasil Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tutup") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Selesai" : "Edit") {
                        withAnimation { isEditing.toggle() }
                    }
                    .fontWeight(isEditing ? .bold : .regular)
                    .foregroundColor(isEditing ? .green : .blue)
                }
            }
        }
        .onAppear { runOCR() }
    }

    private func runOCR() {
        isLoading = true
        OCRManager.shared.recognize(image: image) { name, receiptItems, receiptTotal in
            storeName = name
            items     = receiptItems
            total     = receiptTotal
            isLoading = false
        }
    }

    private func saveReceipt() {
        let receipt = Receipt(
            storeName : storeName,
            tanggal   : tanggal,
            items     : items,
            total     : total
        )
        store.save(receipt)
        showSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}
