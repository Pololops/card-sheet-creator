public enum SheetNaming {
  private static let fallback = "Planche"

  /// One image names the sheet after itself; a batch after the folder it came from.
  public static func baseName(fileNames: [String], folderName: String?) -> String {
    if fileNames.count == 1, let file = fileNames.first {
      let stem = file.split(separator: ".").dropLast().joined(separator: ".")
      let name = stem.isEmpty ? file : stem
      return name.prefix(1).uppercased() + name.dropFirst()
    }
    guard let folderName, !folderName.isEmpty else { return fallback }
    return folderName
  }
}
