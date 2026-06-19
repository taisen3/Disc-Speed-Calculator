//
//  DiscTracker.swift
//  Disc Speed Calculator
//
//  Created by Stian Holtet on 10/06/2026.
//


import Vision
import AVFoundation
import CoreML

struct DiscObservation {
    let frameIndex: Int
    let timestamp: CMTime
    let center: CGPoint
    let boundingBox: CGRect
}

@Observable
class DiscTracker {
    
    private var sequenceHandler = VNSequenceRequestHandler()
    private var trackingRequest: VNTrackObjectRequest?
    
    var sessions: [[DiscObservation]] = []      // alle kast
    var currentSession: [DiscObservation] = []  // pågående kast
    
    var detectionPoints: [CGPoint] = []  // alle detekterte posisjoner
    
    private var frameIndex: Int = 0
    
    var lastBoundingBox: CGRect? = nil // brukes til å lage boks rundt observert disc
    
    // LAster inn Disc-gjenkjennings Modellen (CoreML)
    private var coreMLModel: VNCoreMLModel?
    init() {
            coreMLModel = try? VNCoreMLModel(
                for: Disc_Detector_2_v1(configuration: MLModelConfiguration()).model
            )
        }
    
    // FOR Å FINNE DISCEN
    private var previousPixelBuffer: CVPixelBuffer? = nil

    func findDisc(in buffer: CMSampleBuffer) -> VNDetectedObjectObservation? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        
        guard let model = coreMLModel else {  // ← bruk coreMLModel, ikke try? VNCoreMLModel(...)
            print("Kunne ikke laste CoreML-modell")
            return nil
        }
        
        let request = VNCoreMLRequest(model: model) { _, _ in }
        request.imageCropAndScaleOption = .scaleFill
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer).perform([request])
        
        guard let results = request.results as? [VNRecognizedObjectObservation] else { return nil }
        
        let disc = results
            .filter { $0.labels.first?.identifier == "frisbee" }
            .filter { $0.confidence > 0.5 }
            .max(by: { $0.confidence < $1.confidence })
        
        guard let best = disc else { return nil }
        
        print("Disc funnet! Confidence: \(best.confidence)")
        return VNDetectedObjectObservation(boundingBox: best.boundingBox)
    }
    
    
    // TRACKING FUNKSJONER
    
    // Kalles når du vil starte sporing av en bestemt posisjon
    func startTracking(in observation: VNDetectedObjectObservation) {
        trackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
        trackingRequest?.trackingLevel = .accurate // <-- fokus på at trackingen er nøyaktig
    }
    
    // Kalles for hvert frame
    private var lastCenter: CGPoint? = nil
    private var stationaryFrameCount = 0
    private let maxStationaryFrames = 10

    func processFrame(_ buffer: CMSampleBuffer) -> CGPoint? {
        defer { frameIndex += 1 }
        
        guard let request = trackingRequest else { return nil }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        
        try? sequenceHandler.perform([request], on: pixelBuffer)
        
        guard let result = request.results?.first as? VNDetectedObjectObservation else { return nil }
        guard result.confidence > 0.5 else {
            lastBoundingBox = nil
            return nil
        }
        
        let center = CGPoint(
            x: result.boundingBox.midX,
            y: result.boundingBox.midY
        )
        
        // Sjekk om disken har stoppet å bevege seg
        if let last = lastCenter {
            let dx = center.x - last.x
            let dy = center.y - last.y
            let movement = sqrt(dx*dx + dy*dy)
            
            if movement < 0.002 {
                stationaryFrameCount += 1
                if stationaryFrameCount > maxStationaryFrames {
                    lastBoundingBox = nil
                    lastCenter = nil
                    stationaryFrameCount = 0
                    return nil
                }
            } else {
                stationaryFrameCount = 0
            }
        }
        lastCenter = center
        
        lastBoundingBox = result.boundingBox
        
        let observation = DiscObservation(
            frameIndex: frameIndex,
            timestamp: CMSampleBufferGetPresentationTimeStamp(buffer),
            center: center,
            boundingBox: result.boundingBox
        )
        currentSession.append(observation)
        
        return center
    }

    func reset() {
        trackingRequest = nil
        currentSession = []
        sessions = []
        frameIndex = 0
        lastBoundingBox = nil
        lastCenter = nil
        stationaryFrameCount = 0
        //detectionPoints = []
    }
    
    func calculateSpeed(from observations: [DiscObservation]) -> Double? {
        guard observations.count >= 2 else { return nil }
        
        let first = observations.first!
        let last = observations.last!
        
        // Pixelforskjell
        let dx = last.center.x - first.center.x
        let dy = last.center.y - first.center.y
        let pixelDistance = sqrt(dx*dx + dy*dy)
        
        // Tidsforskjell i sekunder
        let time = CMTimeGetSeconds(last.timestamp - first.timestamp)
        
        // Piksler per sekund
        let pixelsPerSecond = pixelDistance / time
        
        // Konverter til m/s ved hjelp av discens kjente diameter (27cm)
        // Du trenger å vite hvor mange piksler discen er bred i bildet
        // Det får du fra boundingBox.width * skjermbredde i piksler
        
        return pixelsPerSecond // midlertidig, uten konvertering
    }
    func endSession() {
            if !currentSession.isEmpty {
                sessions.append(currentSession)
                currentSession = []
            }
        }
    func addObservation(from observation: VNDetectedObjectObservation, buffer: CMSampleBuffer) {
        lastBoundingBox = observation.boundingBox
        
        let center = CGPoint(
            x: observation.boundingBox.midX,
            y: observation.boundingBox.midY
        )
        
        let obs = DiscObservation(
            frameIndex: frameIndex,
            timestamp: CMSampleBufferGetPresentationTimeStamp(buffer),
            center: center,
            boundingBox: observation.boundingBox
        )
        detectionPoints.append(center)
        currentSession.append(obs)
        frameIndex += 1
    }
}

