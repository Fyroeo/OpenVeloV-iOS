import SwiftUI
import UIKit
import VLSKit

/// A bike row you can slide left to unlock.
///
/// Unlocking starts a real, billable ride, so this is a deliberate slide past a threshold
/// — not a light flick — with haptics at the crossing and on firing. Tapping the row
/// still opens the confirm sheet; the swipe is the express path. VoiceOver gets an
/// equivalent "Unlock" action, since it can't perform the drag.
struct UnlockableBikeRow: View {
    let bike: Bike
    let isBooked: Bool
    let isRecommended: Bool
    let isUnlockable: Bool
    let onTap: () -> Void
    let onUnlock: () -> Void

    @State private var offset: CGFloat = 0
    @State private var passedThreshold = false

    private let maxReveal: CGFloat = 104
    private let triggerThreshold: CGFloat = 88

    var body: some View {
        ZStack(alignment: .trailing) {
            // Only in the hierarchy during a leftward drag — at rest there is no green to
            // bleed at the row's corners.
            if offset < 0 {
                unlockTrack
            }
            BikeRowView(bike: bike, isBooked: isBooked, isRecommended: isRecommended)
                .background(Color(.secondarySystemGroupedBackground))
                .offset(x: offset)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
                .gesture(dragGesture)
                .accessibilityAction(named: Text("Unlock")) {
                    if isUnlockable { onUnlock() }
                }
        }
        // Height follows the row, so the greedy green fill can't stretch it; clipped so the
        // sliding row and the track never spill past the row.
        .fixedSize(horizontal: false, vertical: true)
        .clipped()
    }

    private var unlockTrack: some View {
        Color.green
            .overlay(alignment: .trailing) {
                VStack(spacing: 2) {
                    Image(systemName: passedThreshold ? "lock.open.fill" : "lock.fill")
                    (passedThreshold ? Text("Release") : Text("Unlock"))
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.trailing, 22)
                .opacity(Double(min(1, abs(offset) / triggerThreshold)))
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard isUnlockable else { return }
                // Horizontal-left only; a vertical drag belongs to the scroll view.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                offset = max(min(0, value.translation.width), -maxReveal)
                let crossed = abs(offset) >= triggerThreshold
                if crossed != passedThreshold {
                    passedThreshold = crossed
                    UIImpactFeedbackGenerator(style: crossed ? .medium : .light).impactOccurred()
                }
            }
            .onEnded { value in
                let horizontal = abs(value.translation.width) > abs(value.translation.height)
                let fired = isUnlockable && horizontal
                    && abs(min(0, value.translation.width)) >= triggerThreshold
                if fired {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onUnlock()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { offset = 0 }
                passedThreshold = false
            }
    }
}
