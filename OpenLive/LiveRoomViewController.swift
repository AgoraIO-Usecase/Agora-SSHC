//
//  LiveRoomViewController.swift
//  OpenLive
//
//  Created by GongYuhua on 6/25/16.
//  Copyright © 2016 Agora. All rights reserved.
//

import UIKit
import AgoraRtcKit2
import AgoraMediaPlayer

protocol LiveVCDataSource: NSObjectProtocol {
    func liveVCNeedAgoraKit() -> AgoraRtcEngineKit
    func liveVCNeedSettings() -> Settings
}
class EngineDelegate: NSObject {
    
}

protocol AgoraPcmSourcePushDelegate {
    func onAudioFrame(data: CMSampleBuffer) -> Void
}

class AgoraPcmSourcePush: NSObject {
    fileprivate var delegate: AgoraPcmSourcePushDelegate?
    private var filePath: String
    private var playerKit: AgoraMediaPlayer?
    
    
    private var state: State = .Stop

    enum State {
        case Play
        case Stop
    }
    
    init(delegate: AgoraPcmSourcePushDelegate?, filePath: String) {
        self.delegate = delegate
        self.filePath = filePath
    }
  
  func changeFile(filePath: String) {
    self.filePath = filePath
    self.playerKit?.destroy()
    self.playerKit = AgoraMediaPlayer.init(delegate: self)
    playerKit?.open(filePath, startPos: 0)
    self.state = .Stop
  }
    
    func start() {
        if state == .Stop {
          state = .Play
          self.playerKit?.adjustVolume(0)
          playerKit?.play()
        }
    }
    
    func stop() {
        if state == .Play {
          state = .Stop
          playerKit?.stop()
          changeFile(filePath: filePath)
        }
    }
  func destory() {
    self.playerKit?.destroy()
  }
  
  func setVol(vol: Int32) {
//    self.playerKit?.adjustVolume(vol)
  }

}

extension AgoraPcmSourcePush: AgoraMediaPlayerDelegate {
  
  func agoraMediaPlayer(_ playerKit: AgoraMediaPlayer, didChangedTo state: AgoraMediaPlayerState, error: AgoraMediaPlayerError) {
    print(state)
  }
  func agoraMediaPlayer(_ playerKit: AgoraMediaPlayer, didOccur event: AgoraMediaPlayerEvent) {
    print(event)
  }
  func agoraMediaPlayer(_ playerKit: AgoraMediaPlayer, metaDataType type: AgoraMediaPlayerMetaDataType, didReceiveData data: String, length: Int) {
    print(data)
  }
  
  func agoraMediaPlayer(_ playerKit: AgoraMediaPlayer, didReceiveAudioFrame audioFrame: CMSampleBuffer) {
    
//    var aaa = CMSampleBufferGetNumSamples(audioFrame)
      self.delegate?.onAudioFrame(data: audioFrame)
    
  }
}

class LiveRoomViewController: UIViewController {
    
    @IBOutlet weak var broadcastersView: AGEVideoContainer!
    @IBOutlet weak var placeholderView: UIImageView!
    
    @IBOutlet weak var videoMuteButton: UIButton!
    @IBOutlet weak var audioMuteButton: UIButton!
    @IBOutlet weak var beautyEffectButton: UIButton!
    @IBOutlet weak var pickView: UIPickerView!
  @IBOutlet weak var pickButton: UIButton!
  @IBOutlet weak var startButton: UIButton!
  @IBOutlet weak var statusLabel: UILabel!
  @IBOutlet weak var ownerSlider: UISlider!
  @IBOutlet weak var bgmSlider: UISlider!
  @IBOutlet weak var partnerSlider: UISlider!
  @IBOutlet weak var ownerLabel: UILabel!
  @IBOutlet weak var partnerLabel: UILabel!
  @IBOutlet weak var bgmLabel: UILabel!
    
    @IBOutlet var sessionButtons: [UIButton]!
  var pickData: [String] = ["大海","稻香","知足"]
  var fileName: String = "大海"
  private var started: Bool = false;
    private var agoraKit: AgoraRtcEngineKit {
        return dataSource!.liveVCNeedAgoraKit()
    }
    
    private var settings: Settings {
        return dataSource!.liveVCNeedSettings()
    }
    
    private var isMutedVideo = false {
        didSet {
            // mute local video
            agoraKit.muteLocalVideoStream(isMutedVideo)
            videoMuteButton.isSelected = isMutedVideo
        }
    }
    
