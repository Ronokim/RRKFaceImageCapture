//
//  ViewController.swift
//  FaceDetectionRnD
//
//  Created by Ronald on 16/09/2019.
//  Copyright © 2019 ceva. All rights reserved.
//

import UIKit

class MainViewController: UIViewController, RRKFaceDetectionDelegate {

    @IBOutlet weak var faceImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(true)
//        self.navigationController?.navigationBar.isHidden = true
//    }
    
//    override func viewDidDisappear(_ animated: Bool) {
//        super.viewDidDisappear(true)
//        self.navigationController?.navigationBar.isHidden = false
//    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        self.navigationController?.navigationBar.isHidden = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        self.navigationController?.navigationBar.isHidden = true
    }
    
    @IBAction func takePhotoButtonListener(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        let controller = storyboard.instantiateViewController(withIdentifier: "FaceCaptureViewController") as! FaceCaptureViewController
        controller.delegate = self
//        self.present(controller, animated: false, completion: nil)
       self.navigationController?.pushViewController(controller, animated: true)
    }
    
    func returnFaceImage(faceImage: UIImage) {
        NSLog("MainViewController: returnFaceImage")
        faceImageView.image = faceImage
    }
}

