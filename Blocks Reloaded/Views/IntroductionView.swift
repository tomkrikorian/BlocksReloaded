import SwiftUI

struct IntroductionView: View {
    
    @Environment(\.scenesManager) var scenesManager
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        VStack(spacing: 30) {
            // Title
            Text("Welcome to Blocks Reloaded!")
                .font(.system(size: 40, weight: .bold))
                .padding(.top, 20)
            
            // Tutorial Section
            VStack(alignment: .center, spacing: 15) {
                Text("How to play?")
                    .font(.title)
                    .padding()
                
                VStack {
                    HStack(spacing: 5) {
                        Image(systemName: "hand.pinch.fill")
                            .symbolEffect(.wiggle, options: .repeat(.periodic))
                            .font(.title)
                            .scaleEffect(x: -1, y: 1)
                        Image(systemName: "cube.fill")
                            .symbolEffect(.scale.up.byLayer, options: .repeat(.periodic))
                            .font(.title)
                        Image(systemName: "hand.pinch.fill")
                            .symbolEffect(.wiggle, options: .repeat(.periodic))
                            .font(.title)
                    }
                    
                    Text("Pinch your thumb and index finger on both hands to create and scale blocks")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(width: 700)
                .background(.ultraThickMaterial)
                .cornerRadius(15)
            }
            .padding()
            .frame(width: 800)
            .background(.ultraThinMaterial)
            .cornerRadius(15)
            
            // Options Panel
            VStack {
                Text("Options")
                    .font(.title)
                    .padding()
                VStack {
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
                }
                .padding()
                .frame(width: 700)
                .background(.ultraThickMaterial)
                .cornerRadius(15)

            }
            .padding()
            .frame(width: 800)
            .background(.ultraThinMaterial)
            .cornerRadius(15)
            
            Spacer()
            
            // Stop Game Button
            Button {
                Task {
                    await scenesManager.toggleImmersiveSpace()
                }
            } label: {
                Text("Exit")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(minWidth: 200)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 20)
        }
        .frame(width: 900, height: 720)
        .glassBackgroundEffect()
        .padding()
    }
}

#Preview {
    IntroductionView()
        .environment(AppModel.shared)
}
