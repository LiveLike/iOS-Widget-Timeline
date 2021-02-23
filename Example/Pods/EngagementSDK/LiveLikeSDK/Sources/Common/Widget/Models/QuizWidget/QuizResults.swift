//
//  QuizResults.swift
//  LiveLikeSDK
//
//  Created by jelzon on 3/21/19.
//

import Foundation

struct QuizResults: Decodable {
    let id: String
    var choices: [QuizResult]
}

struct QuizResult: Decodable {
    let id: String
    let isCorrect: Bool
    var answerCount: Int

    init(id: String, isCorrect: Bool, answerCount: Int) {
        self.id = id
        self.isCorrect = isCorrect
        self.answerCount = answerCount
    }
}
