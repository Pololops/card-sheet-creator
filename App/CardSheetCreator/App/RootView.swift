import Domain
import Printing
import Rendering
import Storage
import SwiftUI
import UniformTypeIdentifiers

/// The single window: glass sidebar · canvas · inspector, as in the reference mockups.
struct RootView: View {
  let environment: AppEnvironment
  @Bindable private var model: LibraryModel
  @State private var zoom = CanvasZoom()
  @State private var isInspectorShown = true
  @State private var isNewSheetShown = false
  @State private var printController: PrintController?
  @State private var isImagePickerShown = false
  @State private var importTarget: Template?
  @State private var resizeDraft: ResizeDraft?
  @State private var selectedSlot: Int?
  @State private var calibrationFailure: String?
  @Environment(\.undoManager) private var undoManager
  @Environment(\.openWindow) private var openWindow

  init(environment: AppEnvironment) {
    self.environment = environment
    model = environment.model
  }

  var body: some View {
    NavigationSplitView {
      LibrarySidebar(model: model, images: environment.images) { isNewSheetShown = true }
        .navigationSplitViewColumnWidth(Design.Metrics.sidebarWidth)
    } detail: {
      DetailCanvas(
        model: model, images: environment.images, zoom: zoom, resizeDraft: $resizeDraft,
        selectedSlot: $selectedSlot, onDropImages: createSheets, onApplyResize: applyResize
      )
      .navigationTitle(title)
      .navigationSubtitle(subtitle)
      .toolbar { toolbar }
      .inspector(isPresented: $isInspectorShown) {
        inspector.inspectorColumnWidth(Design.Metrics.inspectorWidth)
      }
    }
    .task { await model.load() }
    .onAppear { model.undoManager = undoManager }
    .onChange(of: model.selection) {
      selectedSlot = nil
      resizeDraft = nil
      model.discardGeometryPreview()
    }
    .sheet(isPresented: $isNewSheetShown) {
      NewSheetDialog(templates: model.templates, preselected: model.selectedTemplate ?? model.templates.first)
      {
        chooseImages(for: $0)
      }
    }
    // SwiftUI resets `isPresented` before calling the completion: the template must outlive it.
    .fileImporter(
      isPresented: $isImagePickerShown, allowedContentTypes: UTType.cardImages, allowsMultipleSelection: true
    ) { result in
      guard let template = importTarget, case .success(let urls) = result else { return }
      createSheets(urls, template)
    }
    .fileDialogConfirmationLabel("Sélectionner")
    .sheet(item: $printController) { controller in
      PrintDialog(
        controller: controller, images: environment.images, onSettingsChange: { model.savePrintSettings($0) },
        onCalibrate: {
          printController = nil
          openCalibration(printerName: controller.settings.printerName, sheetIDs: controller.sheets.map(\.id))
        })
    }
    .sheet(item: offerBinding) { offer in
      TemplateOfferDialog(
        offer: offer, onAccept: model.acceptTemplateOffer(named:), onDecline: model.declineTemplateOffer)
    }
    .alert(
      "Calibration impossible",
      isPresented: Binding(get: { calibrationFailure != nil }, set: { _ in calibrationFailure = nil })
    ) {
      Button("OK") {}
    } message: {
      Text(calibrationFailure ?? "")
    }
    .colorCalibrationHandoff(
      route: environment.calibrationRoute, library: model,
      onReopen: { openPrint(sheets: $0, printerName: $1) }
    )
    .focusedSceneValue(\.appActions, actions)
  }

  // MARK: - Content

  @ViewBuilder
  private var inspector: some View {
    if let resizeDraft {
      ResizeInspector(draft: resizeDraft)
    } else if let template = model.selectedTemplate {
      TemplateInspector(model: model, template: template)
    } else if let sheet = model.selectedSheet {
      SheetInspector(
        model: model, sheet: sheet, images: environment.images, selectedSlot: selectedSlot,
        onEditDimensions: { resizeDraft = ResizeDraft(sheet: sheet) })
    } else {
      Text("Sélectionne un gabarit ou une planche.")
        .font(Design.Typography.body)
        .foregroundStyle(.secondary)
        .padding(16)
    }
  }

