import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showToast: Bool = false // Control toast visibility
    
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
            }
            
            // Toast overlay
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
        .onChange(of: cameraManager.cameraSwitchMessage) { newValue in
            if newValue != nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showToast = true
                }
                // Hide toast after 2 seconds
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

#Preview {
    ContentView()
}
