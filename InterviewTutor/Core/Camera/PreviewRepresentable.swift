import AppKit
import AVFoundation
import SwiftUI

struct CameraPreviewRepresentable: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = PreviewView()
        view.previewLayer = previewLayer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? PreviewView else { return }
        view.previewLayer = previewLayer
    }
}

private final class PreviewView: NSView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            guard let previewLayer else { return }
            previewLayer.frame = bounds
            wantsLayer = true
            layer?.addSublayer(previewLayer)
        }
    }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}
