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

@Observable
class DiscTracker {
    
    private var sequenceHandler = VNSequenceRequestHandler()
    private var trackingRequest: VNTrackObjectRequest?
    
    private(set) var observations: [DiscObservation] = [] // liste over alle observasjoner av disc
    private var frameIndex: Int = 0
    
    var lastBoundingBox: CGRect? = nil // brukes til å lage boks rundt observert disc
    
    // FOR Å FINNE DISCEN
    func findDisc(in buffer: CMSampleBuffer) -> VNDetectedObjectObservation? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 3.0
        request.detectsDarkOnLight = true  // disc er mørk mot lys himmel
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer).perform([request])
        
        guard let result = request.results?.first else { return nil }
        
        // Finn den mest sirkulære konturen
        let bestContour = result.topLevelContours.max(by: { a, b in
            a.aspectRatio < b.aspectRatio
        })
        
        guard let disc = bestContour else { return nil }
        
        let box = disc.normalizedPath.boundingBox
        
        // Disc skal ikke være for stor (ikke hele skjermen)
        guard box.width < 0.5 && box.height < 0.5 else {
            print("findDisc: for stor, ignorerer")
            return nil
        }
        
        // Disc skal ikke være for liten
        guard box.width > 0.067 && box.height > 0.067 else {
            print("findDisc: for liten, ignorerer")
            return nil
        }
        
        // Disc er rund – boksen må være noenlunde kvadratisk
        let ratio = box.width / box.height
        guard ratio > 0.9 && ratio < 1.2 else {
            print("findDisc: ikke rund nok, ignorerer")
            return nil
        }
        
        // aspectRatio nærmest 1.0 = perfekt sirkel
        guard disc.aspectRatio > 0.6 else {
            print("findDisc: ikke sirkulær nok, ignorerer")
            return nil
        }
        
        print("findDisc: disc funnet! aspectRatio=\(disc.aspectRatio), størrelse=\(box.width)x\(box.height)")
        return VNDetectedObjectObservation(boundingBox: box)
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
            guard result.confidence > 0.3 else {
                lastBoundingBox = nil
                return nil
            }
        
            lastBoundingBox = result.boundingBox // LAGER BOKS RUNDT DISC
            
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

