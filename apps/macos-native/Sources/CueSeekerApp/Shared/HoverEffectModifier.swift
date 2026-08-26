import SwiftUI

/// The project's button style: it draws the label and nothing else. SwiftUI's
/// own `.plain` dims the label while the mouse is held down, and the design
/// system has no pressed state for any button, so every button uses this one
/// instead and keeps the appearance it already had until it is released.
struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
