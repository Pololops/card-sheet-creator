import Domain
import SwiftUI

struct SheetInspector: View {
  @Bindable var model: LibraryModel
  let sheet: Sheet
  let images: ImageCache
  let selectedSlot: Int?
  let onEditDimensions: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Planche").font(Design.Typography.body.weight(.bold))
      NameField(name: sheet.name) { model.rename(.sheet(sheet.id), to: $0) }
      dimensions
      if let image = selectedImage {
        SelectedSlotSection(
          sheet: sheet, image: image, slotNumber: (selectedSlot ?? 0) + 1, images: images,
          onRecenter: { model.setCrop(.centered, for: image, inSheet: sheet.id) })
      }
      Spacer(minLength: 0)
      SavedFooter(date: sheet.updatedAt)
    }
    .padding(16)
  }

  private var selectedImage: ImageRef? {
    guard let selectedSlot, let contents = try? sheet.slotContents(), contents.indices.contains(selectedSlot)
    else { return nil }
    return contents[selectedSlot]
  }

  private var dimensions: some View {
    VStack(alignment: .leading, spacing: 9) {
      InspectorHeader(title: "Dimensions")
      InspectorRow(
        label: "Cases",
        value:
          "\(sheet.geometry.slot.width.formattedOneDecimal) × \(sheet.geometry.slot.height.formattedOneDecimal) mm"
      )
      InspectorRow(label: "Gouttière", value: "\(sheet.geometry.gutter.formatted) mm")
      if let origin = sheet.sourceTemplateID.flatMap(model.template(id:)) {
        InspectorRow(label: "Gabarit d'origine", value: origin.name)
      }
      Button("Modifier les dimensions…", action: onEditDimensions)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .padding(.top, 2)
    }
  }
}

private struct SelectedSlotSection: View {
  let sheet: Sheet
  let image: ImageRef
  let slotNumber: Int
  let images: ImageCache
  let onRecenter: () -> Void

  @State private var thumbnail: CGImage?
  @State private var size: PixelSize?

  var body: some View {
    let anchor = sheet.crop(for: image)
    let clones = sheet.cloneCount(of: image) - 1
    VStack(alignment: .leading, spacing: 12) {
      InspectorHeader(title: "Case sélectionnée · \(slotNumber)")
      HStack(spacing: 10) {
        Group {
          if let thumbnail {
            Image(decorative: thumbnail, scale: 1).resizable().aspectRatio(contentMode: .fill)
          } else {
            Rectangle().fill(.quaternary)
          }
        }
        .frame(width: 54, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        VStack(alignment: .leading, spacing: 2) {
          Text(image.originalName).font(Design.Typography.body.weight(.semibold)).lineLimit(1)
          if let size {
            Text("\(size.width.formatted()) × \(size.height.formatted()) px · \(effectiveDPI(size)) ppp")
              .font(Design.Typography.caption).foregroundStyle(.secondary).monospacedDigit()
          }
        }
      }
      if clones > 0 {
        Label {
          Text("\(clones) clone\(clones > 1 ? "s" : "") sur cette planche")
        } icon: {
          RoundedRectangle(cornerRadius: 2)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            .frame(width: 14, height: 10)
        }
        .font(Design.Typography.callout)
      }
      framingRow(anchor)
      Button("Recentrer", action: onRecenter)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .disabled(Crop.isCentered(anchor))
      Text(
        "Glisse l'image dans sa case, ou utilise ← → (⇧ pour 5 mm). L'image couvre toujours toute la case."
      )
      .font(Design.Typography.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
    .task(id: image) {
      size = await images.displaySize(of: image)
      thumbnail = await images.thumbnail(of: image, maxPixelSize: 160)
    }
  }

  private func framingRow(_ anchor: CropAnchor) -> some View {
    let isHorizontal =
      size.map {
        Double($0.width) / Double($0.height) > sheet.geometry.slot.width.mm / sheet.geometry.slot.height.mm
      } ?? true
    let position = isHorizontal ? anchor.x : anchor.y
    return VStack(alignment: .leading, spacing: 7) {
      HStack {
        Text(isHorizontal ? "Cadrage horizontal" : "Cadrage vertical")
        Spacer()
        Text(Crop.isCentered(anchor) ? "Centré" : "Décalé")
          .fontWeight(.semibold)
          .foregroundStyle(Crop.isCentered(anchor) ? Design.Palette.centerGuide : .secondary)
      }
      .font(Design.Typography.body)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(.quaternary).frame(height: 6)
          Rectangle().fill(Design.Palette.centerGuide).frame(width: 1.5, height: 14)
            .offset(x: proxy.size.width / 2)
          Circle().fill(.white).shadow(color: .black.opacity(0.3), radius: 2, y: 1).frame(
            width: 16, height: 16
          )
          .offset(x: proxy.size.width * position - 8)
        }
        .frame(height: 16)
      }
      .frame(height: 16)
      .accessibilityHidden(true)
    }
  }

  private func effectiveDPI(_ size: PixelSize) -> Int {
    let cover = Crop.coverRect(image: size, slot: sheet.geometry.slot, anchor: .centered)
    return Int((Double(size.width) / (cover.width / 25.4)).rounded())
  }
}
