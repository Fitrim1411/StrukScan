// CameraPreviewView.swift
// StrukScan
//
// File ini berisi CameraPreviewView, sebuah UIViewRepresentable yang
// menjadi jembatan antara UIKit dan SwiftUI untuk menampilkan live
// preview kamera di layar. Menggunakan AVCaptureVideoPreviewLayer
// dari CameraManager untuk menampilkan feed kamera secara real-time.

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let camera: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let layer = camera.previewLayer {
                layer.frame        = view.bounds
                layer.videoGravity = .resizeAspectFill
                view.layer.addSublayer(layer)
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        camera.previewLayer?.frame = uiView.bounds
    }
}
