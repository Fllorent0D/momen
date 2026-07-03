import SwiftUI
import StandupKit
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Bridges raw image `Data` to a SwiftUI `Image` on the current platform.
private func imageFromData(_ data: Data) -> Image? {
    #if canImport(AppKit)
    guard let nsImage = NSImage(data: data) else { return nil }
    return Image(nsImage: nsImage)
    #elseif canImport(UIKit)
    guard let uiImage = UIImage(data: data) else { return nil }
    return Image(uiImage: uiImage)
    #else
    return nil
    #endif
}

struct AvatarView: View {
    let participant: Participant
    let size: CGFloat
    /// Optional override for the disc tint. When `nil`, the participant's stable
    /// per-person identity accent (``PulseAccent``) is used.
    var backgroundColor: Color? = nil

    var body: some View {
        Group {
            if let data = participant.avatarData,
               let image = imageFromData(data) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Text(participant.initials)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .background(backgroundColor ?? PulseAccent.color(for: participant.id), in: Circle())
        .clipShape(Circle())
    }
}

#if canImport(AppKit)
/// Button to pick a photo for a participant (macOS file picker)
struct AvatarPickerButton: View {
    @Binding var participant: Participant

    var body: some View {
        Button {
            pickImage()
        } label: {
            if participant.avatarData != nil {
                AvatarView(participant: participant, size: 24)
            } else {
                // Initials on the participant's stable identity accent — same tint
                // they carry everywhere else (queue, overlay, stats).
                Text(participant.initials.isEmpty ? "?" : participant.initials)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(PulseAccent.color(for: participant.id), in: Circle())
            }
        }
        .buttonStyle(.plain)
        .help("Choisir une photo")
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url,
              let image = NSImage(contentsOf: url) else { return }

        // Resize to 64x64 for storage
        let resized = resize(image: image, to: NSSize(width: 64, height: 64))
        participant.avatarData = resized.tiffRepresentation.flatMap {
            NSBitmapImageRep(data: $0)?.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
        }
    }

    private func resize(image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
#endif
