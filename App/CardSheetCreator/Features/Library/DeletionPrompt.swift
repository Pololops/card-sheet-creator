import Foundation

/// What the confirmation dialog shows before anything is deleted (ADR 0013).
struct DeletionPrompt: Identifiable {
  let items: Set<LibraryItem>
  let title: String
  let message: String

  var id: Set<LibraryItem> { items }
}

extension LibraryModel {
  /// Nil when none of `items` is in the library: there is nothing to ask about.
  func deletionPrompt(for items: Set<LibraryItem>) -> DeletionPrompt? {
    let present = items.filter(isInLibrary)
    guard !present.isEmpty else { return nil }
    let includesTemplate = present.contains { if case .template = $0 { true } else { false } }
    return DeletionPrompt(
      items: present, title: "Supprimer \(subject(of: present)) ?",
      message: (includesTemplate ? Self.sheetsAreKeptNotice + " " : "") + Self.undoNotice)
  }

  /// Items are checked again here: the library may have changed while the dialog was open.
  func confirmDeletion(_ prompt: DeletionPrompt) {
    delete(prompt.items.filter(isInLibrary))
  }

  private static let undoNotice = "Tu pourras annuler avec ⌘Z."
  private static let sheetsAreKeptNotice = "Les planches faites avec un gabarit supprimé sont conservées."

  private func isInLibrary(_ item: LibraryItem) -> Bool {
    switch item {
    case .template(let id): template(id: id) != nil
    case .sheet(let id): sheet(id: id) != nil
    }
  }

  private func subject(of items: Set<LibraryItem>) -> String {
    guard items.count == 1, let item = items.first else { return "\(items.count) éléments" }
    switch item {
    case .template(let id): return "« \(template(id: id)?.name ?? "") »"
    case .sheet(let id): return "« \(sheet(id: id)?.name ?? "") »"
    }
  }
}
