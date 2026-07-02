// PomodoroActivityAttributes.swift
// IMPORTANT: In Xcode, add this file to BOTH the Daypilot target AND the DaypilotWidget target
// by checking the appropriate boxes in File Inspector → Target Membership.

import ActivityKit
import Foundation

public struct PomodoroActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var secondsLeft: Int
        var totalSeconds: Int
        var sessionLabel: String
        var isRunning: Bool
    }
    public var taskTitle: String
}
