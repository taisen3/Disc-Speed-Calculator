//
//  CameraManager.swift
//  Disc Speed Calculator
//
//  Created by Stian Holtet on 08/06/2026.
//


import AVFoundation

class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    
    // Kamera som gir ut frames
    let session = AVCaptureSession()
    private(set) var actualFPS: Int = 60  // hva vi faktisk fikk
    
    // Disc deteksjon og tracking
    private let tracker = DiscTracker()
    private var isTracking = false

    // MARK: - Tillatelse

    func requestPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("requestPermissionAndSetup: authorized")
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    print("requestPermissionAndSetup: notDetermined -> granted")
                    self?.setupCamera()
                } else {
                    print("requestPermissionAndSetup: notDetermined -> showPermissionAlert")
                    DispatchQueue.main.async { self?.showPermissionAlert() }
                }
            }
        case .denied, .restricted:
            showPermissionAlert()
        @unknown default:
            print("requestPermissionAndSetup: denied eller restricted")
            break
        }
    }

    // MARK: - Kameraoppsett

    func setupCamera() {
        // Prøv bakkamera, fall tilbake til frontkamera
        guard let device = bestAvailableCamera() else {
            print("setupCamera: Ingen kamera tilgjengelig")
            return
        }

        // Sørger for at kamera opererer på samme fps som actualfps
        do {
            try device.lockForConfiguration()
            
            // Finn beste FPS-konfigurasjon enheten støtter
            let targetFPS = bestSupportedFPS(for: device, preferred: 120)
            actualFPS = targetFPS
            //DEBUG
            print("actualFPS = \(actualFPS)")
            
            let duration = CMTime(value: 1, timescale: CMTimeScale(actualFPS))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            
            device.unlockForConfiguration()
        } catch {
            print("Kunne ikke konfigurere kamera: \(error)")
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.queue"))
        session.addOutput(output)
    }
    
    func start() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func stop() {
        session.stopRunning()
    }

    // MARK: - Hjelpefunksjoner

    private func bestAvailableCamera() -> AVCaptureDevice? {
        // Prøv bakkamera først, deretter frontkamera
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    }

    private func bestSupportedFPS(for device: AVCaptureDevice, preferred: Int) -> Int {
        let candidates = [120, 60, 30]
        
        for fps in candidates where fps <= preferred {
            if let format = device.formats
                .filter({ format in
                    let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    let supportsFPS = format.videoSupportedFrameRateRanges.contains {
                        $0.maxFrameRate >= Double(fps)
                    }
                    // Maks 1080p for å unngå overbelastning
                    return supportsFPS && dim.width <= 1920
                })
                .max(by: { a, b in
                    // Velg høyest oppløsning blant de som støtter FPS-en
                    let aRes = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
                    let bRes = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
                    return (aRes.width * aRes.height) < (bRes.width * bRes.height)
                })
            {
                device.activeFormat = format
                let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                print("bestSupportedFPS: \(fps) FPS, oppløsning \(dim.width)x\(dim.height)")
                return fps
            }
        }
        
        print("bestSupportedFPS: fallback verdi: 30")
        return 30
    }

    private func showPermissionAlert() {
        DispatchQueue.main.async {
            // Presenter alert med lenke til Innstillinger
            // Her bruker du f.eks. en @Published var til SwiftUI-viewet ditt
        }
    }

    // MARK: - Frame-mottak

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        processFrame(sampleBuffer)
        print("Frame mottatt") // Midlertidig print
    }
    
    // prosseser frames og let etter og spor disc
    func processFrame(_ buffer: CMSampleBuffer) {
        if !isTracking {
            // Prøv å finne disken
            if let observation = tracker.findDisc(in: buffer) {
                tracker.startTracking(in: observation)
                isTracking = true
                print("Disc funnet – starter sporing")
            }
        } else {
            // Spor disken
            if let center = tracker.processFrame(buffer) {
                print("Disc posisjon: \(center)")
            }
        }
    }
    
}






