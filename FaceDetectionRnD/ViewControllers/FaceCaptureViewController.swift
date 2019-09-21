//
//  FaceCaptureViewController.swift
//  FaceDetectionRnD
//
//  Created by Ronald on 16/09/2019.
//  Copyright © 2019 ceva. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import Vision

@objc public protocol RRKFaceDetectionDelegate {
    func returnFaceImage(faceImage: UIImage)
}

class FaceCaptureViewController: UIViewController {
    
    @IBOutlet weak var captureButton: UIButton!
    
    @objc public var delegate: RRKFaceDetectionDelegate?
    //This defines the request handler you’ll be feeding images to from the camera feed
    var sequenceHandler = VNSequenceRequestHandler()
    let session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    let dataOutputQueue = DispatchQueue(
        label: "video data queue",
        qos: .userInitiated,
        attributes: [],
        autoreleaseFrequency: .workItem)
    
    // Vision requests
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    var faceImage: UIImage?
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        self.setButtonTitle(canCapture: false)
        self.prepareVisionRequest()
        session.startRunning()
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        self.navigationController?.navigationBar.isHidden = false
        self.navigationController?.navigationBar.isTranslucent = false
        //        self.navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        session.stopRunning()
    }
    

    func setButtonTitle(canCapture: Bool){
        DispatchQueue.main.async {
            var title: String?
            if canCapture{ title = "Capture" as String} else { title = "No face detected"}
            self.captureButton.setTitle(title, for: .normal)
            self.captureButton.isEnabled = canCapture
        }
    }
}
//self.delegate?.returnFaceImage(faceImage: faceImage!)
//dismiss(animated: true, completion: nil)

// MARK: - capture button methods
extension FaceCaptureViewController {
    @IBAction func captureImageButtonListener(_ sender: UIButton) {
        NSLog("captureImageButtonListener")
        self.delegate?.returnFaceImage(faceImage: faceImage!)
        self.navigationController?.popViewController(animated: true)
//        dismiss(animated: true, completion: nil)
    }
}

// MARK: - Video Processing methods

extension FaceCaptureViewController {
    func configureCaptureSession() {
        // Define the capture device we want to use
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front) else {
                                                    fatalError("No front video camera available")
        }
        
        // Connect the camera to the capture session input
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            session.addInput(cameraInput)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        // Create the video data output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        // Add the video output to the capture session
        session.addOutput(videoOutput)
        
        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
        
        // Configure the preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate methods

extension FaceCaptureViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        // Get the image buffer from the passed in sample buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        guard let requests = self.trackingRequests, !requests.isEmpty else {
            // No tracking object detected, so perform initial detection
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer,
                                                            orientation: .leftMirrored,
                                                            options: requestHandlerOptions)
            
            do {
                guard let detectRequests = self.detectionRequests else {
                    return
                }
                try imageRequestHandler.perform(detectRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceRectangleRequest: %@", error)
            }
            return
        }
        
        do {
            try self.sequenceHandler.perform(requests,
                                             on: imageBuffer,
                                             orientation: .leftMirrored)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
        }
        
        // Setup the next round of tracking.
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in requests {
            
            guard let results = trackingRequest.results else {
                return
            }
            
            guard let observation = results[0] as? VNDetectedObjectObservation else {
                return
            }
            
            if !trackingRequest.isLastFrame {
                if observation.confidence > 0.3 {
                    trackingRequest.inputObservation = observation
                } else {
                    trackingRequest.isLastFrame = true
                }
                newTrackingRequests.append(trackingRequest)
            }
        }
        self.trackingRequests = newTrackingRequests
        
        if newTrackingRequests.isEmpty {
            // Nothing to track, so abort.
            NSLog("--------Nothing to track, so abort")
            self.setButtonTitle(canCapture: false)
            return
        }
        else{
            self.setButtonTitle(canCapture: true)
        }
        
        let ciimage : CIImage = CIImage(cvPixelBuffer: imageBuffer)
        faceImage = UIImage.init(ciImage: ciimage)
    }
}

extension FaceCaptureViewController{
    // MARK: Performing Vision Requests
    
    /// - Tag: WriteCompletionHandler
    func prepareVisionRequest() {
        NSLog("--------prepareVisionRequest")
        //self.trackingRequests = []
        var requests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            NSLog("--------faceDetectionRequest = VNDetectFaceRectanglesRequest")
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                    return
            }
            
            DispatchQueue.main.async {
                // Add the observations to the tracking list
                for observation in results {
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(faceTrackingRequest)
                }
                self.trackingRequests = requests
            }
        })
        
        // Start with detection.  Find face, then track it.
        self.detectionRequests = [faceDetectionRequest]
        
        self.sequenceHandler = VNSequenceRequestHandler()
    }
}
