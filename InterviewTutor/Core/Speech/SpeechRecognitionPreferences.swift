import Speech

enum SpeechRecognitionPreferences {
    static func applyOnDevicePreference(to request: SFSpeechAudioBufferRecognitionRequest, locale: Locale) {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else { return }
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
    }

    static func applyOnDevicePreference(to request: SFSpeechURLRecognitionRequest, locale: Locale) {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else { return }
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
    }
}
