import WidgetKit
import SwiftUI

@main
struct NAVAWidgetBundle: WidgetBundle {
    var body: some Widget {
        NAVAActivityWidget()
        NAVAQuickLaunchWidget()
    }
}
