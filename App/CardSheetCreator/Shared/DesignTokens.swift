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
    /// 17 pt: dialog titles.
    static let dialogTitle = Font.title2.weight(.bold)
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
