import SwiftUI

struct TestosteroneChart: View {
    @EnvironmentObject var dataStore: AppDataStore
    let treatmentProtocol: InjectionProtocol
    
    var body: some View {
        Text("Chart temporarily unavailable")
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.2))
            .padding()
    }
} 