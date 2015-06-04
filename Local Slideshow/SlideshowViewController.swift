//
//  SlideshowViewController.swift
//  Local Slideshow
//
//  Created by Vincent Polsinelli on 2015-06-03.
//  Copyright (c) 2015 Vincent Polsinelli. All rights reserved.
//

import UIKit
import MultipeerConnectivity
import MessageUI

class SlideshowViewController : UIViewController {
    
    var advertiser : MCNearbyServiceAdvertiser!
    var session : MCSession!
    var peerID: MCPeerID = MCPeerID(displayName: "SERVER:" + UIDevice.currentDevice().name)

    @IBOutlet var buttons: [UIButton]!
    
    var slideshowTitle : String? {
        didSet {
            
            if slideshowTitle == "" {
                slideshowTitle = "Bride and Groom"
            }
            
            if let slideshowTitle = slideshowTitle, let titleLabel = self.titleLabel {
                UIView.transitionWithView(titleLabel, duration: 1.0, options: (UIViewAnimationOptions.CurveEaseInOut |
                    UIViewAnimationOptions.TransitionCrossDissolve), animations: { () -> Void in
                        self.titleLabel?.text = slideshowTitle + "\n" + NSDateFormatter.localizedStringFromDate(NSDate(), dateStyle: NSDateFormatterStyle.LongStyle, timeStyle: NSDateFormatterStyle.NoStyle)
                }, completion: nil)
            }
        }
    }
    
    @IBOutlet var titleLabel : UILabel?
    @IBOutlet var imageView : UIImageView?
    
    var images : NSMutableArray = NSMutableArray()
    var imageIndex = 0
    var timer : NSTimer?
    
    func getImageWithColor(color: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(10, 10), false, 0)
        color.setFill()
        UIRectFill(CGRectMake(0, 0, 100, 100))
        var image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.titleLabel?.layer.shadowRadius = 20
        //self.titleLabel?.layer.shadowOffset = CGSizeZero
        self.titleLabel?.layer.shadowOpacity = 1
        self.titleLabel?.text = ""
        
        
        self.images.addObject(self.getImageWithColor(UIColor.clearColor()))
        
        updateButtons()
        
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.None)
        self.session.delegate = self
        self.advertiser = MCNearbyServiceAdvertiser(peer: self.peerID, discoveryInfo: nil, serviceType: "LocalSlideshow")
        self.advertiser.delegate = self
        self.startAdvertising()
        
        
    }
    
    @IBAction func resetSlideshow(sender: UIButton?) {
        while self.images.count > 1 {
            self.images.removeLastObject()
        }
        self.tapGestureHandler(nil)
        updateButtons()
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        showTitlePopup()
        
        if self.timer == nil {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(5, target:self, selector: "loadNextImage", userInfo: nil, repeats: true)
        }
    }
    
    
    func showTitlePopup() {
        var alert = UIAlertController(title: nil, message: "Name of the Bride and Groom", preferredStyle: UIAlertControllerStyle.Alert)
        let saveAction = UIAlertAction(title: "Start", style: UIAlertActionStyle.Default) { ( alertAction : UIAlertAction!) -> Void in
            if let textField = alert.textFields?.first as? UITextField {
                self.slideshowTitle = textField.text
            }
        }
        alert.addAction(saveAction)
        alert.addTextFieldWithConfigurationHandler({(textField: UITextField!) in
            //textField.placeholder = "Bride and Groom"
        })
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func startAdvertising() {
        self.advertiser.startAdvertisingPeer()
    }
    
    @IBAction func pressShare(sender : UIButton?) {
        
        if self.images.count > 1 {
        
            let items = NSMutableArray()
            for var index : Int = 1; index < self.images.count; index++ {
                items.addObject(self.images[index])
            }
            let controller = UIActivityViewController(activityItems: items as [AnyObject], applicationActivities: nil)
            
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                controller.popoverPresentationController?.sourceView = sender
            }
            
            self.presentViewController(controller, animated: true, completion: nil)
        }
    }
    
    func loadNextImage() {
        
        
        let nextIndex = self.imageIndex + 1
        self.imageIndex = (nextIndex > self.images.count - 1) ? 0 : nextIndex
        
        
        CATransaction.begin()
        
        CATransaction.setAnimationDuration(1)
        let transition = CATransition()
        transition.type = kCATransitionFade
        /*
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromRight
        */
        
        self.imageView?.layer.addAnimation(transition, forKey: kCATransition)
        self.imageView?.image = self.images[self.imageIndex] as? UIImage
        if self.imageIndex == 0 {
            self.imageView?.backgroundColor = UIColor.clearColor()
        }
        else {
            self.imageView?.backgroundColor = UIColor.blackColor()
        }
        
        CATransaction.commit()
    }
    
    func updateButtons() {
        for aButton in self.buttons {
            aButton.enabled = self.images.count > 1
        }
    }
    
    @IBAction func tapGestureHandler(gestureHandler : UITapGestureRecognizer?) {
        for aButton in self.buttons {
            if aButton.hidden {
                aButton.alpha = 0
                aButton.hidden = false
            }
            
            UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: UIViewAnimationOptions.BeginFromCurrentState, animations: { () -> Void in
                aButton.alpha = (aButton.alpha == 0) ? 1 : 0
                }, completion: { (finished : Bool) -> Void in
                    if aButton.alpha == 0 {
                        aButton.hidden = true
                    }
            })
        }
    }
}

