import Domain
import Storage
import SwiftUI
import UniformTypeIdentifiers

/// The neutral canvas behind the floating panels, holding the selected template or sheet.
struct DetailCanvas: View {
  @Bindable var model: LibraryModel
  let images: ImageCache
  @Bindable var zoom: CanvasZoom
  @Binding var resizeDraft: ResizeDraft?
  @Binding var selectedSlot: Int?
  let onDropImages: ([URL], Template) -> Void
  let onApplyResize: () -> Void

  @State private var droppingCount: Int?
  @State private var isShowingSkipped = false
  @State private var pageFrame = CGRect.zero

  private static let contentSpace = "canvasContent"

  var body: some View {
    GeometryReader { proxy in
      let scale = zoom.scale(fitting: proxy.size)
      ZStack {
        Design.Palette.canvas
          .ignoresSafeArea()
          .backgroundExtensionEffect()
        ScrollView([.horizontal, .vertical]) {
          page(scale: scale)
            .padding(.top, Design.Metrics.canvasTopInset)
            .padding(.bottom, Design.Metrics.canvasBottomInset)
            .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
            .contentShape(Rectangle())
            .onTapGesture { selectedSlot = nil }
            .coordinateSpace(.named(Self.contentSpace))
            .modifier(
              CanvasPinch(model: model, zoom: zoom, available: proxy.size, pageFrame: pageFrame, scale: scale)
            )
        }
        .scrollIndicators(.automatic)
        VStack(spacing: 12) {
          banners
          Spacer()
          bottomControl(available: proxy.size)
        }
        .padding(.vertical, 20)
      }
      .background(TrackpadProbe(role: .canvas, onEvent: toggleZoom))
    }
  }

  /// A two-finger double-tap that no selected image took toggles between fit and physical size.
  private func toggleZoom(on event: TrackpadEvent) -> Bool {
    guard case .smartMagnify = event else { return false }
    zoom.toggleFitAndRealSize()
    return true
  }

  @ViewBuilder
  private func page(scale: Double) -> some View {
    if let template = model.selectedTemplate {
      TemplateCanvas(
        geometry: model.geometry(ofTemplate: template.id) ?? template.geometry, scale: scale,
        droppingCount: droppingCount
      )
      .onGeometryChange(for: CGRect.self) {
        $0.frame(in: .named(Self.contentSpace))
      } action: {
        pageFrame = $0
      }
      .onDrop(
        of: [.fileURL],
        delegate: ImageDropDelegate(droppingCount: $droppingCount) { onDropImages($0, template) })
    } else if let sheet = model.selectedSheet {
      VStack(spacing: 10) {
        if resizeDraft != nil { DraftBadge() }
        SheetCanvas(
          sheet: sheet, geometry: resizeDraft?.geometry ?? sheet.geometry, scale: scale, images: images,
          isEditable: resizeDraft == nil, selectedSlot: $selectedSlot
        ) { anchor, image in
          model.setCrop(anchor, for: image, inSheet: sheet.id)
        }
      }
    } else if model.selectedSheets.count > 1 {
      ContentUnavailableView(
        "\(model.selectedSheets.count) planches sélectionnées", systemImage: "printer",
        description: Text("⌘P les imprime ensemble, dans l'ordre de la barre latérale."))
    } else {
      ContentUnavailableView(
        "Aucune sélection", systemImage: "square.grid.3x3",
        description: Text("Choisis un gabarit ou une planche dans la barre latérale."))
    }
  }

  @ViewBuilder
  private func bottomControl(available: CGSize) -> some View {
    if let resizeDraft {
      ResizeBar(
        draft: resizeDraft, images: images, onCancel: { self.resizeDraft = nil }, onValidate: onApplyResize)
    } else if model.selectedTemplate != nil || model.selectedSheet != nil {
      ZoomControl(zoom: zoom, available: available)
    }
  }

  @ViewBuilder
  private var banners: some View {
    if let failure = model.saveFailure {
      CanvasBanner(
        systemImage: "exclamationmark.triangle", message: "Enregistrement impossible : \(failure)",
        tint: Design.Palette.warning
      ) {
        Button("Réessayer") { Task { try? await model.flush() } }
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
      }
    }
    if let summary = model.importSummary {
      CanvasBanner(systemImage: "checkmark.circle", message: summary.message) {
        if !summary.skipped.isEmpty {
          Button("Détails") { isShowingSkipped = true }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .popover(isPresented: $isShowingSkipped) { SkippedFilesList(files: summary.skipped) }
        }
        Button("Fermer", systemImage: "xmark") { model.importSummary = nil }
          .labelStyle(.iconOnly)
          .buttonStyle(.plain)
          .frame(width: 28, height: 28)
      }
    }
  }
}

extension ImportSummary {
  var message: String {
    let created =
      "\(createdSheets) planche\(createdSheets > 1 ? "s" : "") créée\(createdSheets > 1 ? "s" : "")"
    guard !skipped.isEmpty else { return created }
    return
      "\(created) · \(skipped.count) fichier\(skipped.count > 1 ? "s" : "") ignoré\(skipped.count > 1 ? "s" : "")"
  }
}

private struct SkippedFilesList: View {
  let files: [SkippedFile]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Fichiers ignorés").font(Design.Typography.body.weight(.bold))
      ForEach(Array(files.enumerated()), id: \.offset) { _, file in
        VStack(alignment: .leading, spacing: 1) {
          Text(file.fileName).font(Design.Typography.body)
          Text(
            file.reason == .unsupportedFormat ? "Format non pris en charge" : "Fichier illisible ou endommagé"
          )
          .font(Design.Typography.caption).foregroundStyle(.secondary)
        }
      }
    }
    .padding(16)
    .frame(minWidth: 260, alignment: .leading)
  }
}

/// Counts the files hovering over a template, then hands their URLs over on drop, in Finder order.
struct ImageDropDelegate: DropDelegate {
  @Binding var droppingCount: Int?
  let onDrop: ([URL]) -> Void

  func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.fileURL]) }

  func dropEntered(info: DropInfo) {
    droppingCount = info.itemProviders(for: [.fileURL]).count
  }

  func dropExited(info: DropInfo) {
    droppingCount = nil
  }

  func performDrop(info: DropInfo) -> Bool {
    let providers = info.itemProviders(for: [.fileURL])
    droppingCount = nil
    Task {
      var urls: [URL] = []
      for provider in providers {
        if let url = await Self.loadURL(from: provider) { urls.append(url) }
      }
      if !urls.isEmpty { onDrop(urls) }
    }
    return true
  }

  private static func loadURL(from provider: NSItemProvider) async -> URL? {
    await withCheckedContinuation { continuation in
      _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
    }
  }
}