    private var isMutedAudio = false {
        didSet {
            // mute local audio
            agoraKit.muteLocalAudioStream(isMutedAudio)
            audioMuteButton.isSelected = isMutedAudio
        }
    }
    
    private var isBeautyOn = false {
        didSet {
            // improve local render view
            beautyEffectButton.isSelected = isBeautyOn
        }
    }
    
    private var isSwitchCamera = false {
        didSet {
            agoraKit.switchCamera()
        }
    }
    
    private var videoSessions = [VideoSession]() {
        didSet {
            placeholderView.isHidden = (videoSessions.count == 0 ? false : true)
            // update render view layout
            updateBroadcastersView()
        }
    }
    
    private let maxVideoSession = 4
    var connectionId:UInt32?
    var streamId:Int?
    weak var dataSource: LiveVCDataSource?
    var pcmSourcePush: AgoraPcmSourcePush?
    var rtt:Int64 = 0
    var role: KTVRole = .audience
  var vol:Int = 100
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateButtonsVisiablity()
      self.pickView.dataSource = self
      self.pickView.delegate = self
      self.pickView.isHidden = true
      self.ownerSlider.value = 100
      self.partnerSlider.value = 100
      self.bgmSlider.value = 100
        loadAgoraKit()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    //MARK: - ui action
    @IBAction func doSwitchCameraPressed(_ sender: UIButton) {
        isSwitchCamera.toggle()
    }
    
    @IBAction func doBeautyPressed(_ sender: UIButton) {
//        isBeautyOn.toggle()
      sync()
    }
    
    @IBAction func doMuteVideoPressed(_ sender: UIButton) {
        isMutedVideo.toggle()
    }
    
    @IBAction func doMuteAudioPressed(_ sender: UIButton) {
        isMutedAudio.toggle()
    }
    
    @IBAction func doLeavePressed(_ sender: UIButton) {
        leaveChannel()
    }
  @IBAction func doChangeBGM(_ sender: UIButton) {
    self.pickView.isHidden = false
  }
  @IBAction func doStartPlay(_ sender: UIButton) {
    if role == .owner {
        if !started {
            started = true;
          startButton.setTitle("停止播放", for: UIControl.State.normal)
            let str = "start"
            guard let data = str.data(using: String.Encoding.utf8) else { return }
            agoraKit.sendStreamMessage(streamId ?? 0, data: data)
            usleep(useconds_t(rtt*1000/2))
            pcmSourcePush?.start()
        } else {
            started = false;
            let str = "stop"
          startButton.setTitle("开始播放", for: UIControl.State.normal)
            guard let data = str.data(using: String.Encoding.utf8) else { return }
            agoraKit.sendStreamMessage(streamId ?? 0, data: data)
            pcmSourcePush?.stop()
        }
    }
  }
  @IBAction func ownerSliderChanged(_ sender: UISlider) {
    if role == .owner {
      self.agoraKit.adjustRecordingSignalVolume(Int(ownerSlider.value))
    }else {
      self.agoraKit.adjustUserPlaybackSignalVolume(2, volume: Int32(ownerSlider.value))
    }
  }
  @IBAction func partnerSliderChanged(_ sender: UISlider) {
    if role == .broadcaster {
      self.agoraKit.adjustRecordingSignalVolume(Int(partnerSlider.value))
    } else {
      self.agoraKit.adjustUserPlaybackSignalVolume(3, volume: Int32(partnerSlider.value))
    }
  }
  @IBAction func bgmSliderChanged(_ sender: UISlider) {
    if role == .audience {
      self.agoraKit.adjustUserPlaybackSignalVolume(1, volume: Int32(bgmSlider.value))
    } else {
//      self.pcmSourcePush?.setVol(vol: Int32(bgmSlider.value))
      self.vol = Int(bgmSlider.value)
    }
  }
}

