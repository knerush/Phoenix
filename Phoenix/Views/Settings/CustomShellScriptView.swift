import SwiftUI
import UniformTypeIdentifiers

struct CustomShellScriptView: View {
    @ObservedObject private var viewModel: CustomShellScriptViewModel
    
    init(viewModel: CustomShellScriptViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Shell Script")
                .font(.headline)

                Text(viewModel.selectedFilePath)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            Button {
                openFilePicker()
            } label: {
                Text("Pick a File")
            }
        }
        .padding()
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType.shellScript] // Accept shell scripts
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                // Attempt to read the file content to verify access
                _ = try String(contentsOf: url)
                viewModel.selectedFilePath = url.path
            } catch {
                viewModel.selectedFilePath = "Error reading file: \(error.localizedDescription)"
            }
        }
    }

}
