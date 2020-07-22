//
//  BackCameraViewController.swift
//  AixDetected
//
//  Created by greetgo on 7/9/20.
//  Copyright © 2020 greetgo. All rights reserved.
//

import UIKit
import AVFoundation

class FontCameraViewController: UIViewController {


    var segmentSelectionAtIndex: ((String) -> ())?
    var segmentSelectionAtIndex2: ((NSData) -> ())?



    // MARK: - Constants
    private let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
    private let edgeOffset: CGFloat = 2.0
    private let labelOffset: CGFloat = 10.0
    private let animationDuration = 0.5
    private let collapseTransitionThreshold: CGFloat = -30.0
    private let expandThransitionThreshold: CGFloat = 30.0
    private let delayBetweenInferencesMs: Double = 200
    private var initialBottomSpace: CGFloat = 0.0
    private var isCameraBack: Bool = true



    // MARK: - Properties
    lazy var previewView: PreviewView = {
        let view = PreviewView()
        return view
    }()
    lazy var overlayView: OverlayView = {
        let view = OverlayView()
        return view
    }()
    lazy var resumeButton: UIButton = {
        let btn = UIButton()
        btn.setTitle("resum", for: .normal)
        return btn
    }()
    lazy var cameraUnavailableLabel: UILabel = {
        let label = UILabel()
        label.text = "available"
        return label
    }()



    // MARK: - Holds the results at any time
    private var result: Resultt?
    private var previousInferenceTimeMs: TimeInterval = Date.distantPast.timeIntervalSince1970 * 1000



    // MARK: - Controllers that manage functionality
    private lazy var cameraFeedManager = CameraFeedManager(previewView: previewView, isBackCamera: true)
    private var modelDataHandler: ModelDataHandler? = ModelDataHandler(modelFileInfo: MobileNetSSD.modelInfo, labelsFileInfo: MobileNetSSD.labelsInfo)
    private var inferenceViewController: InferenceViewController?



    // MARK: - Lifecycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        previewView.isHidden = true
        cameraFeedManager.checkCameraConfigurationAndStartSession()
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        guard modelDataHandler != nil else { fatalError("Failed to load model")}
        cameraFeedManager.delegate = self
        overlayView.clearsContextBeforeDrawing = true

        setupViews()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraFeedManager.stopSession()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startCamera()
            self.cameraFeedManager.resumeInterruptedSession { (bool) in
                self.previewView.isHidden = false
            }
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }



    // MARK: - SetupViews
    func setupViews() -> Void {
        view.backgroundColor = hexStringToUIColor(hex: "#1d3664")
        overlayView.backgroundColor = .clear
        self.navigationItem.setHidesBackButton(true, animated: true)

        view.addSubview(previewView)
        previewView.addSubview(overlayView)
        previewView.addSubview(resumeButton)
        previewView.addSubview(cameraUnavailableLabel)

        previewView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        overlayView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        resumeButton.snp.makeConstraints { (make) in
            make.top.equalTo(overlayView.snp.bottom).offset(10)
            make.centerX.equalToSuperview()
            make.width.equalTo(100)
            make.height.equalTo(30)
        }
        cameraUnavailableLabel.snp.makeConstraints { (make) in
            make.top.equalTo(resumeButton.snp.bottom).offset(10)
            make.centerX.equalToSuperview()
            make.width.equalTo(100)
            make.height.equalTo(30)
        }
        
        cameraView.isHidden = true
        view.addSubview(cameraView)
        cameraView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    func hexStringToUIColor (hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }

        if ((cString.count) != 6) {
            return UIColor.gray
        }

        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }

    
    
    // MARK: - New Part
    var captureSession: AVCaptureSession!
    var cameraOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var frontDevice: AVCaptureDevice?
    var frontInput: AVCaptureInput?
    
    lazy var cameraView: UIView = {
        let view = UIView()
        return view
    }()
    
    func startCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        cameraOutput = AVCapturePhotoOutput()

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: device) {
            if (captureSession.canAddInput(input)) {
                captureSession.addInput(input)
                if (captureSession.canAddOutput(cameraOutput)) {
                    captureSession.addOutput(cameraOutput)
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                    previewLayer.frame = cameraView.bounds
                    cameraView.layer.addSublayer(previewLayer)
                    captureSession.startRunning()
                }
            } else { print("issue here : captureSesssion.canAddInput") }
        } else { print("some problem here") }
    }
    func tapShot() -> Void {
        captureSession.startRunning()
        self.cameraOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.cameraOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }
    func tapStop() -> Void {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.removeInputSession()
            self.stopSession()
            self.cameraOutput = nil
            
            self.cameraFeedManager.removeInputSession()
            self.cameraFeedManager.stopSession()
            self.cameraFeedManager.delegate = nil
        }
    }
    
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    
    func removeInputSession() -> Void {
        captureSession.beginConfiguration()
        if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                captureSession.removeInput(input)
            }
        }
        captureSession.commitConfiguration()
    }
    func stopSession() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
}


// MARK: - AVCapturePhotoCaptureDelegate
extension FontCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("error occured : \(error.localizedDescription)")
        }
        if let dataImage = photo.fileDataRepresentation() {
            let dataProvider = CGDataProvider(data: dataImage as CFData)
            let cgImageRef: CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: UIImage.Orientation.right)
            let imageData =  image.jpegData(compressionQuality: 1)
            segmentSelectionAtIndex2?(imageData! as NSData)
        } else {
            print("some error here")
        }
    }
}



