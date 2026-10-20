import Testing

@testable import Domain

@Suite struct SheetNamingTests {
  @Test func singleImageNamesTheSheetAfterTheFile() {
    #expect(SheetNaming.baseName(fileNames: ["lune.png"], folderName: "Images") == "Lune")
  }

  @Test func severalImagesNameTheSheetAfterTheirFolder() {
    #expect(
      SheetNaming.baseName(fileNames: ["a.png", "b.png"], folderName: "Contes du soir") == "Contes du soir")
  }

  @Test func missingNamesFallBackToAGenericName() {
    #expect(SheetNaming.baseName(fileNames: ["a.png", "b.png"], folderName: nil) == "Planche")
  }
}
