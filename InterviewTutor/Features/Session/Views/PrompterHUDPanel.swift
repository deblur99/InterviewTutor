import AppKit
import SwiftUI

struct PrompterHUDState: Equatable {
    var isVisible: Bool
    var keywords: [String]
    var fillerCount: Int
    var keywordCoveragePercent: Int
    var gazePercent: Int
}

struct PrompterHUDView: View {
    let state: PrompterHUDState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("프롬프터 HUD", systemImage: "rectangle.on.rectangle")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                metric("필러", value: "\(state.fillerCount)")
                metric("키워드", value: "\(state.keywordCoveragePercent)%")
                metric("응시", value: "\(state.gazePercent)%")
            }

            if state.keywords.isEmpty {
                Text("키워드 없음")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(state.keywords, id: \.self) { keyword in
                        Text(keyword)
                            .font(.callout)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.blue.opacity(0.15), in: Capsule())
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
final class PrompterHUDController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<PrompterHUDView>?

    func update(state: PrompterHUDState, anchorWindow: NSWindow?) {
        guard state.isVisible else {
            hide()
            return
        }

        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 220),
                styleMask: [.nonactivatingPanel, .hudWindow, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.isMovableByWindowBackground = true
            panel.title = "프롬프터"
            panel.backgroundColor = .clear
            panel.isOpaque = false
            self.panel = panel
        }

        let view = PrompterHUDView(state: state)
        if let hostingView {
            hostingView.rootView = view
        } else {
            let hostingView = NSHostingView(rootView: view)
            hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 220)
            panel?.contentView = hostingView
            self.hostingView = hostingView
        }

        positionPanel(anchorWindow: anchorWindow)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    private func positionPanel(anchorWindow: NSWindow?) {
        guard let panel, let anchorWindow else { return }
        let anchorFrame = anchorWindow.frame
        let size = panel.frame.size
        let origin = NSPoint(
            x: anchorFrame.maxX + 16,
            y: anchorFrame.maxY - size.height
        )
        panel.setFrameOrigin(origin)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
