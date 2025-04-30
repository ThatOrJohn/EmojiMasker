import SwiftUI
import AVFoundation

struct CameraPreview: UIViewControllerRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        previewLayer.videoGravity = .resizeAspectFill // Explicitly set videoGravity
        previewLayer.frame = viewController.view.bounds
        viewController.view.layer.addSublayer(previewLayer)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
