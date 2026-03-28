import SwiftUI

struct ContentView: View {
    @State private var vm = SimulationViewModel()

    var body: some View {
        NavigationSplitView {
            ConfigurationView(vm: vm)
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 400)
        } detail: {
            ResultsView(vm: vm)
        }
        .background(.background)
    }
}
