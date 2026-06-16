import Foundation
import SwiftData

@Model
final class QuestionRecord {
    var questionID: UUID
    var orderIndex: Int
    var categoryRawValue: String
    var questionText: String
    var promptKeywords: String
    var startTimestamp: TimeInterval
    var endTimestamp: TimeInterval
    var transcribedAnswer: String
    var fillerWordCount: Int
    var aiFeedback: String
    var recommendedSeconds: Int
    var speechScore: Int?
    var contentScore: Int?
    var postureScore: Int?
    var gazeTowardCameraRatio: Double?
    var faceDetectedRatio: Double?
    var postureStabilityScore: Double?

    var session: InterviewSession?

    var category: QuestionCategory {
        get { QuestionCategory(rawValue: categoryRawValue) ?? .documentBased }
        set { categoryRawValue = newValue.rawValue }
    }

    init(
        questionID: UUID = UUID(),
        orderIndex: Int,
        category: QuestionCategory,
        questionText: String,
        promptKeywords: String = "",
        startTimestamp: TimeInterval = 0,
        endTimestamp: TimeInterval = 0,
        transcribedAnswer: String = "",
        fillerWordCount: Int = 0,
        aiFeedback: String = "",
        recommendedSeconds: Int = 45,
        speechScore: Int? = nil,
        contentScore: Int? = nil,
        postureScore: Int? = nil,
        gazeTowardCameraRatio: Double? = nil,
        faceDetectedRatio: Double? = nil,
        postureStabilityScore: Double? = nil,
        session: InterviewSession? = nil
    ) {
        self.questionID = questionID
        self.orderIndex = orderIndex
        self.categoryRawValue = category.rawValue
        self.questionText = questionText
        self.promptKeywords = promptKeywords
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.transcribedAnswer = transcribedAnswer
        self.fillerWordCount = fillerWordCount
        self.aiFeedback = aiFeedback
        self.recommendedSeconds = recommendedSeconds
        self.speechScore = speechScore
        self.contentScore = contentScore
        self.postureScore = postureScore
        self.gazeTowardCameraRatio = gazeTowardCameraRatio
        self.faceDetectedRatio = faceDetectedRatio
        self.postureStabilityScore = postureStabilityScore
        self.session = session
    }

    var keywordList: [String] {
        promptKeywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
