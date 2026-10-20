import Domain
import SwiftUI

/// Templates and sheets as Pixelmator-style layers: thumbnail on the left, name and summary on the right.
struct LibrarySidebar: View {
  @Bindable var model: LibraryModel
  let images: ImageCache
  let onNewSheet: () -> Void

  @State private var templatesExpanded = true
  @State private var sheetsExpanded = true
  @State private var renaming: LibraryItem?
  @State private var newName = ""

  var body: some View {
    List(selection: $model.selection) {
      Section(isExpanded: $templatesExpanded) {
        ForEach(model.templates) { template in
          LibraryRow(title: template.name, subtitle: template.summary) {
            TemplateThumbnail(geometry: template.geometry, size: Design.Metrics.sidebarThumbnail)
          }
          .tag(LibraryItem.template(template.id))
          .contextMenu { contextMenu(for: .template(template.id), name: template.name) }
        }
      } header: {
        SectionHeader(title: "Gabarits", count: model.templates.count, addLabel: "Nouveau gabarit") {
          _ = model.createTemplate()
        }
      }

      Section(isExpanded: $sheetsExpanded) {
        if model.sheets.isEmpty {
          EmptySheetsCard(onNewSheet: onNewSheet)
        }
        ForEach(model.sheets) { sheet in
          LibraryRow(title: sheet.name, subtitle: sheet.summary) {
            SheetThumbnail(sheet: sheet, images: images, size: Design.Metrics.sidebarThumbnail)
          }
          .tag(LibraryItem.sheet(sheet.id))
          .contextMenu { contextMenu(for: .sheet(sheet.id), name: sheet.name) }
        }
      } header: {
        SectionHeader(
          title: "Planches", count: model.sheets.count, addLabel: "Nouvelle planche", add: onNewSheet)
      }
    }
    .listStyle(.sidebar)
    .onDeleteCommand { model.delete(model.selection) }
    .alert("Renommer", isPresented: isRenaming) {
      TextField("Nom", text: $newName)
      Button("Annuler", role: .cancel) {}
      Button("Renommer") { if let renaming { model.rename(renaming, to: newName) } }
    }
  }

  private var isRenaming: Binding<Bool> {
    Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
  }

  @ViewBuilder
  private func contextMenu(for item: LibraryItem, name: String) -> some View {
    Button("Renommer…") {
      newName = name
      renaming = item
    }
    Button("Dupliquer") { model.duplicate(item) }
    Divider()
    Button("Supprimer", role: .destructive) {
      model.delete(model.selection.contains(item) ? model.selection : [item])
    }
  }
}

private struct SectionHeader: View {
  let title: String
  let count: Int
  let addLabel: String
  let add: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      Text(title)
      Text("\(count)").fontWeight(.medium)
      Spacer()
      Button(action: add) {
        Image(systemName: "plus").frame(width: 28, height: 26).contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(addLabel)
    }
  }
}

private struct EmptySheetsCard: View {
  let onNewSheet: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Aucune planche").font(Design.Typography.body.weight(.semibold))
      Text("Glisse des images sur un gabarit pour créer ta première planche.")
        .font(Design.Typography.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Button("Nouvelle planche…", action: onNewSheet)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(
      RoundedRectangle(cornerRadius: 12).strokeBorder(
        .tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
    )
    .selectionDisabled()
  }
}

struct LibraryRow<Thumbnail: View>: View {
  let title: String
  let subtitle: String
  @ViewBuilder var thumbnail: Thumbnail

  var body: some View {
    HStack(spacing: 10) {
      thumbnail
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(Design.Typography.body.weight(.semibold)).lineLimit(1)
        Text(subtitle).font(Design.Typography.caption).foregroundStyle(.secondary).monospacedDigit()
          .lineLimit(1)
      }
    }
    .frame(minHeight: Design.Metrics.rowHeight - 12)
    .accessibilityElement(children: .combine)
  }
}

extension Template {
  var summary: String {
    guard let layout = try? Domain.GridLayout.make(geometry) else { return "Dimensions invalides" }
    return
      "\(layout.columns) × \(layout.rows) · \(geometry.slot.width.formatted) × \(geometry.slot.height.formatted)"
  }
}

extension Sheet {
  var summary: String {
    let cards = ((try? slotContents()) ?? []).compactMap { $0 }.count
    let uniqueImages = Set(images).count
    return "\(cards) carte\(cards > 1 ? "s" : "") · \(uniqueImages) image\(uniqueImages > 1 ? "s" : "")"
  }
}
