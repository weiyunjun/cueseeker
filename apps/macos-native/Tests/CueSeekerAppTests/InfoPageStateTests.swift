import Testing
@testable import CueSeekerApp

@Test
func searchNoQueryStateExplainsLiveSearchWithoutSubmit() {
    let message = InfoPageState.searchNoQuery.message

    #expect(
        message
            == "Type a query in the topbar Search field to start searching."
    )
    #expect(!message.contains("Return"))
}
