import Testing
@testable import NotepadMac

@Test func localizationCatalogLoadsBundledNativeLanguages() {
    let options = AppLocalizationCatalog.loadBundledOptions()

    #expect(options.count > 90)
    #expect(options.first?.fileName == "english.xml")
    #expect(options.contains { $0.fileName == "chineseSimplified.xml" && $0.displayName == "简体中文" })
    #expect(options.contains { $0.fileName == "french.xml" && $0.displayName == "Français" })
}

@Test func localizationResolvesSimplifiedChineseBundle() {
    let original = Localization.currentLocalizationFileName
    defer { Localization.apply(localizationFileName: original, postNotification: false) }
    Localization.apply(localizationFileName: "chineseSimplified.xml", postNotification: false)
    let string = Localization.string("app.preferences", default: "Preferences...")
    #expect(string == "偏好设置...")
}

@Test func nativeLangFallbackProvidesFrenchMenuTranslations() {
    let translations = NativeLangTranslations.load(fileName: "french.xml", bundle: Localization.resourceBundle)

    #expect(translations?.localizedValue(for: "menu.tools") == "Outils")
    #expect(translations?.localizedValue(for: "run.command") == "Exécuter...")
    #expect(translations?.localizedValue(for: "app.preferences") == "Préférences...")
    #expect(translations?.localizedValue(forDefaultValue: "Copy") == "Copier")
    #expect(translations?.localizedValue(forDefaultValue: "Find...") == "Rechercher...")
}

@Test func localizationProvidesFrenchDialogFallbacks() {
    let translations = NativeLangTranslations.load(fileName: "french.xml", bundle: Localization.resourceBundle)

    #expect(translations?.localizedValue(for: "plugins.panelTitle") == "Gestionnaire des modules d’extension")
    #expect(translations?.localizedValue(for: "plugins.install.panelPrompt") == "Installer")
    #expect(translations?.localizedValue(for: "plugins.column.plugin") == "Modules d’extension")
    #expect(translations?.localizedValue(for: "styleConfigurator.panelTitle") == "Configurateur de coloration syntaxique")
    #expect(translations?.localizedValue(for: "styleConfigurator.bold") == "Gras")
    #expect(translations?.localizedValue(for: "styleConfigurator.language") == "Langage :")
    #expect(translations?.localizedValue(for: "styleConfigurator.style") == "Description :")
    #expect(translations?.localizedValue(for: "udl.panelTitle") == "Langage utilisateur")
    #expect(translations?.localizedValue(for: "udl.import") == "Importer...")
    #expect(translations?.localizedValue(for: "udl.export") == "Exporter...")
    #expect(translations?.localizedValue(for: "udl.edit") == "Définir votre langage...")
    #expect(translations?.localizedValue(for: "udl.edit.panelTitle") == "Définir votre langage...")
    #expect(translations?.localizedValue(for: "udl.delete") == "Supprimer")
    #expect(translations?.localizedValue(for: "udl.edit.save") == "Enregistrer")
    #expect(translations?.localizedValue(for: "udl.edit.cancel") == "Annuler")
    #expect(translations?.localizedValue(for: "udl.column.extensions") == "Ext. :")
    #expect(translations?.localizedValue(for: "udl.edit.structuredFgColor") == "Premier plan")
    #expect(translations?.localizedValue(for: "udl.edit.structuredBgColor") == "Arrière-plan")
    #expect(translations?.localizedValue(for: "udl.edit.structuredFontName") == "Nom :")
    #expect(translations?.localizedValue(for: "udl.edit.structuredFontStyle") == "Police :")
    #expect(translations?.localizedValue(for: "udl.edit.structuredNesting") == "Héberge :")
}

@Test func localizationProvidesFrenchMessageBoxFallbacks() {
    let translations = NativeLangTranslations.load(fileName: "french.xml", bundle: Localization.resourceBundle)
    let importMessage = translations?.messageBox(tag: "UDL_importSuccessful")
    let exportMessage = translations?.messageBox(tag: "UDL_exportSuccessful")

    #expect(importMessage?.title == "UDL")
    #expect(importMessage?.message == "Importation réussie.")
    #expect(exportMessage?.title == "UDL")
    #expect(exportMessage?.message == "Exportation réussie.")
}
