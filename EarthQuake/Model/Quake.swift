//
//  Quake.swift
//  EarthQuakeSwiftData
//
//  Created by Jens Troest on 11/4/24.
//
// The app internal data model

import Foundation
import SwiftData

@Model
final class Quake {
    init(magnitude: Float, place: String, timestamp: Date, code: String) {
        self.magnitude = magnitude
        self.place = place
        self.timestamp = timestamp
        self.code = code
    }

    var magnitude: Float
    var place: String
    var timestamp: Date
    @Attribute(.unique) var code: String
}
