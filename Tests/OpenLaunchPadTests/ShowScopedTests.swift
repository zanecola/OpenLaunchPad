import Testing
@testable import OpenLaunchPad

struct ShowScopedTests {
    @Test
    func valueLastsForTheShowItWasSetIn() {
        var dialog = ShowScoped<String>()

        dialog.set("Uninstall Mail?", presentationID: 3)

        #expect(dialog.value(in: 3) == "Uninstall Mail?")
    }

    @Test
    func valueLeftFromAnEarlierShowIsGone() {
        var dialog = ShowScoped<String>()

        dialog.set("Uninstall Mail?", presentationID: 3)

        #expect(dialog.value(in: 4) == nil)
    }

    @Test
    func clearingRemovesTheValue() {
        var dialog = ShowScoped<String>()
        dialog.set("Uninstall Mail?", presentationID: 3)

        dialog.clear()

        #expect(dialog.value(in: 3) == nil)
    }

    @Test
    func viewWithoutAValueNeverReadsThePresentation() {
        let dialog = ShowScoped<String>()
        var reads = 0

        let value = dialog.value(in: {
            reads += 1
            return 3
        }())

        #expect(value == nil)
        #expect(reads == 0)
    }
}
