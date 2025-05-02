//
//  ContentView.swift
//  TestoSim
//
//  Created by Jesper Vang on 01/05/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: AppDataStore
    
    var body: some View {
        NavigationStack {
            ProtocolListView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppDataStore())
}
