//
//  DiscTracker.swift
//  Disc Speed Calculator
//
//  Created by Stian Holtet on 10/06/2026.
//


import Vision
import AVFoundation

struct DiscObservation {
    let frameIndex: Int
    let timestamp: CMTime
    let center: CGPoint
    let boundingBox: CGRect
}

class DiscTracker {
    
    private var sequenceHandler = VNSequenceRequestHandler()
    private var trackingRequest: VNTrackObjectRequest?
    
    private(set) var observations: [DiscObservation] = []
    private var frameIndex: Int = 0
    
    // FOR Å FINNE DISCEN
    
    func findDisc(in buffer: CMSampleBuffer) -> VNDetectedObjectObservation? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 2.0  // øk kontrast for å finne kanter bedre
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer).perform([request])
        
        guard let result = request.results?.first else { return nil }
        
        // Finn den mest sirkulære konturen – sannsynligvis disken
        let topContour = result.topLevelContours.max(by: { a, b in
            a.aspectRatio < b.aspectRatio  // nærmest 1.0 = mest sirkulær
        })
        
        guard let disc = topContour else { return nil }
        
        // Konverter til en observation som trackeren kan bruke
        return VNDetectedObjectObservation(boundingBox: disc.normalizedPath.boundingBox)
    }
    
    
    // TRACKING FUNKSJONER
    
    // Kalles når du vil starte sporing av en bestemt posisjon
    func startTracking(in observation: VNDetectedObjectObservation) {
        trackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
        trackingRequest?.trackingLevel = .accurate // <-- fokus på at trackingen er nøyaktig
    }
    
    // Kalles for hvert frame
    func processFrame(_ buffer: CMSampleBuffer) -> CGPoint? {
            defer { frameIndex += 1 }  // øk frameIndex uansett hva som skjer
            
            guard let request = trackingRequest else { return nil }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
            
            try? sequenceHandler.perform([request], on: pixelBuffer)
            
            guard let result = request.results?.first as? VNDetectedObjectObservation else { return nil }
            
            let center = CGPoint(
                x: result.boundingBox.midX,
                y: result.boundingBox.midY
            )
            
            // Lagre observasjonen
            let observation = DiscObservation(
                frameIndex: frameIndex,
                timestamp: CMSampleBufferGetPresentationTimeStamp(buffer),
                center: center,
                boundingBox: result.boundingBox
            )
            observations.append(observation)
            
            return center
        }
        
        func reset() {
            trackingRequest = nil
            observations = []
            frameIndex = 0
        }
}

