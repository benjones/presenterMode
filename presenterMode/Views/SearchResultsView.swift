import SwiftUI

struct SearchResultsView: View {
    let results: [SearchResultData]
    let searchText: String
    let onSwitch: (SearchResultData) -> Void
    let onAdd: (SearchResultData) -> Void

    private let columns = Array(
        repeating: GridItem(.fixed(220)),
        count: 4
    )

    var body: some View {
        VStack {
            Text("Search results! \(searchText)")

            LazyVGrid(columns: columns) {
                ForEach(results, id: \.self) { result in
                    SearchResultCard(
                        result: result,
                        onSwitch: {
                            onSwitch(result)
                        },
                        onAdd : {
                            onAdd(result)
                        }
                    )
                }
            }
        }
    }
}
