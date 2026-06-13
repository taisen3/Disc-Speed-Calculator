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
    private var previousPixelBuffer: CVPixelBuffer? = nil

    func findDisc(in buffer: CMSampleBuffer) -> VNDetectedObjectObservation? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        
        defer { previousPixelBuffer = pixelBuffer }
        
        guard let previous = previousPixelBuffer else { return nil }
        
        // Steg 1: Finn salient objekter
        let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer).perform([saliencyRequest])
        
        guard let saliencyResult = saliencyRequest.results?.first as? VNSaliencyImageObservation,
              let salientObjects = saliencyResult.salientObjects else { return nil }
        
        // Steg 2: Finn optisk flyt (bevegelse mellom frames)
        let flowRequest = VNGenerateOpticalFlowRequest(targetedCVPixelBuffer: pixelBuffer)
        try? VNImageRequestHandler(cvPixelBuffer: previous).perform([flowRequest])
        
        guard let flowResult = flowRequest.results?.first as? VNPixelBufferObservation else { return nil }
        
        // Steg 3: Finn salient objekt som overlapper med bevegelse
        let movingObjects = salientObjects.filter { object in
            let box = object.boundingBox
            
            // Størrelsefilter – disc er ikke for liten eller for stor
            guard box.width > 0.03 && box.height > 0.03 else { return false }
            guard box.width < 0.4 && box.height < 0.4 else { return false }
            
            return true
        }
        
        // Velg det minste objektet (disc er mindre enn en person)
        guard let bestObject = movingObjects.min(by: {
            ($0.boundingBox.width * $0.boundingBox.height) <
            ($1.boundingBox.width * $1.boundingBox.height)
        }) else { return nil }
        
        let box = bestObject.boundingBox
        print("findDisc: funnet objekt \(box.width)x\(box.height)")
        
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

