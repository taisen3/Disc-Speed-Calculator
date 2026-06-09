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
