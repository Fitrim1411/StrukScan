// ScanView.swift
// StrukScan
//
// File ini berisi ScanView, layar utama untuk melakukan scan struk.
// Menampilkan live kamera dengan bounding box sebagai panduan posisi
// struk, tombol capture foto, dan opsi memilih dari galeri.
// Setelah foto diambil, akan membuka ResultView untuk memproses hasil.

import SwiftUI
import PhotosUI

struct ScanView: View {
    @StateObject private var camera = CameraManager()
    @EnvironmentObject var store    : ReceiptStore

    @State private var selectedPhoto : PhotosPickerItem? = nil
    @State private var isProcessing                      = false
    @State private var scannedImage  : UIImage?          = nil
    @State private var showResult                        = false
    @State private var showCamera                        = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // ── Kamera ──
            if showCamera {
                CameraPreviewView(camera: camera)
                    .ignoresSafeArea()

                // ── Overlay Guide ──
                VStack {
                    Spacer()
                    ZStack {
                        // Bounding box guide
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 320, height: 460)
                            .overlay(
                                // Corner highlights
                                CornerBrackets()
                            )

                        VStack {
                            Spacer()
                            Text("Arahkan struk ke dalam frame")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.black.opacity(0.5))
                                .cornerRadius(8)
                                .padding(.bottom, 16)
                        }
                        .frame(width: 320, height: 460)
                    }
                    Spacer()
                }
            }

            // ── UI Controls ──
            VStack {
                // Header
                HStack {
                    Text("Scan Struk")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()

                    // Toggle kamera/galeri
                    Button {
                        showCamera.toggle()
                        showCamera ? camera.start() : camera.stop()
                    } label: {
                        Image(systemName: showCamera ?
                              "photo.on.rectangle" : "camera.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.white.opacity(0.2))
                            .cornerRadius(10)
                    }
                }
                .padding()

                Spacer()

                // Loading
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(
                                CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Memproses struk...")
                            .foregroundColor(.white)
                            .font(.subheadline)
                    }
                    .padding(24)
                    .background(.black.opacity(0.7))
                    .cornerRadius(16)
                }

                Spacer()

                // Bottom bar
                HStack(spacing: 20) {
                    // Galeri
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images
                    ) {
                        VStack(spacing: 6) {
                            Image(systemName: "photo.fill")
                                .font(.title2)
                            Text("Galeri")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(.white.opacity(0.2))
                        .cornerRadius(16)
                    }

                    // Tombol Capture
                    Button {
                        guard showCamera else { return }
                        camera.capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 80, height: 80)
                            Circle()
                                .stroke(.white.opacity(0.5), lineWidth: 4)
                                .frame(width: 92, height: 92)
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(
                                        CircularProgressViewStyle(tint: .black))
                            }
                        }
                    }
                    .disabled(isProcessing || !showCamera)

                    // Placeholder kanan
                    Spacer()
                        .frame(width: 70, height: 70)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.capturedImage) { _, image in
            guard let image else { return }
            processImage(image)
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data  = try? await item.loadTransferable(
                    type: Data.self),
                   let image = UIImage(data: data) {
                    processImage(image)
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

    private func processImage(_ image: UIImage) {
        isProcessing  = true
        scannedImage  = image
        // Langsung buka ResultView — OCR akan jalan di sana
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isProcessing = false
            showResult   = true
        }
    }
}

// ── Corner Brackets ──
struct CornerBrackets: View {
    var body: some View {
        ZStack {
            // Top left
            VStack {
                HStack {
                    CornerShape().stroke(Color.green, lineWidth: 3)
                        .frame(width: 30, height: 30)
                    Spacer()
                }
                Spacer()
            }
            // Top right
            VStack {
                HStack {
                    Spacer()
                    CornerShape()
                        .rotation(.degrees(90))
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 30, height: 30)
                }
                Spacer()
            }
            // Bottom left
            VStack {
                Spacer()
                HStack {
                    CornerShape()
                        .rotation(.degrees(270))
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 30, height: 30)
                    Spacer()
                }
            }
            // Bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    CornerShape()
                        .rotation(.degrees(180))
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 30, height: 30)
                }
            }
        }
    }
}

struct CornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
