//
//  Camera.swift
//  Alib
//
//  Created by renan jegouzo on 28/02/2017.
//  Copyright © 2017 aestesis. All rights reserved.
//
import Foundation
import AVFoundation
import Metal
import MetalKit

/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public class Camera : NodeUI {
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    public let onNewFrame = Event<Void>()
    public private(set) var preview:SharedBitmap?
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    let queue = DispatchQueue(label: "CameraSampleBufferQueue")
    var session: AVCaptureSession?
    var input: AVCaptureDeviceInput?
    var output: AVCaptureOutput?
    var delgate: VideoDelegate?
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    var deviceId : String?
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    public init(parent:NodeUI,deviceId:String? = nil) {
        self.deviceId = deviceId
        super.init(parent:parent)
    }
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    override public func detach() {
        stop()
        onNewFrame.removeAll()
        preview?.detach()
        preview = nil
        super.detach()
    }
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    public func start() {
        session = AVCaptureSession()
        session!.sessionPreset = AVCaptureSession.Preset.high
        // needs access granted before (ex: in aestesis at camera module instanciation)
        self.grantedStart()
    }
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    func grantedStart() {
        let vdev = deviceId == nil ? AVCaptureDevice.default(for:AVMediaType.video) : AVCaptureDevice(uniqueID: deviceId!)
        if let vdev = vdev {
            do {
                let vinput = try AVCaptureDeviceInput(device: vdev)
                if !self.session!.canAddInput(vinput) {
                    Debug.error("Camera input problems")
                }
                session!.addInput(vinput)
                self.input = vinput
                let voutput = AVCaptureVideoDataOutput()
                voutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]
                voutput.alwaysDiscardsLateVideoFrames = true
                let vdel = VideoDelegate()
                vdel.onFrame.alive(self) { sampleBuffer in
                    if let imgbuf = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        self.preview = SharedBitmap(parent:self,pixelBuffer: imgbuf)
                        self.onNewFrame.dispatch(())
                    }
                }
                voutput.setSampleBufferDelegate(vdel,queue:queue)
                self.delgate = vdel
                if !session!.canAddOutput(voutput) {
                    Debug.error("Camera output problems")
                }
                // TODO: add AVCaptureMetadataOutput()  to get qr code, etc..
                session!.addOutput(voutput)
                self.output = voutput
                addObservers(session: session!)
                //session!.commitConfiguration()
                session!.startRunning()
            } catch {
                Debug.error("Camera.start(), error \(error)")
            }
        }
    }
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    public func stop() {
        if let session = self.session {
            removeObservers(session: session)
            session.stopRunning()
            if let output = output {
                session.removeOutput(output)
            }
            if let input = input {
                session.removeInput(input)
            }
            self.session = nil
            self.input = nil
            self.output = nil
            self.delgate = nil
        }
    }
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    @objc
    func notification(not:Notification) {
        Debug.info(not.description)
    }
    private func addObservers(session:AVCaptureSession) {
        NotificationCenter.default.addObserver(self, selector: #selector(self.notification), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(self.notification), name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(self.notification), name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
    }
    
    private func removeObservers(session:AVCaptureSession) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
    }
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    class VideoDelegate : NSObject,AVCaptureVideoDataOutputSampleBufferDelegate {
        let onFrame = Event<CMSampleBuffer>()
        public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            Debug.info("Camera: frame dropped")
        }
        public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            onFrame.dispatch(sampleBuffer)
            
        }
    }
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
