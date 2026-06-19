//
//  ContentView.swift
//  Disc Speed Calculator
//
//  Created by Stian Holtet on 07/06/2026.
//

import SwiftUI

struct ContentView: View {
    let camera = CameraManager()
    
    @State private var isRunning = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session) // tar inn session fra Camera Manager
                .ignoresSafeArea()
            
            // Bounding box overlay
            GeometryReader { geo in
                if let box = camera.tracker.lastBoundingBox {
                    let _ = print("Box: midX=\(box.midX), midY=\(box.midY)")
                    Rectangle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(
                            width: box.height * geo.size.width,
                            height: box.width * geo.size.height
                        )
                        .position(
                            x: box.midY * geo.size.width,
                            y: box.midX * geo.size.height
                        )
                }
                // Vis alle detekterte posisjoner som røde sirkler
                ForEach(Array(camera.tracker.detectionPoints.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 12, height: 12)
                        .position(
                            x: point.y * geo.size.width,
                            y: point.x * geo.size.height
                        )
                }
                
            }
            
            
            if (!isRunning) {
                Color
                    .black
                    .opacity(0.5)
                    .ignoresSafeArea()
            }

            VStack {
                //Spacer()
                Button(isRunning ? "Stop" : "Start") {
                    if isRunning {
                        camera.stop()
                    } else {
                        camera.start()
                    }
                    isRunning.toggle()
                }
                .font(Font.largeTitle.bold())
                .padding()
            }
        }
        .onAppear {
            camera.requestPermissionAndSetup()
        }
    }
}

#Preview {
    ContentView()
}
