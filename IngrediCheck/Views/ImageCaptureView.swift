import SwiftUI
import AVFoundation
import Vision

struct ImageCaptureView: View {
    @State private var cameraManager = CameraManager()
    @Environment(WebService.self) var webService
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(spacing: 0) {
            CameraPreview(session: cameraManager.session)
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.paletteSecondary, lineWidth: 0.8)
                )
                .padding(.top)
            Text("Take photo of an Ingredient Label.")
                .padding(.top)
            Spacer()
            HStack {
                if appState.checkTabState.capturedImages.isEmpty {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 100 * (3/4), height: 100)
                } else {
                    Image(uiImage: appState.checkTabState.capturedImages.last!.image)
                        .resizable()
                        .aspectRatio(3/4, contentMode: .fit)
                        .frame(width: 100 * (3/4), height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.paletteSecondary, lineWidth: 0.8)
                        )
                }
                Spacer()
                Button(action: {
                    capturePhoto()
                }, label: {
                    Image(systemName: "circle.dotted.circle")
                        .resizable()
                        .frame(width: 50, height: 50)
                })
                Spacer()
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 100 * (3/4), height: 100)
            }
            .padding(.bottom)
        }
        .navigationBarItems(
            leading: clearButton,
            trailing: checkButton
        )
        .onAppear {
            cameraManager.setupSession()
        }
        .onDisappear {
            appState.checkTabState.capturedImages = []
            cameraManager.stopSession()
        }
    }
    
    private var clearButton: some View {
        Button("Clear") {
            deleteCapturedImages()
        }
        .disabled(appState.checkTabState.capturedImages.isEmpty)
        .foregroundStyle(appState.checkTabState.capturedImages.isEmpty ? .clear : .paletteAccent)
    }

    private var checkButton: some View {
        Button("Check") {
            appState.checkTabState.routes.append(.productImages(appState.checkTabState.capturedImages))
        }
        .disabled(appState.checkTabState.capturedImages.isEmpty)
        .foregroundStyle(appState.checkTabState.capturedImages.isEmpty ? .clear : .paletteAccent)
    }
    
    func capturePhoto() {
        cameraManager.capturePhoto { image in
            if let image = image {
                
                let ocrTask = startOCRTask(image: image)
                let uploadTask = startUploadTask(image: image)
                let barcodeDetectionTask = startBarcodeDetectionTask(image: image)

                withAnimation {
                    appState.checkTabState.capturedImages.append(ProductImage(
                        image: image,
                        ocrTask: ocrTask,
                        uploadTask: uploadTask,
                        barcodeDetectionTask: barcodeDetectionTask))
                }
            }
        }
    }
    
    func startUploadTask(image: UIImage) -> Task<String, Error> {
        Task {
            try await webService.uploadImage(image: image)
        }
    }
    
    func startOCRTask(image: UIImage) -> Task<String, Error> {
        Task {
            guard let cgImage = image.cgImage else {
                return ""
            }
            
            var imageText = ""
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    fatalError("Received invalid observations")
                }
                
                for observation in observations {
                    guard let bestCandidate = observation.topCandidates(1).first else {
                        print("No candidate")
                        continue
                    }
                    
                    imageText += bestCandidate.string
                    imageText += "\n"
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            return imageText
        }
    }
    
    func startBarcodeDetectionTask(image: UIImage) -> Task<String?, Error> {
        Task {
            guard let cgImage = image.cgImage else {
                return nil
            }

            let request = VNDetectBarcodesRequest()
            request.symbologies = [.ean8, .ean13]
            request.coalesceCompositeSymbologies = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
                guard let results = request.results as [VNBarcodeObservation]?, !results.isEmpty else {
                    return nil
                }
                
                return results.first?.payloadStringValue
            } catch {
                print("Failed to perform barcode detection: \(error)")
                return nil
            }
        }
    }
    
    func deleteCapturedImages() {
        let imagesToDelete = appState.checkTabState.capturedImages
        
        withAnimation {
            appState.checkTabState.capturedImages = []
        }

        Task {
            var filesToDelete: [String] = []
            for productImage in imagesToDelete {
                filesToDelete.append(try await productImage.uploadTask.value)
                _ = try await productImage.ocrTask.value
            }
            try await webService.deleteImages(imageFileNames: filesToDelete)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    var session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView(session: session)
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Update code here
    }
}

class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer
    
    init(session: AVCaptureSession) {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        
        self.previewLayer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(self.previewLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = self.bounds
    }
}

class CameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    var session = AVCaptureSession()
    var photoOutput = AVCapturePhotoOutput()
    var completion: ((UIImage?) -> Void)?
    
    func setupSession() {
        session.sessionPreset = .photo
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No back camera available.")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if session.canAddInput(input) {
                session.addInput(input)
                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                }
            }
            Task {
                session.startRunning()
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    func stopSession() {
        session.stopRunning()
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        self.photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let completion = self.completion {
            if let imageData = photo.fileDataRepresentation(),
               let uiImage = UIImage(data: imageData) {
                completion(uiImage)
            } else {
                completion(nil)
            }
        }
    }
}
