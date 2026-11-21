import AppKit
import SwiftUI

/// Values taken from the validated mockups (docs/adr/0010). One family, SF Pro: hierarchy comes from
/// weight and primary/secondary colour, like Apple's own apps.
enum Design {
  enum Palette {
    static let canvas = dynamic(light: 0xDADADF, dark: 0x2B2B30)
    static let paper = Color.white
    /// Fixed rather than semantic: drawn on the always-white paper, it must ignore the selected-row highlight.
    static let templateOutline = Color.black.opacity(0.5)
    static let centerGuide = rgb(0xE5177E)
    static let marginHatch = rgb(0xFF9500).opacity(0.42)
    static let draftBackground = rgb(0xFFF4E5)
    static let draftText = rgb(0x8A4B00)
    static let warning = rgb(0xB25E00)
    static let changedField = rgb(0xC77700)
    static let printerReady = rgb(0x2E9E50)
    static let dragBadge = rgb(0xE0352B)
    /// Neutral grey around a colour reference: fixed, so the surround never biases the eye in dark mode.
    static let referenceFrame = rgb(0x808080)
    static let success = dynamic(light: 0x2C6E3F, dark: 0x5BD27A)
    /// The unfilled part of a step marker, a progress dot or the drying ring.
    static let progressTrack = Color.secondary.opacity(0.18)
    static let currentStep = Color.accentColor.opacity(0.12)
    /// The invitation to calibrate: tinted like the accent, never glass, readable in light and dark.
    static let offerBackground = Color.accentColor.opacity(0.14)
    static let offerStroke = Color.accentColor.opacity(0.35)
    /// The version on offer in the update sheet, tinted like the accent to stand out from the installed one.
    static let newVersionChip = Color.accentColor.opacity(0.14)
    static let onAccent = Color.white
    /// Text on the always-white paper rectangle: fixed for the same reason as the paper itself.
    static let onPaper = Color.black.opacity(0.62)
  }

  enum Metrics {
    static let sidebarWidth: CGFloat = 268
    static let inspectorWidth: CGFloat = 284
    static let rowHeight: CGFloat = 60
    static let sidebarThumbnail = CGSize(width: 34, height: 48)
    static let pickerThumbnail = CGSize(width: 63, height: 89)
    static let dialogRadius: CGFloat = 26
    static let fieldWidth: CGFloat = 62
    static let canvasTopInset: CGFloat = 28
    static let canvasBottomInset: CGFloat = 92
    /// Content area of the colour calibration window (the 840 × 660 mockup minus its title bar).
    static let calibrationWindow = CGSize(width: 840, height: 616)
    static let calibrationSideColumn: CGFloat = 290
    static let letterTile: CGFloat = 48
    static let referenceSide: CGFloat = 200
    static let referenceFramePadding: CGFloat = 24
    static let verificationReferenceSide: CGFloat = 96
    static let dryingRing: CGFloat = 128
    static let verificationRing: CGFloat = 112
    /// Same construction as the print dialog, a little narrower: it holds a title and two chips, no form.
    static let updateDialogWidth: CGFloat = 480
    static let updateAppIcon: CGFloat = 64
  }

  enum Typography {
    /// 11 pt: captions, row subtitles, section headers.
    static let caption = Font.subheadline
    /// 12 pt: secondary buttons, helper text.
    static let callout = Font.callout
    /// 13 pt: body.
    static let body = Font.body
    /// 15 pt: key figure such as "3 × 3 = 9 cartes".
    static let figure = Font.title3.weight(.bold)
    /// 15 pt: the instruction a calibration step leads with.
    static let lead = Font.title3
    /// 17 pt: dialog titles.
    static let dialogTitle = Font.title2.weight(.bold)
    /// 22 pt: the heading of a calibration step.
    static let stepTitle = Font.title.weight(.bold)
    /// 26 pt: the closing "C'est réglé".
    static let stepHero = Font.largeTitle.weight(.bold)
    /// 17 pt: the letter naming a patch, the one thing to read on the tile.
    static let tileLetter = Font.title2.weight(.bold)
  }

  private static func rgb(_ hex: UInt32) -> Color {
    Color(nsColor: nsColor(hex))
  }

  private static func dynamic(light: UInt32, dark: UInt32) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? nsColor(dark) : nsColor(light)
      })
  }

  private static func nsColor(_ hex: UInt32) -> NSColor {
    NSColor(
      srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }
}