private extension LiveRoomViewController {
    func updateBroadcastersView() {
        // video views layout
        if videoSessions.count == maxVideoSession {
            broadcastersView.reload(level: 0, animated: true)
        } else {
            var rank: Int
            var row: Int
            
            if videoSessions.count == 0 {
                broadcastersView.removeLayout(level: 0)
                return
            } else if videoSessions.count == 1 {
                rank = 1
                row = 1
            } else if videoSessions.count == 2 {
                rank = 1
                row = 2
            } else {
                rank = 2
                row = Int(ceil(Double(videoSessions.count) / Double(rank)))
            }
            
            let itemWidth = CGFloat(1.0) / CGFloat(rank)
            let itemHeight = CGFloat(1.0) / CGFloat(row)
            let itemSize = CGSize(width: itemWidth, height: itemHeight)
            let layout = AGEVideoLayout(level: 0)
                        .itemSize(.scale(itemSize))
            
            broadcastersView
                .listCount { [unowned self] (_) -> Int in
                    return self.videoSessions.count
                }.listItem { [unowned self] (index) -> UIView in
                    return self.videoSessions[index.item].hostingView
                }
            
            broadcastersView.setLayouts([layout], animated: true)
        }
    }
    
  func sync() {
    print("datastream send: 190124102399")
    if role == .owner {
      statusLabel.text = "发起同步"
      let ms = CLongLong(round(Date().timeIntervalSince1970*1000))
      let str = "rtt,"+fileName+",\(ms)"
      guard let data = str.data(using: String.Encoding.utf8) else { return }
      agoraKit.sendStreamMessage(streamId ?? 0, data: data)
      guard let filepath = Bundle.main.path(forResource: fileName+".mp3", ofType: nil) else {
          return
      }
      pcmSourcePush?.changeFile(filePath: filepath)
      self.isSwitchCamera = false
    }
  }
  func changeFile(filePath: String) {
    if role == .owner {
      let str = "stop"
      guard let data = str.data(using: String.Encoding.utf8) else { return }
      agoraKit.sendStreamMessage(streamId ?? 0, data: data)
    }
    pcmSourcePush?.changeFile(filePath: filePath)
    self.isSwitchCamera = false
  }
    func updateButtonsVisiablity() {
        guard let sessionButtons = sessionButtons else {
            return
        }
        
        let isHidden = settings.role == .audience
        
        for item in sessionButtons {
            item.isHidden = isHidden
        }
    }
    
    func setIdleTimerActive(_ active: Bool) {
        UIApplication.shared.isIdleTimerDisabled = !active
    }
}

private extension LiveRoomViewController {
    func getSession(of uid: UInt) -> VideoSession? {
        for session in videoSessions {
            if session.uid == uid {
                return session
            }
        }
        return nil
    }
    
    func videoSession(of uid: UInt) -> VideoSession {
        if let fetchedSession = getSession(of: uid) {
            return fetchedSession
        } else {
            let newSession = VideoSession(uid: uid)
            videoSessions.append(newSession)
            return newSession
        }
    }
}

