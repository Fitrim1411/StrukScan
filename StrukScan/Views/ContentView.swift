// ContentView.swift
// StrukScan
//
// File ini berisi ContentView, root view dari aplikasi yang mengatur
// navigasi utama menggunakan TabView. Terdiri dari dua tab yaitu
// ScanView untuk scan struk baru dan HistoryView untuk melihat
// riwayat. Juga bertanggung jawab meng-inject ReceiptStore ke
// seluruh child view melalui environmentObject.

import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var store = ReceiptStore()
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var scannedImage: UIImage? = nil
    @State private var showResult = false
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {

            // Tab Galeri
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images
            ) {
                VStack {
                    Spacer()
                    Image(systemName: "photo.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    Text("Pilih foto struk")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
            .tabItem {
                Label("Galeri", systemImage: "photo.fill")
            }
            .tag(0)

            // Tab Scan
            ScanView()
                .environmentObject(store)
                .tabItem {
                    Label("Scan", systemImage: "camera.fill")
                }
                .tag(1)

            // Tab History
            HistoryView()
                .environmentObject(store)
                .tabItem {
                    Label("History",
                          systemImage: "list.bullet.rectangle.portrait.fill")
                }
                .tag(2)
        }
        .tint(.green)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data  = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    scannedImage  = image
                    showResult    = true
                    selectedPhoto = nil
                }
            }
        }
        .sheet(isPresented: $showResult) {
            if let image = scannedImage {
                ResultView(image: image)
                    .environmentObject(store)
            }
        }
    }
}
