import SwiftUI
import AVFoundation
import UIKit

/// Camera QR Code Scanner with Viewfinder & Torch Toggle
public struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScanned: (String) -> Void
    
    @State private var isTorchOn: Bool = false
    @State private var scanLineOffset: CGFloat = -110
    
    public init(onScanned: @escaping (String) -> Void) {
        self.onScanned = onScanned
    }
    
    public var body: some View {
        ZStack {
            // Camera feed
            CameraPreviewRepresentable(isTorchOn: isTorchOn) { code in
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
                dismiss()
                onScanned(code)
            }
            .edgesIgnoringSafeArea(.all)
            
            // Dark vignette overlay with cutout for viewfinder
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .frame(width: 250, height: 250)
                                .blendMode(.destinationOut)
                        )
                )
            
            // Target Viewfinder Frame
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: 250, height: 250)
                
                // Animated Laser Scanner Line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primary.opacity(0.1), AppTheme.primary, AppTheme.primary.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 230, height: 3)
                    .offset(y: scanLineOffset)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.8)
                            .repeatForever(autoreverses: true)
                        ) {
                            scanLineOffset = 110
                        }
                    }
                
                // Corner accents
                CornerBorders()
                    .frame(width: 250, height: 250)
            }
            
            // UI Overlay Controls
            VStack {
                // Top Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Spacer()
                    
                    Text("Scan QR Code")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        isTorchOn.toggle()
                    } label: {
                        Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 22))
                            .foregroundColor(isTorchOn ? .yellow : .white.opacity(0.85))
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Helper Prompt
                VStack(spacing: 6) {
                    Text("Point your camera at the QR code on your PC screen")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("(Run pc_sender.py on your computer)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.65))
                .cornerRadius(14)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Viewfinder Corner Accents
private struct CornerBorders: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let length: CGFloat = 28
            let stroke: CGFloat = 4
            
            Path { path in
                // Top Left
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: 16))
                path.addQuadCurve(to: CGPoint(x: 16, y: 0), control: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
                
                // Top Right
                path.move(to: CGPoint(x: w - length, y: 0))
                path.addLine(to: CGPoint(x: w - 16, y: 0))
                path.addQuadCurve(to: CGPoint(x: w, y: 16), control: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: length))
                
                // Bottom Left
                path.move(to: CGPoint(x: 0, y: h - length))
                path.addLine(to: CGPoint(x: 0, y: h - 16))
                path.addQuadCurve(to: CGPoint(x: 16, y: h), control: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: length, y: h))
                
                // Bottom Right
                path.move(to: CGPoint(x: w - length, y: h))
                path.addLine(to: CGPoint(x: w - 16, y: h))
                path.addQuadCurve(to: CGPoint(x: w, y: h - 16), control: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w, y: h - length))
            }
            .stroke(AppTheme.primary, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
        }
    }
}

// MARK: - Camera Feed View Representable
private struct CameraPreviewRepresentable: UIViewControllerRepresentable {
    var isTorchOn: Bool
    var onDetected: (String) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.setTorch(on: isTorchOn)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDetected: onDetected)
    }
    
    class Coordinator: NSObject, CameraViewControllerDelegate {
        let onDetected: (String) -> Void
        private var hasDetected = false
        
        init(onDetected: @escaping (String) -> Void) {
            self.onDetected = onDetected
        }
        
        func didScanCode(_ code: String) {
            guard !hasDetected else { return }
            hasDetected = true
            DispatchQueue.main.async { [weak self] in
                self?.onDetected(code)
            }
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func didScanCode(_ code: String)
}

class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: CameraViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        
        session.addInput(input)
        
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        
        self.previewLayer = preview
        self.captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {}
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = readable.stringValue else { return }
        
        delegate?.didScanCode(stringValue)
    }
}