//MARK: - Agora Media SDK
private extension LiveRoomViewController {
    func loadAgoraKit() {
        guard let channelId = settings.roomName else {
            return
        }
        
        setIdleTimerActive(false)
        
        // Step 1, set delegate to inform the app on AgoraRtcEngineKit events
        agoraKit.delegate = self
        // Step 2, set live broadcasting mode
        // for details: https://docs.agora.io/cn/Video/API%20Reference/oc/Classes/AgoraRtcEngineKit.html#//api/name/setChannelProfile:
        agoraKit.setChannelProfile(.liveBroadcasting)
        // set client role
        agoraKit.setClientRole(settings.role)
        
        // Step 3, Warning: only enable dual stream mode if there will be more than one broadcaster in the channel
        agoraKit.enableDualStreamMode(false)
        
        // Step 4, enable the video module
//        agoraKit.enableVideo()
      agoraKit.enable(inEarMonitoring: true)
        
        let mediaOptions = AgoraRtcChannelMediaOptions()
      mediaOptions.autoSubscribeAudio = AgoraRtcBoolOptional.of(false)
        mediaOptions.autoSubscribeVideo = AgoraRtcBoolOptional.of(false)
        mediaOptions.publishAudioTrack = AgoraRtcBoolOptional.of(true)
        mediaOptions.publishCameraTrack = AgoraRtcBoolOptional.of(false)
      mediaOptions.publishCustomAudioTrack = AgoraRtcBoolOptional.of((false))
      mediaOptions.channelProfile = AgoraRtcIntOptional.of(Int32(AgoraChannelProfile.liveBroadcasting.rawValue))
      mediaOptions.clientRoleType =  AgoraRtcIntOptional.of((role == .audience) ? 2 : 1)
        
        agoraKit.setAudioProfile(AgoraAudioProfile(rawValue: 8) ?? AgoraAudioProfile.default)
        
        agoraKit.setExternalAudioSource(true, sampleRate: 44100, channels: 2, sourceNumber: 1, localPlayback: true, publish: true)
        
        // Step 5, join channel and start group chat
        // If join  channel success, agoraKit triggers it's delegate function
//        agoraKit.joinChannel(byToken: KeyCenter.Token, channelId: channelId, info: nil, uid: 1, joinSuccess: nil)
      var tuid:UInt = 0
      if role == .owner {
        tuid = 2
      }else if role == .broadcaster {
        tuid = 3
      }
        agoraKit.joinChannel(byToken: KeyCenter.Token, channelId: channelId, uid: tuid, mediaOptions: mediaOptions, joinSuccess: nil)
        if role != .audience {
            let connectionIdPointer2 = UnsafeMutablePointer<UInt32>.allocate(capacity: MemoryLayout<UInt32>.stride)
          mediaOptions.publishAudioTrack = AgoraRtcBoolOptional.of(false)
          mediaOptions.publishCustomAudioTrack = AgoraRtcBoolOptional.of((role == .owner))
            mediaOptions.enableAudioRecordingOrPlayout = AgoraRtcBoolOptional.of(false)
          mediaOptions.publishMediaPlayerAudioTrack = AgoraRtcBoolOptional.of(false)
            mediaOptions.clientRoleType = AgoraRtcIntOptional.of(1)
            let uid2:UInt = role == .owner ? 1 : 4
            agoraKit.joinChannelEx(byToken: KeyCenter.Token, channelId: channelId, uid: uid2, connectionId: connectionIdPointer2, delegate: nil, mediaOptions: mediaOptions, joinSuccess: nil)
            connectionId = connectionIdPointer2.pointee
            connectionIdPointer2.deallocate()
            guard let filepath = Bundle.main.path(forResource: "大海.mp3", ofType: nil) else {
                return
            }
            pcmSourcePush = AgoraPcmSourcePush(delegate: self, filePath: filepath)
          changeFile(filePath: filepath)
        }
        if role != .audience {
            let streamIdP = UnsafeMutablePointer<Int>.allocate(capacity: MemoryLayout<Int>.stride)
            agoraKit.createDataStream(streamIdP, reliable: false, ordered: false)
            streamId = streamIdP.pointee
            streamIdP.deallocate()
        }
        
    }
    
    func addLocalSession() {
        let localSession = VideoSession.localSession()
        localSession.updateInfo(fps: settings.frameRate.rawValue)
        videoSessions.append(localSession)
        agoraKit.setupLocalVideo(localSession.canvas)
    }
    
    func leaveChannel() {
        self.pcmSourcePush?.destory()
        // Step 1, release local AgoraRtcVideoCanvas instance
        agoraKit.setupLocalVideo(nil)
        // Step 2, leave channel and end group chat
        agoraKit.leaveChannel(nil)
        
        // Step 3, if current role is broadcaster,  stop preview after leave channel
        if settings.role == .broadcaster {
            agoraKit.stopPreview()
        }
        
        setIdleTimerActive(true)
        
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - AgoraPcmSourcePushDelegate
extension LiveRoomViewController: AgoraPcmSourcePushDelegate {
    func onAudioFrame(data: CMSampleBuffer) {
//      agoraKit.pushExternalAudioFrameExSampleBuffer(data, connectionId: connectionId ?? 1)
      
      guard let buffer = CMSampleBufferGetDataBuffer(data) else { return }
      let size = CMBlockBufferGetDataLength(buffer)
      let sampleBytes = UnsafeMutablePointer<Int16>.allocate(capacity: size/2)
      CMBlockBufferCopyDataBytes(buffer, atOffset: 0, dataLength: size, destination: sampleBytes)
      var i = 0
      while i < size / 2 {
        var tmp:Float = Float(sampleBytes[i])
        tmp = tmp / 100 * Float(vol)
        sampleBytes[i] = Int16(tmp)
        i+=1
      }
      let datas = Data(bytes: sampleBytes, count: size)
      agoraKit.pushExternalAudioFrameExNSData(datas, sourceId: 0, timestamp: 0, connectionId: connectionId ?? 1)
//      agoraKit.pushExternalAudioFrameSampleBuffer(data)
//      agoraKit.pushExternalAudioFrameExNSData(data.dataBuffer, sourceId: 0, timestamp: 0, connectionId: connectionId ?? 1)
    }
    
}
// MARK: - UIPickerViewDataSource
extension LiveRoomViewController: UIPickerViewDataSource {
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 1
  }
  
  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    return 3
  }
}

