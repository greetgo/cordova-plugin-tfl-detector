// Copyright 2019 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import AVFoundation



protocol CameraFeedManagerDelegate: class {

    func didOutput(pixelBuffer: CVPixelBuffer)
    func presentCameraPermissionsDeniedAlert()
    func presentVideoConfigurationErrorAlert()
    func sessionRunTimeErrorOccured()
    func sessionWasInterrupted(canResumeManually resumeManually: Bool)
    func sessionInterruptionEnded()
    func sendImage(image: UIImage)
}



enum CameraConfiguration {
      case success
      case failed
      case permissionDenied
}



class CameraFeedManager: NSObject, AVCapturePhotoCaptureDelegate {


    // MARK: - Camera Related Instance Variables
    var session: AVCaptureSession = AVCaptureSession()
    private let previewView: PreviewView
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var cameraConfiguration: CameraConfiguration = .failed
    private lazy var videoDataOutput = AVCaptureVideoDataOutput()
    private var isSessionRunning = false
    private var isBackCamera = false



    // MARK: - CameraFeedManagerDelegate
    weak var delegate: CameraFeedManagerDelegate?



    // MARK: - Initializer
    init(previewView: PreviewView, isBackCamera: Bool) {
        self.previewView = previewView
        self.isBackCamera = isBackCamera
        super.init()

        // Initializes the session
        session.sessionPreset = .high
        self.previewView.session = session
        self.previewView.previewLayer.connection?.videoOrientation = .portrait
        self.previewView.previewLayer.videoGravity = .resizeAspectFill
        self.attemptToConfigureSession()
      }



    // MARK: - Session Start and End methods
    func checkCameraConfigurationAndStartSession() {
        sessionQueue.async {
            switch self.cameraConfiguration {
            case .success:
                self.addObservers()
                self.startSession()
            case .failed:
                DispatchQueue.main.async {
                    self.delegate?.presentVideoConfigurationErrorAlert()
                }
            case .permissionDenied:
                DispatchQueue.main.async {
                    self.delegate?.presentCameraPermissionsDeniedAlert()
                }
            }
        }
    }
    func stopSession() {
        self.removeObservers()
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
    }
    func resumeInterruptedSession(withCompletion completion: @escaping (Bool) -> ()) {

        sessionQueue.async {
            self.startSession()

            DispatchQueue.main.async {
                completion(self.isSessionRunning)
            }
        }
    }

