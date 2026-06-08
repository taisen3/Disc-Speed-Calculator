//
//  ContentView.swift
//  Disc Speed Calculator
//
//  Created by Stian Holtet on 07/06/2026.
//

import SwiftUI

struct ContentView: View {
    let camera = CameraManager()

    var body: some View {
        CameraPreviewView(session: camera.session)
            .ignoresSafeArea()
            .onAppear {
                camera.requestPermissionAndSetup()
            }
    }
}

#Preview {
    ContentView()
}
