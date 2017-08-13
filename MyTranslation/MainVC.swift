//
//  MainVC.swift
//  MyTranslation
//
//  Created by 佐藤賢 on 2017/08/12.
//  Copyright © 2017年 佐藤賢. All rights reserved.
//

import UIKit
import Speech
import AVFoundation

class MainVC: UIViewController, SFSpeechRecognizerDelegate {

  
  @IBOutlet weak var inputTextView: UITextView!
  @IBOutlet weak var outputTextView: UITextView!
  @IBOutlet weak var button: UIButton!
  @IBOutlet weak var ActivityIndicatorView: UIActivityIndicatorView!
  
  // ロケールを指定してSFSpeechRecognizerを生成
  fileprivate let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
  // マイク等のオーディオバッファを利用
  fileprivate var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  fileprivate var recognitionTask: SFSpeechRecognitionTask?
  fileprivate let audioEngine = AVAudioEngine()   // マイクの利用生成
  fileprivate var translator = Translator()
  fileprivate var talker = AVSpeechSynthesizer()
  
  enum Mode {
    case none
    case recording
    case translation
  }
  fileprivate var mode = Mode.none
  
  override func viewDidLoad() {
    super.viewDidLoad()
    speechRecognizer.delegate = self
    
    // キーボードを下げる処理（キーボード以外をタップ）
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action:#selector(dismissKeyboard(_:)))
    tapGestureRecognizer.delegate = self
    self.view.addGestureRecognizer(tapGestureRecognizer)
    
    SFSpeechRecognizer.requestAuthorization { authStatus in
      switch authStatus {
      case .authorized: // 許可された
        self.button.isEnabled = true
      case .denied: // 音声認識へのアクセスが拒否された
        self.button.isEnabled = false
      case .restricted: // この端末で音声認識が出来ない
        self.button.isEnabled = false
      case .notDetermined: // 音声認識が許可されていない
        self.button.isEnabled = false
      }
    }
    setMode(.none)
  }
  
  // MARK: - Action
  @IBAction func tapButton(_ sender: AnyObject) {
    switch mode {
    case .none:
      do {
        try self.startRecording()
        setMode(.recording)
      } catch {
        
      }
      break
    case .recording:
      stopRecording()
      startTranslation()
      setMode(.translation)
      break
    case .translation:
      break
    }
  }
  
  // MARK: - Private
  fileprivate func startRecording() throws {
    
    if let recognitionTask = recognitionTask {
      recognitionTask.cancel()
      self.recognitionTask = nil
    }
    
    // 認識開始前に初期化
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let recognitionRequest = recognitionRequest else {
      fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object")
    }
    
    // 入力をSFSpeechRecognizerに送る
    guard let inputNode = audioEngine.inputNode else {
      fatalError("Audio engine has no input node")
    }
    
    /*
     recognitionTaskでリクエストを開始してクロージャーで入力を取得します。
     入力に変化があるたびに開始後の全部の文字列が返される
     */
    
    // 録音が終わる前の "partial (non-final)" な結果を報告する
    recognitionRequest.shouldReportPartialResults = true
    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
      var isFinal = false
      if let result = result {
        if (self.mode == .recording) {
          // 入力フォームに音声認識の結果を反映
          self.inputTextView.text = result.bestTranscription.formattedString
        }
        isFinal = result.isFinal
      }
      if error != nil || isFinal {
        self.audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        
        self.recognitionRequest = nil
        self.recognitionTask = nil
      }
    }
    
    // 入力をSFSpeechRecognizerに送る
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    // マイクから得られる音声バッファがSFSpeechRecognitionRequestオブジェクトに渡され、録音開始とともに認識が開始される
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
      self.recognitionRequest?.append(buffer)
    }
    
    // マイクの利用開始
    audioEngine.prepare()
    try audioEngine.start()
  }
  
  fileprivate func stopRecording() {
    // マイクの利用停止
    audioEngine.stop()
    recognitionRequest?.endAudio()
  }
  
  fileprivate func startTranslation() {
    translator.conversion(inputTextView.text, complate: { result in
      self.outputTextView.text = result
      // 話す内容をセット
      let utterance = AVSpeechUtterance(string: result)
      // 言語を米国に設定
      utterance.voice = AVSpeechSynthesisVoice(language: "en")
      // 実行
      self.talker.speak(utterance)
      self.setMode(.none)
    })
  }
  
  //画面に表示されるUI（ボタンとロード時の表示）
  func setMode(_ mode:Mode){
    self.mode = mode
    switch mode {
    case .none:
      button.setTitle("開始", for: .normal)
      ActivityIndicatorView.isHidden = true
      ActivityIndicatorView.stopAnimating()
    case .recording:
      button.setTitle("翻訳", for: .normal)
      inputTextView.text = ""
      outputTextView.text = ""
      ActivityIndicatorView.isHidden = true
    case .translation:
      button.setTitle("", for: .normal)
      ActivityIndicatorView.isHidden = false
      ActivityIndicatorView.startAnimating()
    }
  }
  
  // MARK: - SFSpeechRecognizerDelegate
  func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
    if available {
      button.isEnabled = true // 利用可能
    } else {
      button.isEnabled = false // 利用不能
    }
  }
}

// 拡張：キーボードを下げる処理（キーボード以外をタップ）
extension MainVC: UIGestureRecognizerDelegate {
  func dismissKeyboard(_ gesture: UIGestureRecognizerDelegate) {
    self.view.endEditing(true)
  }
}

// 拡張：layer
extension UIView {
  
  @IBInspectable var cornerRadius: CGFloat {
    get {
      return layer.cornerRadius
    }
    set {
      layer.cornerRadius = newValue
      layer.masksToBounds = newValue > 0
    }
  }
  
  @IBInspectable
  var borderWidth: CGFloat {
    get {
      return self.layer.borderWidth
    }
    set {
      self.layer.borderWidth = newValue
    }
  }
  
  @IBInspectable
  var borderColor: UIColor? {
    get {
      return UIColor(cgColor: self.layer.borderColor!)
    }
    set {
      self.layer.borderColor = newValue?.cgColor
    }
  }
  
}
