//
//  CameraViewController.swift
//  Local Slideshow
//
//  Created by Vincent Polsinelli on 2015-06-03.
//  Copyright (c) 2015 Vincent Polsinelli. All rights reserved.
//

import AVFoundation
import UIKit
import MobileCoreServices
import MultipeerConnectivity


class CameraViewController : UIViewController, UINavigationControllerDelegate {
    
    @IBOutlet var statusLabel : UILabel?
    
    // Multipeer
    var browser : MCNearbyServiceBrowser?
    var session : MCSession!
    var peerID: MCPeerID!
    
    // image capturing
    let captureSession = AVCaptureSession()
    var previewLayer : AVCaptureVideoPreviewLayer?
    var stillImageOutput: AVCaptureStillImageOutput = AVCaptureStillImageOutput()
    var captureDevice : AVCaptureDevice?
    
    // misc camera UI
    @IBOutlet var cameraButton : UIButton?
    @IBOutlet var imagePreview : UIImageView?
    @IBOutlet var tempImageView : UIImageView?
    @IBOutlet var imageViews: [UIImageView]!
    var originalPicture : UIImage?
    
    // countdown timer
    var countdownTimer : NSTimer?
    var startTime = NSTimeInterval()
    
    // filters
    let filterNames = ["CISepiaTone", "CIColorInvert", "CIPhotoEffectNoir", "CIPhotoEffectChrome", "CIPhotoEffectFade", "CIPhotoEffectInstant", "CIPhotoEffectTonal", "CIPhotoEffectTransfer"]
    var filterIndex = -1
    
    // drawing
    var swiped = false
    var brushWidth: CGFloat = 10.0
    var opacity: CGFloat = 1.0
    var lastPoint = CGPoint.zeroPoint
    var red: CGFloat = 51.0 / 255.0
    var green: CGFloat = 204.0 / 255.0
    var blue: CGFloat = 1.0
    
    // MARK: view methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.statusLabel?.text = "Looking for server..."
        self.statusLabel?.layer.shadowRadius = 5
        self.statusLabel?.layer.shadowOpacity = 1
        self.statusLabel?.layer.shadowColor = UIColor.blackColor().CGColor
        
        self.cameraButton?.hidden = true
        self.cameraButton?.layer.shadowRadius = 20
        self.cameraButton?.layer.shadowOpacity = 1
        self.cameraButton?.layer.shadowColor = UIColor.whiteColor().CGColor
        
        self.peerID = MCPeerID(displayName: UIDevice.currentDevice().name)
        self.session = MCSession(peer: self.peerID, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.None)
        self.session.delegate = self
        
        let devices = AVCaptureDevice.devices()
        