//MARK: - UIPickerViewDelegate
extension LiveRoomViewController: UIPickerViewDelegate {
  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    return self.pickData[row]
  }
  func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    self.pickButton.setTitle(self.pickData[row], for: UIControl.State.normal)
    self.fileName = self.pickData[row]
    self.pickView.isHidden = true
    sync()
  }
}
// MARK: - AgoraRtcEngineDelegate
extension LiveRoomViewController: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
//        if role != .audience {
//            pcmSourcePush?.start()
//        }
    }
    func rtcEngine(_ engine: AgoraRtcEngineKit, receiveStreamMessageFromUid uid: UInt, streamId: Int, data: Data) {
        if role == .broadcaster {
            let str =  NSString(data:data ,encoding: String.Encoding.utf8.rawValue)
            guard let recv = str?.contains("rtt,") else { return  }
            guard let start = str?.contains("start") else { return  }
            if recv {
                let time = str?.substring(from: 7)
                guard let data2 = time?.data(using: String.Encoding.utf8) else { return  }
                agoraKit.sendStreamMessage(self.streamId ?? 1, data: data2)
              self.statusLabel.text = "收到同步"
              self.fileName = str?.substring(with: NSRange(location: 4, length: 2)) ?? "大海"
              self.pickButton.setTitle(self.fileName, for: UIControl.State.normal)
              guard let filepath = Bundle.main.path(forResource: fileName + ".mp3", ofType: nil) else {
                  return
              }
              changeFile(filePath: filepath)
              self.statusLabel.text = "文件打开"
            } else if start {
                pcmSourcePush?.start()
            } else {
                pcmSourcePush?.stop()
            }
        }
        if role == .owner {
            let str =  String(data:data ,encoding: String.Encoding.utf8)
            guard let recv = str?.contains("start") else { return  }
            guard let rtt = str?.contains("rtt,") else { return  }
            if !recv && !rtt {
                let ms = CLongLong(round(Date().timeIntervalSince1970*1000))
                guard let start = Int64(str ?? "0") else { return  }
                self.rtt = ms-start
              self.statusLabel.text = "延时\(self.rtt)"
            }
        }
    }
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
      if (uid == 1 && role != .audience) || (uid == 4)  {
            
        }else{
            agoraKit.muteRemoteAudioStream(uid, mute: false)
        }
    }
    
    
    /// Occurs when the first local video frame is displayed/rendered on the local video view.
    ///
    /// Same as [firstLocalVideoFrameBlock]([AgoraRtcEngineKit firstLocalVideoFrameBlock:]).
    /// @param engine  AgoraRtcEngineKit object.
    /// @param size    Size of the first local video frame (width and height).
    /// @param elapsed Time elapsed (ms) from the local user calling the [joinChannelByToken]([AgoraRtcEngineKit joinChannelByToken:channelId:info:uid:joinSuccess:]) method until the SDK calls this callback.
    ///
    /// If the [startPreview]([AgoraRtcEngineKit startPreview]) method is called before the [joinChannelByToken]([AgoraRtcEngineKit joinChannelByToken:channelId:info:uid:joinSuccess:]) method, then `elapsed` is the time elapsed from calling the [startPreview]([AgoraRtcEngineKit startPreview]) method until the SDK triggers this callback.
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstLocalVideoFrameWith size: CGSize, elapsed: Int) {
        if let selfSession = videoSessions.first {
            selfSession.updateInfo(resolution: size)
        }
    }
    
    /// Reports the statistics of the current call. The SDK triggers this callback once every two seconds after the user joins the channel.
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportRtcStats stats: AgoraChannelStats) {
        if let selfSession = videoSessions.first {
            selfSession.updateChannelStats(stats)
        }
    }
