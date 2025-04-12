import SwiftUI

struct IntroductionView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Blocks Reloaded")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Create and interact with blocks in your space")
                .font(.title2)
            
            Text("Use your hands to grab and move objects")
                .font(.title3)
        }
        .frame(width: 1280, height: 720)
        .padding()
        .glassBackgroundEffect()
    }
}

#Preview {
    IntroductionView()
} 
