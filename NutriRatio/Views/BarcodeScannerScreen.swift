import SwiftUI
import VisionKit

struct BarcodeScannerScreen: View {
    @State private var model = BarcodeViewModel()
    @State private var manualCode = ""
    @FocusState private var manualFocused: Bool
    let onProduct: (VerificationInput) -> Void

    var body: some View {
        VStack(spacing: 0) {
            scannerArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.9))
            bottomPanel
        }
        .navigationTitle("Code-barres")
        .navigationBarTitleDisplayMode(.inline)
        // La zone caméra est sombre et passe sous la barre : titre et bouton en clair.
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await model.prepareCamera() }
    }

    @ViewBuilder
    private var scannerArea: some View {
        switch model.camera {
        case .checking:
            ProgressView().tint(.white)
        case .available:
            DataScannerRepresentable { code in
                Task {
                    if let input = await model.scanned(code) { onProduct(input) }
                }
            }
            .accessibilityLabel("Caméra : visez le code-barres du produit")
        case .denied:
            ContentUnavailableView(
                "Caméra non autorisée",
                systemImage: "video.slash",
                description: Text("Autorisez l'appareil photo dans Réglages > NutriRatio, ou saisissez le code ci-dessous.")
            )
            .foregroundStyle(.white)
        case .unsupported:
            ContentUnavailableView(
                "Scanner indisponible sur cet appareil",
                systemImage: "barcode.viewfinder",
                description: Text("Saisissez le code-barres ci-dessous.")
            )
            .foregroundStyle(.white)
        }
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch model.lookup {
            case .idle:
                Text("Visez un code-barres EAN-13 ou EAN-8, ou saisissez-le.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .loading(let code):
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Recherche du produit \(code)…").font(.subheadline)
                }
            case .failed(let code, let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                Button("Réessayer avec \(code)") { search(code) }
                    .font(.subheadline)
            }

            HStack {
                TextField("Code-barres", text: $manualCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($manualFocused)
                Button("Rechercher") {
                    manualFocused = false
                    search(manualCode)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!OpenFoodFactsService.isValidBarcode(manualCode))
            }
        }
        .padding()
        .background(.bar)
    }

    private func search(_ code: String) {
        Task {
            if let input = await model.fetch(code) { onProduct(input) }
        }
    }
}

/// Scanner VisionKit limité aux codes EAN-13 et EAN-8.
private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let code = barcode.payloadStringValue {
                    onCode(code)
                    return
                }
            }
        }

        /// Toucher un code déjà surligné relance la recherche.
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .barcode(let barcode) = item, let code = barcode.payloadStringValue {
                onCode(code)
            }
        }
    }
}