        // Loop through all the capture devices on this phone
        for device in devices {
            // Make sure this particular device supports video
            if (device.hasMediaType(AVMediaTypeVideo)) {
                // Finally check the position and confirm we've got the back camera
                if(device.position == AVCaptureDevicePosition.Front) {
                    captureDevice = device as? AVCaptureDevice
                    if captureDevice != nil {
                        stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
                        
                        var err : NSError? = nil
                        captureSession.addInput(AVCaptureDeviceInput(device: captureDevice, error: &err))
                        captureSession.addOutput(stillImageOutput)
                        
                        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                        previewLayer?.connection.videoOrientation = self.videoOrientationForDevice()
                        self.view.layer.insertSublayer(previewLayer, atIndex: 0)
                        previewLayer?.frame = self.view.layer.frame
                        captureSession.startRunning()
                    }
                }
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.browser == nil {
            self.browser = MCNearbyServiceBrowser(peer: self.peerID, serviceType: "LocalSlideshow")
            self.browser?.delegate = self
            self.browser?.startBrowsingForPeers()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let previewLayer = self.previewLayer {
            previewLayer.frame = self.view.bounds
        }
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        if let connection = self.previewLayer?.connection {
            connection.videoOrientation = self.videoOrientationForDevice()
        }
        
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
    }
    
    
    // MARK: Actions
    
    func sendImage(image : UIImage) {
        let data = NSData(data: UIImageJPEGRepresentation(image, 1.0))
        
        self.statusLabel?.text = "Sending"
        
        var error : NSError?
        self.session.sendData(data, toPeers: self.session.connectedPeers, withMode: MCSessionSendDataMode.Reliable, error: &error)
    }
    
    func updateImageViews() {
        for aView in self.imageViews {
            aView.hidden = self.originalPicture == nil
        }
    }
    
    @IBAction func cancelPicture(sender: AnyObject?) {
        self.originalPicture = nil
        self.updateImageViews()
        self.imagePreview?.image = nil
        self.tempImageView?.image = nil
        self.navigationController?.setToolbarHidden(true, animated: true)
    }
    
    @IBAction func takePicture(sender: AnyObject?) {
        
        if let image = self.imagePreview?.image {
            self.sendImage(image)
            self.cancelPicture(sender)
        }
        else {
            
            self.cameraButton?.hidden = true
            self.statusLabel?.text = "5" // timer starts in 1 sec so update label now
            startTime = NSDate.timeIntervalSinceReferenceDate()
            countdownTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "updateCountdown", userInfo: nil, repeats: true)
            
            
        }
    }
    
    func updateCountdown() {
        let elapsedTime = NSDate.timeIntervalSinceReferenceDate() - self.startTime
        if elapsedTime > 5 {
            self.countdownTimer?.invalidate()
            if let videoConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo) {
                let videoOrientation = videoConnection.videoOrientation
                let deviceOrientation = UIDevice.currentDevice().orientation
                
                stillImageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection, completionHandler: {(sampleBuffer : CMSampleBuffer!, error : NSError!) in
                    
                    var imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    var dataProvider = CGDataProviderCreateWithCFData(imageData)
                    var cgImageRef = CGImageCreateWithJPEGDataProvider(dataProvider, nil, true, kCGRenderingIntentDefault)
                    if let image = UIImage(CGImage: cgImageRef, scale: 1.0, orientation: self.imageOrientationForDeviceOrientation(deviceOrientation)) {
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            self.statusLabel?.text = ""
                            self.originalPicture = image
                            self.imagePreview?.image = image
                            self.updateImageViews()
                            self.navigationController?.setToolbarHidden(false, animated: true)
                            self.cameraButton?.hidden = false
                        })
                    }
                })
            }
        }
        else {
            let remaining = 6 - elapsedTime
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.statusLabel?.text = String(Int(remaining))
            })
        }
    }
    
    @IBAction func resetPicture(sender: AnyObject?) {
        self.imagePreview?.image = self.originalPicture
    }
    
    @IBAction func changeFilter(sender : AnyObject?) {
        if let image = self.originalPicture {
            
            self.filterIndex++
            
            if self.filterIndex >= self.filterNames.count {
                self.filterIndex = -1
            }
            else if self.filterIndex < -1 {
                self.filterIndex = self.filterNames.count - 1
            }
            
            if self.filterIndex >= 0 {
                let beginImage = CIImage(CGImage: image.CGImage)
                let filter = CIFilter(name: self.filterNames[self.filterIndex])
                filter.setValue(beginImage, forKey: kCIInputImageKey)
                
                
                
                let context = CIContext(options:[kCIContextUseSoftwareRenderer : true])
                let cgimg = context.createCGImage(filter.outputImage, fromRect: filter.outputImage.extent())
                if let newImage = UIImage(CGImage: cgimg, scale: 1.0, orientation: image.imageOrientation) {
                    self.imagePreview?.image = newImage
                }
            }
            else {
                self.imagePreview?.image = image
            }
        }
    }
    
    
    // MARK: touch stuff
    
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        swiped = false
        
        if self.originalPicture != nil {
        
        if let touch = touches.first as? UITouch {
            lastPoint = touch.locationInView(self.view)
        }
        }
    }
    
    func drawLineFrom(fromPoint: CGPoint, toPoint: CGPoint) {
        if self.originalPicture != nil, let tempImageView = self.tempImageView {
            UIGraphicsBeginImageContext(view.frame.size)
            let context = UIGraphicsGetCurrentContext()
            tempImageView.image?.drawInRect(CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height))
            
            CGContextMoveToPoint(context, fromPoint.x, fromPoint.y)
            CGContextAddLineToPoint(context, toPoint.x, toPoint.y)
            
            CGContextSetLineCap(context, kCGLineCapRound)
            CGContextSetLineWidth(context, brushWidth)
            CGContextSetRGBStrokeColor(context, red, green, blue, 1.0)
            CGContextSetBlendMode(context, kCGBlendModeNormal)
            
            CGContextStrokePath(context)
            
            tempImageView.image = UIGraphicsGetImageFromCurrentImageContext()
            tempImageView.alpha = opacity
            UIGraphicsEndImageContext()
        }
        
    }
    
    override func touchesMoved(touches: Set<NSObject>, withEvent event: UIEvent) {
        
        if self.originalPicture != nil {
        
        swiped = true
        if let touch = touches.first as? UITouch {
            let currentPoint = touch.locationInView(view)
            drawLineFrom(lastPoint, toPoint: currentPoint)
            
            lastPoint = currentPoint
        }
        }
    }
    
    override func touchesEnded(touches: Set<NSObject>, withEvent event: UIEvent) {
        
        if (self.originalPicture != nil) {
            if !swiped {
                // draw a single point
                drawLineFrom(lastPoint, toPoint: lastPoint)
            }
            
            if let imagePreview = self.imagePreview, let tempImageView = self.tempImageView {
                UIGraphicsBeginImageContext(imagePreview.frame.size)
                imagePreview.image?.drawInRect(CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height), blendMode: kCGBlendModeNormal, alpha: 1.0)
                tempImageView.image?.drawInRect(CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height), blendMode: kCGBlendModeNormal, alpha: opacity)
                imagePreview.image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                self.tempImageView?.image = nil
            }
        }
    }
    
    // MARK: helpers
    func videoOrientationForDevice() -> AVCaptureVideoOrientation {
        switch UIDevice.currentDevice().orientation {
        case .LandscapeRight:
            return AVCaptureVideoOrientation.LandscapeLeft
        case .LandscapeLeft:
            return AVCaptureVideoOrientation.LandscapeRight
        case .Portrait:
            return AVCaptureVideoOrientation.Portrait
        case .PortraitUpsideDown:
            return AVCaptureVideoOrientation.PortraitUpsideDown
        default:
            return AVCaptureVideoOrientation.Portrait
        }
    }
    
    func imageOrientationForDeviceOrientation(orientation : UIDeviceOrientation) -> UIImageOrientation {
        switch orientation {
        case .LandscapeRight:
            return UIImageOrientation.Up
        case .LandscapeLeft:
            return UIImageOrientation.Down
        case .Portrait:
            return UIImageOrientation.LeftMirrored
        case .PortraitUpsideDown:
            return UIImageOrientation.Right
        default:
            return UIImageOrientation.LeftMirrored
        }
    }
    
}

