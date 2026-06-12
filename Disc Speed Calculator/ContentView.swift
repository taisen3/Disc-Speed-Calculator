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
                                Rectangle()
                                    .stroke(Color.red, lineWidth: 2)
                                    .frame(
                                        width: box.width * geo.size.width,
                                        height: box.height * geo.size.height
                                    )
                                    .position(
                                        x: box.midX * geo.size.width,
                                        y: (1 - box.midY) * geo.size.height // 1 - box.midY fordi man må speile Y-aksen av en eller annen grunn:)
                                    )
                                // box.width,height, midX og midY må alle gangen med geo.size fordi;
                                // det er måten boksen faktisk blir synlig på faktisk skjermstørrelse.
                                // altså konverterer boksen fra data -> piksler
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