extension SlideshowViewController : MCNearbyServiceAdvertiserDelegate {
    // auto accept invite form people who arent servers
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didReceiveInvitationFromPeer peerID: MCPeerID!, withContext context: NSData!, invitationHandler: ((Bool, MCSession!) -> Void)!) {

        if peerID.displayName.hasPrefix("SERVER:") == false {
            invitationHandler(true, self.session);
        }
        else {
            invitationHandler(false, nil);
        }
    }
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didNotStartAdvertisingPeer error: NSError!) {
        
    }
}

extension SlideshowViewController : MCSessionDelegate {
    
    // needed to approve connection to peer
    func session(session: MCSession!, didReceiveCertificate certificate: [AnyObject]!, fromPeer peerID: MCPeerID!, certificateHandler: ((Bool) -> Void)!) {
        certificateHandler(true)
    }
    
    // called when image is recieved
    func session(session: MCSession!, didReceiveData data: NSData!, fromPeer peerID: MCPeerID!) {
        if let image = UIImage(data: data) {
            self.images.addObject(image)
        }
        
        
        // send back a message to update the status
        let message = "Sent"
        let messageData = message.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        
        var error : NSError?
        self.session.sendData(messageData, toPeers: [peerID], withMode: MCSessionSendDataMode.Reliable, error: &error)
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.updateButtons()
        })
        
        
    }
    
    // just for logging
    func session(session: MCSession!, peer peerID: MCPeerID!, didChangeState state: MCSessionState) {
        if (state == MCSessionState.Connecting) {
            NSLog("%@ received MCSessionStateConnecting for %@", self.peerID.displayName, peerID.displayName);
        }
        else if (state == MCSessionState.Connected) {
            NSLog("%@ received MCSessionStateConnected for %@", self.peerID.displayName, peerID.displayName);
        } else if (state == MCSessionState.NotConnected) {
            NSLog("%@ received MCSessionStateNotConnected for %@", self.peerID.displayName, peerID.displayName);
        }
    }
    
    func session(session: MCSession!, didFinishReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, atURL localURL: NSURL!, withError error: NSError!) {
        
    }
    
    func session(session: MCSession!, didReceiveStream stream: NSInputStream!, withName streamName: String!, fromPeer peerID: MCPeerID!) {
        
    }
    
    func session(session: MCSession!, didStartReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, withProgress progress: NSProgress!) {
        
    }
    
    
}
