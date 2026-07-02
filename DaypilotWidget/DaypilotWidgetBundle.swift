// DaypilotWidgetBundle.swift

import WidgetKit
import SwiftUI

@main
struct DaypilotWidgetBundle: WidgetBundle {
    var body: some Widget {
        DaypilotSmallWidget()
        DaypilotMediumWidget()
        DaypilotWidgetLiveActivity()
    }
}