//  func rtcEngine(_ engine: AgoraRtcEngineKit, audioTransportStatsOfUid uid: UInt, delay: UInt, lost: UInt, rxKBitRate: UInt) {
//    print("uid: \(uid), netdelay: \(delay), lost: \(lost), bitRate: \(rxKBitRate)")
//  }
//  func rtcEngine(_ engine: AgoraRtcEngineKit, audioQualityOfUid uid: UInt, quality: AgoraNetworkQuality, delay: UInt, lost: UInt) {
//    print("uid: \(uid), audiodelay: \(delay), quality: \(quality), lost: \(lost)")
//    if uid == 1 {
//      bgmLabel.text = "bgm状态：audiodelay: \(delay), quality: \(quality), lost: \(lost)"
//    }else if uid == 2 {
//      ownerLabel.text = "主播状态：audiodelay: \(delay), quality: \(quality), lost: \(lost)"
//    }else {
//      partnerLabel.text = "合唱状态：audiodelay: \(delay), quality: \(quality), lost: \(lost)"
//    }
//  }
    
    
    /// Occurs when the first remote video frame is received and decoded.
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit object.
    ///   - uid: User ID of the remote user sending the video stream.
    ///   - size: Size of the video frame (width and height).
    ///   - elapsed: Time elapsed (ms) from the local user calling the joinChannelByToken method until the SDK triggers this callback.
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid: UInt, size: CGSize, elapsed: Int) {
        guard videoSessions.count <= maxVideoSession else {
            return
        }
        
        let userSession = videoSession(of: uid)
        userSession.updateInfo(resolution: size)
        agoraKit.setupRemoteVideo(userSession.canvas)
    }
    
    /// Occurs when a remote user (Communication)/host (Live Broadcast) leaves a channel. Same as [userOfflineBlock]([AgoraRtcEngineKit userOfflineBlock:]).
    ///
    /// There are two reasons for users to be offline:
    ///
    /// - Leave a channel: When the user/host leaves a channel, the user/host sends a goodbye message. When the message is received, the SDK assumes that the user/host leaves a channel.
    /// - Drop offline: When no data packet of the user or host is received for a certain period of time (20 seconds for the Communication profile, and more for the Live-broadcast profile), the SDK assumes that the user/host drops offline. Unreliable network connections may lead to false detections, so Agora recommends using a signaling system for more reliable offline detection.
    ///
    ///  @param engine AgoraRtcEngineKit object.
    ///  @param uid    ID of the user or host who leaves a channel or goes offline.
    ///  @param reason Reason why the user goes offline, see AgoraUserOfflineReason.
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        var indexToDelete: Int?
        for (index, session) in videoSessions.enumerated() where session.uid == uid {
            indexToDelete = index
            break
        }
        
        if let indexToDelete = indexToDelete {
            let deletedSession = videoSessions.remove(at: indexToDelete)
            deletedSession.hostingView.removeFromSuperview()
            
            // release canvas's view
            deletedSession.canvas.view = nil
        }
    }
    
    /// Reports the statistics of the video stream from each remote user/host.
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteVideoStats stats: AgoraRtcRemoteVideoStats) {
        if let session = getSession(of: stats.uid) {
            session.updateVideoStats(stats)
        }
    }
    
    /// Reports the statistics of the audio stream from each remote user/host.
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteAudioStats stats: AgoraRtcRemoteAudioStats) {
//        if let session = getSession(of: stats.uid) {
//            session.updateAudioStats(stats)
//        }
      print("uid\(stats.uid), jitterBufferDelay\(stats.jitterBufferDelay), networkTransportDelay\(stats.networkTransportDelay), receivedBitrate\(stats.receivedBitrate), quality\(stats.quality),  audioLossRate\(stats.audioLossRate)")
      if stats.uid == 1 {
        bgmLabel.text = "bgm状态：jbd\(stats.jitterBufferDelay), net\(stats.networkTransportDelay), rb\(stats.receivedBitrate), q\(stats.quality),  lr\(stats.audioLossRate)"
          }else if stats.uid == 2 {
            ownerLabel.text = "主播状态：jbd\(stats.jitterBufferDelay), net\(stats.networkTransportDelay), rb\(stats.receivedBitrate), q\(stats.quality),  lr\(stats.audioLossRate)"
          }else {
            partnerLabel.text = "合唱状态：jbd\(stats.jitterBufferDelay), net\(stats.networkTransportDelay), rb\(stats.receivedBitrate), q\(stats.quality),  lr\(stats.audioLossRate)"
          }
    }
    
    /// Reports a warning during SDK runtime.
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        print("warning code: \(warningCode.description)")
    }
    
    /// Reports an error during SDK runtime.
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("warning code: \(errorCode.description)")
    }
}
