import AppKit
import Speech
import AVFoundation

/// 把语音转写文本注入 DSH 输入框的桥（接缝，可替换策略）。
///
/// 默认实现是剪贴板桥：把转写文本复制到系统剪贴板并发送 Cmd+V 粘贴到当前聚焦的
/// DSH 输入框。稳健、不依赖 DSH Web UI 的 DOM 结构（DSH 输入框 DOM 不在本仓库控制内）。
/// 若未来 DSH 提供稳定 hook，可新增 JSInjectionBridge 并共享同一接口。
protocol VoiceBridge {
    /// 把转写文本交给当前聚焦的 DSH 输入框。返回是否成功投递。
    @discardableResult
    func deliver(_ text: String) -> Bool
}

/// 剪贴板桥：写剪贴板 + 模拟 Cmd+V。默认采用，稳健失败可感知（剪贴板写入失败即返回 false）。
final class ClipboardVoiceBridge: VoiceBridge {
    private let pasteboard = NSPasteboard.general

    func deliver(_ text: String) -> Bool {
        pasteboard.clearContents()
        let ok = pasteboard.setString(text, forType: .string)
        guard ok, !text.isEmpty else { return false }
        // 触发粘贴需要目标窗口是关键窗口；若面板不抢前台但用户正聚焦 DSH 主窗口，此粘贴落在聚焦处。
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // 9 = 'v'
        let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        return true
    }
}

/// 语音输入控制器（AppKit/Speech 薄适配器，深逻辑在 VoiceInputModel）。
///
/// 职责：
///  - 请求/检查麦克风与语音识别权限；
///  - 用 SFSpeechRecognizer + AVAudioEngine 做本机离线转写（zh-CN/en-US）；
///  - 每帧/结束时通过 `onStateChange` 回调驱动 UI 状态反馈；
///  - 结束时归一化转写并经 VoiceBridge 注入 DSH 输入框。
final class VoiceController: NSObject, SFSpeechRecognizerDelegate {
    /// 状态变化回调（主线程），UI 据以更新麦克风按钮/菜单项。
    var onStateChange: ((VoiceInputModel.State) -> Void)?

    private let bridge: VoiceBridge
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?

    /// 当前语音 locale（归一化到受支持集合）。
    private(set) var locale: String = VoiceInputModel.defaultLocale

    init(bridge: VoiceBridge = ClipboardVoiceBridge()) {
        self.bridge = bridge
        super.init()
    }

    // MARK: 权限

    /// 当前语音识别权限状态（映射到 VoiceInputModel.Permission）。
    static var authorizationStatus: VoiceInputModel.Permission {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: return .undetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .restricted
        }
    }

    /// 请求语音识别权限并回调授权结果。
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                let granted = status == .authorized
                let state = VoiceInputModel.initialState(permission: VoiceInputModel.Permission(rawValue: status))
                self.onStateChange?(state)
                completion(granted)
            }
        }
    }

    /// 设置语音 locale（归一化后生效）。
    func setLocale(_ raw: String?) {
        let normalized = VoiceInputModel.normalizeLocale(raw)
        guard normalized != locale else { return }
        locale = normalized
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: normalized))
        speechRecognizer?.delegate = self
    }

    // MARK: 录音 / 转写

    var isRecording: Bool { audioEngine?.isRunning ?? false }

    /// 开始录音并转写；已授权麦克风且权限可用才执行。
    func startRecording() {
        let permission = VoiceController.authorizationStatus
        switch permission {
        case .denied:
            onStateChange?(.unavailable("麦克风权限被拒绝"))
            return
        case .restricted:
            onStateChange?(.unavailable("语音识别受限"))
            return
        case .undetermined:
            requestAuthorization { [weak self] granted in
                guard let self, granted else { return }
                self.startRecording()
            }
            return
        case .authorized:
            break
        }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            onStateChange?(.unavailable("语音识别暂不可用"))
            return
        }

        // macOS 上请求麦克风权限（若之前只请求了语音识别权限）。
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async { [weak self] in
                guard let self, granted else {
                    self?.onStateChange?(.unavailable("麦克风权限被拒绝"))
                    return
                }
                self.beginRecognition(with: recognizer)
            }
        }
    }

    /// 停止录音并完成转写（若正在进行）。
    func stopRecording() {
        guard isRecording else { return }
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        audioEngine = nil
    }

    /// 取消当前录音（不投递结果）。
    func cancelRecording() {
        stopRecording()
        recognitionTask?.cancel()
        recognitionTask = nil
        onStateChange?(.idle)
    }

    private func beginRecognition(with recognizer: SFSpeechRecognizer) {
        onStateChange?(.listening)
        do {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let audioEngine = AVAudioEngine()
            self.audioEngine = audioEngine
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                let isFinal = result?.isFinal ?? false
                if let result {
                    let partial = result.bestTranscription.formattedString
                    // 实时反馈：只要非空就让 UI 知道正在产出内容（仍处于 listening）。
                    if !partial.isEmpty, !isFinal {
                        self.onStateChange?(.listening)
                    }
                }
                if error != nil || isFinal {
                    self.stopRecording()
                    self.recognitionTask = nil
                    let text = result?.bestTranscription.formattedString
                    self.finish(with: text)
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            stopRecording()
            recognitionTask?.cancel()
            recognitionTask = nil
            onStateChange?(.unavailable("无法开始语音识别"))
        }
    }

    /// 转写结束：归一化文本，非空则经桥注入 DSH 输入框，然后回到 idle。
    private func finish(with raw: String?) {
        let text = VoiceInputModel.normalizedTranscript(raw)
        if let text {
            onStateChange?(.processing)
            // 投递成功才回 idle；失败保持提示（避免用户以为已输入）。
            if bridge.deliver(text) {
                onStateChange?(.idle)
            } else {
                onStateChange?(.unavailable("语音文本投递失败"))
            }
        } else {
            onStateChange?(.idle)
        }
    }

    // MARK: SFSpeechRecognizerDelegate

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if !available {
                self.onStateChange?(.unavailable("语音识别暂不可用"))
            } else {
                self.onStateChange?(.idle)
            }
        }
    }
}

// MARK: - Permission 映射辅助

extension VoiceInputModel.Permission {
    init(rawValue status: SFSpeechRecognizerAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .undetermined
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default: self = .restricted
        }
    }
}