import Foundation

func formatDuration(_ seconds: Double) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
        return String(format: "%d:%02d", minutes, secs)
    }
}

func relativeDate(for date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .spellOut
    return formatter.localizedString(for: date, relativeTo: Date())
}

// Phase 2 stub — implement timecode with tenths when playhead is wired
func formatTimecode(_ seconds: Double) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    let tenths = Int((seconds - Double(totalSeconds)) * 10)

    if hours > 0 {
        return String(format: "%d:%02d:%02d.%d", hours, minutes, secs, tenths)
    } else {
        return String(format: "%d:%02d.%d", minutes, secs, tenths)
    }
}