// MARK: - InferenceViewControllerDelegate Methods
extension FontCameraViewController: InferenceViewControllerDelegate {
    func didChangeThreadCount(to count: Int) {
                if modelDataHandler?.threadCount == count { return }
                modelDataHandler = ModelDataHandler(
                    modelFileInfo: MobileNetSSD.modelInfo,
                    labelsFileInfo: MobileNetSSD.labelsInfo,
                    threadCount: count
                )
            }
}



// MARK: - CameraFeedManagerDelegate Methods
extension FontCameraViewController: CameraFeedManagerDelegate {


    func didOutput(pixelBuffer: CVPixelBuffer) {
                runModel(onPixelBuffer: pixelBuffer)
            }
    func sendImage(image: UIImage) {
//        self.cameraFeedManager.removeInputSession()
//        self.cameraFeedManager.checkCameraConfigurationAndStartSession()
//        present(PhotoShowViewController(image: image), animated: true)
        let imageData =  image.jpegData(compressionQuality: 1)
        segmentSelectionAtIndex2?(imageData! as NSData)
    }


    // MARK: - Custom functions
    func sessionRunTimeErrorOccured() {
            // Handles session run time error by updating the UI and providing a button if session can be manually resumed.
                self.resumeButton.isHidden = false
            }
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {

            // Updates the UI when session is interupted.
            if resumeManually {
              self.resumeButton.isHidden = false
            }
            else {
              self.cameraUnavailableLabel.isHidden = false
            }
          }
    func sessionInterruptionEnded() {

            // Updates UI once session interruption has ended.
            if !self.cameraUnavailableLabel.isHidden {
              self.cameraUnavailableLabel.isHidden = true
            }

            if !self.resumeButton.isHidden {
              self.resumeButton.isHidden = true
            }
          }
    func presentVideoConfigurationErrorAlert() {

            let alertController = UIAlertController(title: "Confirguration Failed", message: "Configuration of camera has failed.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            alertController.addAction(okAction)

            present(alertController, animated: true, completion: nil)
          }
    func presentCameraPermissionsDeniedAlert() {

            let alertController = UIAlertController(title: "Camera Permissions Denied", message: "Camera permissions have been denied for this app. You can change this by going to Settings", preferredStyle: .alert)

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
//            let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
//                UIApplication.shared.open(URL(string: UIApplication.UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
//            }

            alertController.addAction(cancelAction)
//            alertController.addAction(settingsAction)

            present(alertController, animated: true, completion: nil)

          }


    @objc  func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {

        let currentTimeMs = Date().timeIntervalSince1970 * 1000

        guard  (currentTimeMs - previousInferenceTimeMs) >= delayBetweenInferencesMs else {
          return
        }

        previousInferenceTimeMs = currentTimeMs
        result = self.modelDataHandler?.runModel(onFrame: pixelBuffer)

        guard let displayResult = result else {
          return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        DispatchQueue.main.async {
          // Display results by handing off to the InferenceViewController
          self.inferenceViewController?.resolution = CGSize(width: width, height: height)

          var inferenceTime: Double = 0
          if let resultInferenceTime = self.result?.inferenceTime {
            inferenceTime = resultInferenceTime
          }
          self.inferenceViewController?.inferenceTime = inferenceTime
          self.inferenceViewController?.tableView.reloadData()

          // Draws the bounding boxes and displays class names and confidence scores.
          self.drawAfterPerformingCalculations(onInferences: displayResult.inferences, withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)))
        }
        if displayResult.inferences.count > 0 {
            print("className ", displayResult.inferences[0].className)
            segmentSelectionAtIndex?(displayResult.inferences[0].className)
        }
    }
    func drawAfterPerformingCalculations(onInferences inferences: [Inference], withImageSize imageSize:CGSize) {

            self.overlayView.objectOverlays = []
            self.overlayView.setNeedsDisplay()

            guard !inferences.isEmpty else {
              return
            }

            var objectOverlays: [ObjectOverlay] = []

            for inference in inferences {

              // Translates bounding box rect to current view.
              var convertedRect = inference.rect.applying(CGAffineTransform(scaleX: self.overlayView.bounds.size.width / imageSize.width, y: self.overlayView.bounds.size.height / imageSize.height))

              if convertedRect.origin.x < 0 {
                convertedRect.origin.x = self.edgeOffset
              }

              if convertedRect.origin.y < 0 {
                convertedRect.origin.y = self.edgeOffset
              }

              if convertedRect.maxY > self.overlayView.bounds.maxY {
                convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
              }

              if convertedRect.maxX > self.overlayView.bounds.maxX {
                convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
              }

              let confidenceValue = Int(inference.confidence * 100.0)
              let string = "\(inference.className)  (\(confidenceValue)%)"

              let size = string.size(usingFont: self.displayFont)

              let objectOverlay = ObjectOverlay(name: string, borderRect: convertedRect, nameStringSize: size, color: inference.displayColor, font: self.displayFont)

              objectOverlays.append(objectOverlay)
            }

            // Hands off drawing to the OverlayView
            // Метод рисовать box(block)
//            self.draw(objectOverlays: objectOverlays)
          }
    func draw(objectOverlays: [ObjectOverlay]) {

            self.overlayView.objectOverlays = objectOverlays
            self.overlayView.setNeedsDisplay()
          }
}


