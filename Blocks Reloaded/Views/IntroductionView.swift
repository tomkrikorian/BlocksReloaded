import SwiftUI

struct IntroductionView: View {
    
    @Environment(\.scenesManager) var scenesManager
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Blocks Reloaded")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .center, spacing: 15) {
                HStack(spacing: 5) {
                    Image(systemName: "hand.pinch.fill")
                        .symbolEffect(.wiggle, options: .repeat(.periodic))
                        .font(.title)
                        .scaleEffect(x: -1, y: 1)
                    Image(systemName: "cube.fill")
                        .symbolEffect(.scale.up.byLayer, options: .repeat(.periodic))
                        .font(.title)// Mirror for left hand
                    Image(systemName: "hand.pinch.fill")
                        .symbolEffect(.wiggle, options: .repeat(.periodic))
                        .font(.title)
                }
                
                Text("Pinch your thumb and index finger on both hands to create and scale blocks")
                    .font(.title3)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(15)
            
            Button {
                Task {
                    await scenesManager.toggleImmersiveSpace()
                }
            } label: {
                Text("Exit Game")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(minWidth: 200)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .glassBackgroundEffect()
            
            Button {
                appModel.toggleGravity()
            } label: {
                Text(appModel.gravity.y == 0 ? "Enable Gravity" : "Disable Gravity")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(minWidth: 200)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .glassBackgroundEffect()
        }
        .frame(width: 1280, height: 720)
        .padding()
        .glassBackgroundEffect()
    }
}

#Preview {
    IntroductionView()
} 
