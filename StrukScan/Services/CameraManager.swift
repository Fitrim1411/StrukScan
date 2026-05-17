// CameraManager.swift
// StrukScan
//
// File ini berisi CameraManager yang mengatur semua hal terkait kamera,
// mulai dari setup sesi kamera (AVCaptureSession), menampilkan preview
// live kamera, hingga mengambil foto. Hasil foto dikirim ke ScanView
// melalui @Published var capturedImage.

import AVFoundation
import UIKit
import Combine

class CameraManager: NSObject, ObservableObject,
                     AVCapturePhotoCaptureDelegate {

    @Published var capturedImage : UIImage? = nil
    @Published var isRunning               = false

    let session      = AVCaptureSession()
    var previewLayer : AVCaptureVideoPreviewLayer?
    private let output = AVCapturePhotoOutput()

    override init() {
        super.init()
        setupCamera()
    }

    private func setupCamera() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1280x720

            guard
                let device = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video, position: .back),
                let input  = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else { self.session.commitConfiguration(); return }

            self.session.addInput(input)
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            self.session.commitConfiguration()

            DispatchQueue.main.async {
                self.previewLayer = AVCaptureVideoPreviewLayer(
                    session: self.session)
                self.previewLayer?.videoGravity = .resizeAspectFill
            }
        }
    }

    func start() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data  = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else { return }
        DispatchQueue.main.async { self.capturedImage = image }
    }
}
