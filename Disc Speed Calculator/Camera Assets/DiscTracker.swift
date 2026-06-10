//
//  DiscTracker.swift
//  Disc Speed Calculator
//
//  Created by Stian Holtet on 10/06/2026.
//


import Vision
import AVFoundation

class DiscTracker {
    
    private var sequenceHandler = VNSequenceRequestHandler()
    private var trackingRequest: VNTrackObjectRequest?
    
    // Kalles når du vil starte sporing av en bestemt posisjon
    func startTracking(in observation: VNDetectedObjectObservation) {
        trackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
        trackingRequest?.trackingLevel = .accurate // <-- fokus på at trackingen er nøyaktig
    }
    
    // Kalles for hvert frame
    func processFrame(_ buffer: CMSampleBuffer) -> CGPoint? {
        guard let request = trackingRequest else { return nil }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        
        try? sequenceHandler.perform([request], on: pixelBuffer)
        
        guard let result = request.results?.first as? VNDetectedObjectObservation else { return nil }
        
        // Returner senterpunktet av bounding boxen
        let center = CGPoint(
            x: result.boundingBox.midX,
            y: result.boundingBox.midY
        )
        
        return center
    }
    
    func reset() {
        trackingRequest = nil
    }
}
