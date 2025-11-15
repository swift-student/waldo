import SwiftUI

public struct SecondaryToolbarModifier<ToolbarContent: View>: ViewModifier {
    let toolbarContent: () -> ToolbarContent

    public func body(content: Content) -> some View {
        SecondaryToolbar(
            mainContent: { content },
            toolbarContent: toolbarContent
        )
    }
}

extension View {
    public func secondaryToolbar<ToolbarContent: View>(
        @ViewBuilder content: @escaping () -> ToolbarContent
    ) -> some View {
        self.modifier(SecondaryToolbarModifier(toolbarContent: content))
    }
}

private struct SecondaryToolbar<MainContent: View, ToolbarContent: View>: View {

    let mainContent: MainContent
    let toolbarContent: ToolbarContent

    init(mainContent: () -> MainContent, toolbarContent: () -> ToolbarContent) {
        self.mainContent = mainContent()
        self.toolbarContent = toolbarContent()
    }

    var body: some View {
        VStack(spacing: 0) {
                HStack {
                    Spacer()
                    toolbarContent
                    Spacer()
                }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.bar)

            Divider()

            mainContent
        }
    }

}
