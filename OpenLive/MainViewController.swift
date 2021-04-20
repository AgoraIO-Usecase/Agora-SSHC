//
//  MainViewController.swift
//  OpenLive
//
//  Created by GongYuhua on 6/25/16.
//  Copyright © 2016 Agora. All rights reserved.
//

import UIKit
import AgoraRtcKit2

enum KTVRole {
    case audience, broadcaster, owner
    
    var description: String {
        switch self {
        case .audience:    return "观众"
        case .broadcaster: return "合唱"
        case .owner:       return "主唱"
        }
    }
}

class MainViewController: UIViewController {

    @IBOutlet weak var roomNameTextField: UITextField!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var logoTop: NSLayoutConstraint!
    @IBOutlet weak var inputTextFieldTop: NSLayoutConstraint!
    
    private lazy var agoraKit: AgoraRtcEngineKit = {
      let cfg = AgoraRtcEngineConfig()
//      cfg.audioScenario = .chorus
      cfg.appId = KeyCenter.AppId
      let engine = AgoraRtcEngineKit.sharedEngine(with: cfg, delegate: nil)
        engine.setLogFilter(AgoraLogFilter.info.rawValue)
        engine.setLogFile(FileCenter.logFilePath())
        return engine
    }()
    
    private var settings = Settings()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        inputTextField.endEditing(true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueId = segue.identifier,
            segueId.count > 0 else {
            return
        }
        
        switch segueId {
        case "mainToSettings":
            let settingsVC = segue.destination as? SettingsViewController
            settingsVC?.delegate = self
            settingsVC?.dataSource = self
        case "mainToLive":
            guard let role = sender as? KTVRole else {
                return
            }
            
            let liveVC = segue.destination as? LiveRoomViewController
            liveVC?.dataSource = self
            liveVC?.role = role
        default:
            break
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputTextField.endEditing(true)
    }
    
    @IBAction func doStartButton(_ sender: UIButton) {
        guard let roomName = roomNameTextField.text,
            roomName.count > 0 else {
                return
        }
        settings.roomName = roomName
        
        let act1 = UIAlertAction(title: KTVRole.owner.description,
                                 style: .default) { [unowned self] (_) in
            self.settings.role = .broadcaster
            self.performSegue(withIdentifier: "mainToLive",
                              sender: KTVRole.owner)
        }
        
        let act2 = UIAlertAction(title: KTVRole.broadcaster.description,
                                 style: .default) { [unowned self] (_) in
            self.settings.role = .broadcaster
            self.performSegue(withIdentifier: "mainToLive",
                              sender: KTVRole.broadcaster)
        }
        
        let act3 = UIAlertAction(title: KTVRole.audience.description,
                                 style: .default) { [unowned self] (_) in
            self.settings.role = .audience
            self.performSegue(withIdentifier: "mainToLive",
                              sender: KTVRole.audience)
        }
        
        self.showAlert(nil, message: nil,
                       preferredStyle: .alert,
                       actions: [act1, act2, act3])
    }
    
    @IBAction func doExitPressed(_ sender: UIStoryboardSegue) {
    }
}

private extension MainViewController {
    func updateViews() {
        let key = NSAttributedString.Key.foregroundColor
        let color = UIColor(red: 156.0 / 255.0, green: 217.0 / 255.0, blue: 1.0, alpha: 1)
        let attributed = [key: color]
        let attributedString = NSMutableAttributedString(string: "Enter a channel name", attributes: attributed)
        inputTextField.attributedPlaceholder = attributedString
        
        startButton.layer.shadowOpacity = 0.3
        startButton.layer.shadowColor = UIColor.black.cgColor
        
        if UIScreen.main.bounds.height <= 568 {
            logoTop.constant = 69
            inputTextFieldTop.constant = 37
        }
    }
    
    func showAlert(_ title: String? = nil,
                   message: String? = nil,
                   preferredStyle: UIAlertController.Style = .alert,
                   actions: [UIAlertAction]? = nil) {
        view.endEditing(true)
        
        if let vc = self.presentedViewController,
            let alert = vc as? UIAlertController {
            alert.dismiss(animated: false, completion: nil)
        }
        
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: preferredStyle)
        
        var tActions: [UIAlertAction]
        
        if let actions = actions {
            tActions = actions
        } else {
            tActions = [UIAlertAction(title: "OK",
                                      style: .default,
                                      handler: nil)]
        }
        
        for item in tActions {
            alert.addAction(item)
        }
        
        present(alert,
                animated: true,
                completion: nil)
    }
}

extension MainViewController: LiveVCDataSource {
    func liveVCNeedSettings() -> Settings {
        return settings
    }
    
    func liveVCNeedAgoraKit() -> AgoraRtcEngineKit {
        return agoraKit
    }
}

extension MainViewController: SettingsVCDelegate {
    func settingsVC(_ vc: SettingsViewController, didSelect dimension: CGSize) {
        settings.dimension = dimension
    }
    
    func settingsVC(_ vc: SettingsViewController, didSelect frameRate: AgoraVideoFrameRate) {
        settings.frameRate = frameRate
    }
}

extension MainViewController: SettingsVCDataSource {
    func settingsVCNeedSettings() -> Settings {
        return settings
    }
}

extension MainViewController: RoleVCDelegate {
    func roleVC(_ vc: RoleViewController, didSelect role: AgoraClientRole) {
        settings.role = role
    }
}

extension MainViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        inputTextField.endEditing(true)
        return true
    }
}
