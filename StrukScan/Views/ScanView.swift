// ScanView.swift
// StrukScan
//
// File ini berisi ScanView, layar utama untuk melakukan scan struk.
// Menampilkan live kamera dengan bounding box sebagai panduan posisi
// struk, tombol capture foto, dan opsi memilih dari galeri.
// Setelah foto diambil, akan membuka ResultView untuk memproses hasil.

import SwiftUI

struct ScanView: View {
    @StateObject private var camera = CameraManager()
    @EnvironmentObject var store    : ReceiptStore

    @State private var isProcessing = false
    @State private var scannedImage : UIImage? = nil
    @State private var showResult   = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // ── Kamera ──
            CameraPreviewView(camera: camera)
                .ignoresSafeArea()

            // ── Overlay Guide ──
            VStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 320, height: 460)
                        .overlay(CornerBrackets())

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

            // ── UI Controls ──
            VStack {
                // Header
                HStack {
                    Text("Scan Struk")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()
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

                // Tombol Capture
                Button {
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
                .disabled(isProcessing)
                .padding(.bottom, 40)
            }
        }
        .onAppear  { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.capturedImage) { _, image in
            guard let image else { return }
            processImage(image)
        }
        .sheet(isPresented: $showResult) {
            if let image = scannedImage {
                ResultView(image: image)
                    .environmentObject(store)
            }
        }
    }

    private func processImage(_ image: UIImage) {
        isProcessing = true
        scannedImage = image
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
            VStack {
                HStack {
                    CornerShape().stroke(Color.green, lineWidth: 3)
                        .frame(width: 30, height: 30)
                    Spacer()
                }
                Spacer()
            }
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
