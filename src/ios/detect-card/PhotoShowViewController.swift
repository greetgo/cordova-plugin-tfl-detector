//
//  PhotoShowViewController.swift
//  ObjectDetection
//
//  Created by greetgo on 7/8/20.
//  Copyright © 2020 Y Media Labs. All rights reserved.
//

import UIKit

class PhotoShowViewController: UIViewController {

    lazy var imagePhoto: UIImageView = {
        let image = UIImageView()
        return image
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        view.addSubview(imagePhoto)
        imagePhoto.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.7)
            make.height.equalToSuperview().multipliedBy(0.5)
        }
    }
    
    init(image: UIImage) {
        super.init(nibName: nil, bundle: nil)
        self.imagePhoto.image = image
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