  /// Each mode declares its own items: swapping only the content of shared items leaves AppKit's
  /// glass shadow stale until the next hover. The prominent item is the one main action of the view.
  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
    if resizeDraft == nil {
      if let template = model.selectedTemplate {
        ToolbarItem {
          Button("Nouveau gabarit", systemImage: "plus") { _ = model.createTemplate() }
            .labelStyle(.titleAndIcon)
        }
        ToolbarItem {
          Button("Créer une planche…", systemImage: "photo") { chooseImages(for: template) }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.glassProminent)
        }
      } else {
        ToolbarItem {
          Button("Nouvelle planche…", systemImage: "plus") { isNewSheetShown = true }
            .labelStyle(.titleAndIcon)
        }
        ToolbarItem {
          Button("Imprimer", systemImage: "printer") { openPrint() }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.glassProminent)
            .disabled(model.selectedSheets.isEmpty || environment.calibrationRoute.isWindowOpen)
        }
      }
    }
  }

  private var title: String {
    model.selectedTemplate?.name ?? model.selectedSheet?.name
      ?? (model.selectedSheets.count > 1 ? "\(model.selectedSheets.count) planches" : "Card Sheet Creator")
  }

  private var subtitle: String {
    if resizeDraft != nil { return "Planche · modification des dimensions" }
    if model.selectedTemplate != nil { return "Gabarit · enregistré automatiquement" }
    if let sheet = model.selectedSheet {
      let origin = sheet.sourceTemplateID.flatMap(model.template(id:)).map { " · depuis \($0.name)" } ?? ""
      let cards = ((try? sheet.slotContents()) ?? []).compactMap { $0 }.count
      return "Planche · \(cards) cartes\(origin)"
    }
    return ""
  }

  private var offerBinding: Binding<TemplateOffer?> {
    Binding(get: { model.pendingTemplateOffer }, set: { if $0 == nil { model.declineTemplateOffer() } })
  }

  // MARK: - Actions

  private var actions: AppActions {
    AppActions(
      newTemplate: { _ = model.createTemplate() },
      newSheet: { isNewSheetShown = true },
      print: canPrint ? { openPrint() } : nil,
      zoomToFit: { zoom.mode = .fit },
      zoomToRealSize: { zoom.mode = .realSize },
      toggleInspector: { isInspectorShown.toggle() },
      calibrateColors: printController == nil
        ? { openCalibration(printerName: model.printSettings.printerName, sheetIDs: []) } : nil,
      printCalibrationPage: printCalibrationPage)
  }

  /// Two windows must not write the print settings at once: printing waits while the calibration is open.
  private var canPrint: Bool {
    !model.selectedSheets.isEmpty && resizeDraft == nil && !environment.calibrationRoute.isWindowOpen
  }

  private func chooseImages(for template: Template) {
    importTarget = template
    isImagePickerShown = true
  }

  private func createSheets(_ urls: [URL], _ template: Template) {
    Task { await model.createSheets(from: urls, template: template) }
  }

  private func applyResize() {
    guard let draft = resizeDraft else { return }
    _ = try? model.applyResize(draft)
    resizeDraft = nil
  }

  private func openPrint(sheets: [Sheet]? = nil, printerName: String? = nil) {
    var saved = model.printSettings
    if let printerName { saved.printerName = printerName }
    printController = PrintController(
      sheets: sheets ?? model.selectedSheets, saved: saved, printService: environment.printService,
      persistence: environment.persistence)
  }

  private func openCalibration(printerName: String?, sheetIDs: [UUID]) {
    environment.calibrationRoute.start(printerName: printerName, sheetIDs: sheetIDs)
    openWindow(id: WindowID.colorCalibration)
  }

  private func printCalibrationPage() {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Calibration.pdf")
    let settings = model.printSettings
    Task {
      do {
        try await CalibrationPage.renderPDF(to: url)
        try environment.printService.print(pdfAt: url, settings: settings, copies: 1)
      } catch {
        calibrationFailure = "La page de calibration n'a pas pu être imprimée : \(error.localizedDescription)"
      }
    }
  }
}

extension PrintController: Identifiable {}
extension TemplateOffer: Identifiable {
  var id: SheetGeometry { geometry }
}