extension CameraViewController : MCNearbyServiceBrowserDelegate {
    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        
        // only send invites to servers
        if peerID.displayName.hasPrefix("SERVER:") {
            browser.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 30)
        }
    }
    
    func browser(browser: MCNearbyServiceBrowser!, lostPeer peerID: MCPeerID!) {
        
    }
}

extension CameraViewController : MCBrowserViewControllerDelegate {
    func browserViewControllerDidFinish(browserViewController: MCBrowserViewController!) {
        
    }
    
    func browserViewControllerWasCancelled(browserViewController: MCBrowserViewController!) {
        
    }
}

extension CameraViewController : UIImagePickerControllerDelegate {
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage!, editingInfo: [NSObject : AnyObject]!) {
        
        let data = NSData(data: UIImagePNGRepresentation(image))
        
        self.statusLabel?.text = "Sending"

        var error : NSError?
        self.session.sendData(data, toPeers: self.session.connectedPeers, withMode: MCSessionSendDataMode.Reliable, error: &error)
        
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
}

extension CameraViewController : MCSessionDelegate {
    func session(session: MCSession!, didFinishReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, atURL localURL: NSURL!, withError error: NSError!) {
        
    }
    
    func session(session: MCSession!, didReceiveCertificate certificate: [AnyObject]!, fromPeer peerID: MCPeerID!, certificateHandler: ((Bool) -> Void)!) {
        certificateHandler(true)
    }
    
    func session(session: MCSession!, didReceiveData data: NSData!, fromPeer peerID: MCPeerID!) {
        
        let message = NSString(data: data, encoding: NSUTF8StringEncoding) as String?
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.statusLabel?.text = message
        })

    }
    
    func session(session: MCSession!, didReceiveStream stream: NSInputStream!, withName streamName: String!, fromPeer peerID: MCPeerID!) {
        
    }
    
    func session(session: MCSession!, didStartReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, withProgress progress: NSProgress!) {
        
    }
    
    func session(session: MCSession!, peer peerID: MCPeerID!, didChangeState state: MCSessionState) {
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
        
            if (state == MCSessionState.Connecting) {
                self.statusLabel?.text = "Connecting"
            }
            
            if state == MCSessionState.NotConnected {
                //self.statusLabel?.text = "Not Connected"
                //self.cameraButton?.hidden = true
                
                // reconnect when disconnected
                self.browser?.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 30)
            }
            
            if (state == MCSessionState.Connected) {
                self.statusLabel?.text = "Connected"
                self.cameraButton?.hidden = false
            }
        })
    }
}

