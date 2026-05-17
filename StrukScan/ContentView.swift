// ContentView.swift
// StrukScan
//
// File ini berisi ContentView, root view dari aplikasi yang mengatur
// navigasi utama menggunakan TabView. Terdiri dari dua tab yaitu
// ScanView untuk scan struk baru dan HistoryView untuk melihat
// riwayat. Juga bertanggung jawab meng-inject ReceiptStore ke
// seluruh child view melalui environmentObject.

import SwiftUI

struct ContentView: View {
    @StateObject private var store = ReceiptStore()

    var body: some View {
        TabView {
            ScanView()
                .environmentObject(store)
                .tabItem {
                    Label("Scan", systemImage: "camera.fill")
                }

            HistoryView()
                .environmentObject(store)
                .tabItem {
                    Label("History",
                          systemImage: "list.bullet.rectangle.portrait.fill")
                }
        }
        .tint(.green)
    }
}
