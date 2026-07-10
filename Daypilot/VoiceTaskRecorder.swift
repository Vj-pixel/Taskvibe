import AVFoundation
import Speech
import SwiftUI

class VoiceTaskRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var transcript  = ""
    @Published var denied      = false

    private let audioEngine  = AVAudioEngine()
    private var request:  SFSpeechAudioBufferRecognitionRequest?
    private var task:     SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)

    func toggle(onUpdate: @escaping (String) -> Void) {
        isRecording ? stop() : start(onUpdate: onUpdate)
    }

    func start(onUpdate: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self else { return }
            guard status == .authorized else {
                DispatchQueue.main.async { self.denied = true }
                return
            }
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else {
                    DispatchQueue.main.async { self.denied = true }
                    return
                }
                DispatchQueue.main.async { self.beginSession(onUpdate: onUpdate) }
            }
        }
    }

    private func beginSession(onUpdate: @escaping (String) -> Void) {
        stopEngine()

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        self.request = req

        let node = audioEngine.inputNode
        let fmt  = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak req] buf, _ in
            req?.append(buf)
        }

        do {
            try audioEngine.start()
        } catch {
            return
        }

        isRecording = true
        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcript = text
                    onUpdate(text)
                }
            }
            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async { self.stop() }
            }
        }
    }

    func stop() {
        stopEngine()
        isRecording = false
    }

    private func stopEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
    }
}
