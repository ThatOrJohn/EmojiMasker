import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showToast: Bool = false
    @State private var explosions: [Explosion] = []
    
    var body: some View {
        ZStack {
            CameraPreview(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                ForEach(cameraManager.faces) { face in
                    let rect = convertBoundingBox(face.boundingBox, to: geometry.size)
                    Text(face.emoji)
                        .font(.system(size: rect.width * 1.8))
                        .position(x: rect.midX, y: rect.midY)
                }
                
                ForEach(explosions) { explosion in
                    ExplosionView()
                        .position(explosion.position)
                        .id(explosion.id)
                }
            }
            .onTapGesture { location in
                let newExplosion = Explosion(id: UUID(), position: location)
                explosions.append(newExplosion)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    explosions.removeAll { $0.id == newExplosion.id }
                }
            }
            
            if showToast, let message = cameraManager.cameraSwitchMessage {
                VStack {
                    Text(message)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .padding(.top, 50)
                    Spacer()
                }
                .transition(.opacity)
                .zIndex(1)
            }
            
            VStack {
                Spacer()
                Button(action: {
                    cameraManager.switchCamera()
                }) {
                    Image(systemName: "camera.rotate.fill")
                        .font(.system(size: 24))
                        .padding(12)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .padding(.bottom, 20)
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: cameraManager.cameraSwitchMessage) { _, newValue in
            if newValue != nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showToast = false
                    }
                }
            }
        }
    }
    
    private func convertBoundingBox(_ box: CGRect, to size: CGSize) -> CGRect {
        if cameraManager.isFrontCamera {
            let x = box.origin.x * size.width
            let y = (1 - box.origin.y - box.height) * size.height
            let width = box.width * size.width
            let height = box.height * size.height
            return CGRect(x: x, y: y, width: width, height: height)
        } else {
            let x = box.origin.x * size.width
            let y = box.origin.y * size.height
            let width = box.width * size.width
            let height = box.height * size.height
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }
}

struct Explosion: Identifiable {
    let id: UUID
    let position: CGPoint
}

struct ExplosionView: View {
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 1.0
    
    var body: some View {
        ZStack {
            Text("💥")
                .font(.system(size: 50))
                .scaleEffect(scale)
                .rotationEffect(.degrees(scale * 180))
                .opacity(opacity)
            Text("🔥")
                .font(.system(size: 30))
                .scaleEffect(scale * 0.8)
                .rotationEffect(.degrees(-scale * 90))
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                scale = 2.0
                opacity = 0.0
            }
        }
    }
}

#Preview {
    ContentView()
}
