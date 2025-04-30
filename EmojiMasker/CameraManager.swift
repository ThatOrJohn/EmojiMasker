import AVFoundation
import Vision
import UIKit

struct DetectedFace: Identifiable {
    let id: UUID
    let boundingBox: CGRect
    let emoji: String
}

class CameraManager: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var videoOutput: AVCaptureVideoDataOutput?
    @Published var faces: [DetectedFace] = []
    private var emojiMap: [UUID: String] = [:]
    private let emojis = ["🤬", "🐱", "😐", "🙈", "🙊", "🙉", "🤨", "🤓", "🤪"]
    private var currentCameraPosition: AVCaptureDevice.Position = .front
    private var currentInput: AVCaptureDeviceInput?
    @Published var cameraSwitchMessage: String? = nil // New: Notify camera switch
    
    override init() {
        super.init()
        checkCameraAuthorization()
    }
    
    private func checkCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                }
            }
        default:
            print("Camera access denied")
        }
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .high
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to set up camera")
            return
        }
        
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        captureSession.beginConfiguration()
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            currentInput = input
        }
        if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        captureSession.commitConfiguration()
        
        sessionQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    func switchCamera() {
        sessionQueue.async {
            self.captureSession.beginConfiguration()
            if let currentInput = self.currentInput {
                self.captureSession.removeInput(currentInput)
            }
            
            self.currentCameraPosition = (self.currentCameraPosition == .front) ? .back : .front
            
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentCameraPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newCamera) else {
                print("Failed to switch camera")
                self.captureSession.commitConfiguration()
                return
            }
            
            if self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
                self.currentInput = newInput
            }
            
            self.captureSession.commitConfiguration()
            
            // Publish switch message
            DispatchQueue.main.async {
                self.cameraSwitchMessage = self.currentCameraPosition == .front ? "Switched to Front Camera" : "Switched to Back Camera"
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            self.captureSession.stopRunning()
        }
    }
    
    var isFrontCamera: Bool {
        return currentCameraPosition == .front
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let orientation: CGImagePropertyOrientation = currentCameraPosition == .front ? .leftMirrored : .right
        let request = VNDetectFaceRectanglesRequest { request, error in
            guard let observations = request.results as? [VNDetectedObjectObservation], error == nil else {
                print("Face detection failed: \(String(describing: error))")
                return
            }
            
            var newFaces: [DetectedFace] = []
            var newEmojiMap = self.emojiMap
            
            for observation in observations {
                let boundingBox = observation.boundingBox
                let center = CGPoint(x: boundingBox.midX, y: boundingBox.midY)
                
                var matchedID: UUID?
                var minDistance: CGFloat = .greatestFiniteMagnitude
                for (id, _) in self.emojiMap {
                    if let prevFace = self.faces.first(where: { $0.id == id }) {
                        let prevCenter = CGPoint(x: prevFace.boundingBox.midX, y: prevFace.boundingBox.midY)
                        let distance = hypot(center.x - prevCenter.x, center.y - prevCenter.y)
                        if distance < minDistance && distance < 0.1 {
                            minDistance = distance
                            matchedID = id
                        }
                    }
                }
                
                let faceID = matchedID ?? UUID()
                let emoji = newEmojiMap[faceID] ?? self.emojis.randomElement()!
                newEmojiMap[faceID] = emoji
                
                newFaces.append(DetectedFace(id: faceID, boundingBox: boundingBox, emoji: emoji))
            }
            
            newEmojiMap = newEmojiMap.filter { (key, _) in
                newFaces.contains(where: { $0.id == key })
            }
            
            DispatchQueue.main.async {
                self.faces = newFaces
                self.emojiMap = newEmojiMap
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try? handler.perform([request])
    }
}