    private func startSession() {
        self.session.startRunning()
        self.isSessionRunning = self.session.isRunning
      }
    private func attemptToConfigureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.cameraConfiguration = .success
        case .notDetermined:
            self.sessionQueue.suspend()
            self.requestCameraAccess(completion: { (granted) in
                self.sessionQueue.resume()
            })
        case .denied:
            self.cameraConfiguration = .permissionDenied
        default:
            break
        }
        self.sessionQueue.async {
            self.configureSession()
        }
    }
    private func requestCameraAccess(completion: @escaping (Bool) -> ()) {
        AVCaptureDevice.requestAccess(for: .video) { (granted) in
            if !granted {
                self.cameraConfiguration = .permissionDenied
            }
            else {
                self.cameraConfiguration = .success
            }
            completion(granted)
        }
    }
    private func configureSession() {

        guard cameraConfiguration == .success else {
            return
        }
        session.beginConfiguration()

        // Tries to add an AVCaptureDeviceInput.
        guard addVideoDeviceInput() == true else {
            self.session.commitConfiguration()
            self.cameraConfiguration = .failed
            return
        }

        // Tries to add an AVCaptureVideoDataOutput.
        guard addVideoDataOutput() else {
            self.session.commitConfiguration()
            self.cameraConfiguration = .failed
            return
        }

        session.commitConfiguration()
        self.cameraConfiguration = .success
    }
    private func addVideoDeviceInput() -> Bool {

        guard let camera  = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: isBackCamera ? .back : .front) else {
            fatalError("Cannot find camera")
        }
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)

                return true
            }
            else {
                return false
            }
        }
        catch {
            fatalError("Cannot create video device input")
        }
    }
    private func addVideoDataOutput() -> Bool {

        let sampleBufferQueue = DispatchQueue(label: "sampleBufferQueue")
        videoDataOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]

        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
            return true
        }
        return false
    }

    func removeInputSession() {
        session.beginConfiguration()
        if let inputs = session.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                session.removeInput(input)
            }
        }
        session.commitConfiguration()
    }


    // MARK: - Notification Observer Handling
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(CameraFeedManager.sessionRuntimeErrorOccured(notification:)), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(CameraFeedManager.sessionWasInterrupted(notification:)), name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(CameraFeedManager.sessionInterruptionEnded), name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
      }
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
      }



    // MARK: - Notification Observers
    @objc func sessionWasInterrupted(notification: Notification) {

        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
          let reasonIntegerValue = userInfoValue.integerValue,
          let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
          print("Capture session was interrupted with reason \(reason)")

          var canResumeManually = false
          if reason == .videoDeviceInUseByAnotherClient {
            canResumeManually = true
          } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
            canResumeManually = false
          }

          self.delegate?.sessionWasInterrupted(canResumeManually: canResumeManually)

        }
      }
    @objc func sessionInterruptionEnded(notification: Notification) {

        self.delegate?.sessionInterruptionEnded()
      }
    @objc func sessionRuntimeErrorOccured(notification: Notification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
          return
        }

        print("Capture session runtime error: \(error)")

        if error.code == .mediaServicesWereReset {
          sessionQueue.async {
            if self.isSessionRunning {
              self.startSession()
            } else {
              DispatchQueue.main.async {
                self.delegate?.sessionRunTimeErrorOccured()
              }
            }
          }
        } else {
          self.delegate?.sessionRunTimeErrorOccured()

        }
      }



    // MARK: - Camera switcher
    var frontDevice: AVCaptureDevice?
    var frontInput: AVCaptureInput?
    func openCameraFront() -> Void {
        if let frontDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .front).devices.first {
          frontInput = try? AVCaptureDeviceInput(device: frontDevice)
        }
        session.beginConfiguration()
        if let inputs = session.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                session.removeInput(input)
            }
        }
        let front = frontInput
        session.addInput(front!)
        session.commitConfiguration()
    }
    func openCameraBack() -> Void {
        if let frontDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices.first {
          frontInput = try? AVCaptureDeviceInput(device: frontDevice)
        }
        session.beginConfiguration()
        if let inputs = session.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                session.removeInput(input)
            }
        }
        let front = frontInput
        session.addInput(front!)
        session.commitConfiguration()
    }



    // MARK: - Shot image
    var capturePhotoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    @objc var captureDevice: AVCaptureDevice?

    func shotPhotoBack() -> Void {
        self.session = AVCaptureSession()
        self.session.sessionPreset = .photo
        self.capturePhotoOutput = AVCapturePhotoOutput()
        self.captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        let input = try! AVCaptureDeviceInput(device: self.captureDevice!)
        self.session.addInput(input)
        self.session.addOutput(self.capturePhotoOutput!)

        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.previewLayer?.frame = self.previewView.bounds
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        self.previewView.layer.addSublayer(self.previewLayer!)

        self.session.startRunning()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        let photoSettings : AVCapturePhotoSettings!
        photoSettings = AVCapturePhotoSettings.init(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoSettings.isAutoStillImageStabilizationEnabled = true
        photoSettings.flashMode = .off
        photoSettings.isHighResolutionPhotoEnabled = false
        self.capturePhotoOutput?.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    func shotPhotoFront() -> Void {
        self.session = AVCaptureSession()
        self.session.sessionPreset = .photo
        self.capturePhotoOutput = AVCapturePhotoOutput()
        self.captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        let input = try! AVCaptureDeviceInput(device: self.captureDevice!)
        self.session.addInput(input)
        self.session.addOutput(self.capturePhotoOutput!)

        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.previewLayer?.frame = self.previewView.bounds
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        self.previewView.layer.addSublayer(self.previewLayer!)

        self.session.startRunning()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        let photoSettings : AVCapturePhotoSettings!
        photoSettings = AVCapturePhotoSettings.init(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoSettings.isAutoStillImageStabilizationEnabled = true
        photoSettings.flashMode = .off
        photoSettings.isHighResolutionPhotoEnabled = false
        self.capturePhotoOutput?.capturePhoto(with: photoSettings, delegate: self)
        }
    }
}



// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraFeedManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        // Converts the CMSampleBuffer to a CVPixelBuffer.
        let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(sampleBuffer)

        guard let imagePixelBuffer = pixelBuffer else {
          return
        }

        // Delegates the pixel buffer to the ViewController.
        delegate?.didOutput(pixelBuffer: imagePixelBuffer)
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("error occured : \(error.localizedDescription)")
        }

        if let dataImage = photo.fileDataRepresentation() {
            print(UIImage(data: dataImage)?.size as Any)

            let dataProvider = CGDataProvider(data: dataImage as CFData)
            let cgImageRef: CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: isBackCamera ? UIImage.Orientation.right : UIImage.Orientation.leftMirrored)

            self.startSession()
            delegate?.sendImage(image: image)
        } else {
            print("some error here")
        }
    }
}


