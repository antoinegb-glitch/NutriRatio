import PhotosUI
import SwiftUI

struct PhotoScreen: View {
    @State private var model = PhotoViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    let onProduct: (VerificationInput) -> Void

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Photographiez le tableau nutritionnel")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text("Cadrez uniquement le tableau, bien à plat, net et sans reflet. La lecture se fait sur l'iPhone ; vous vérifierez les valeurs ensuite.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if model.state == .processing {
                    ProgressView("Lecture du tableau…")
                        .padding()
                } else {
                    if cameraAvailable {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Prendre une photo", systemImage: "camera")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choisir dans la photothèque", systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                if case .failed(let message) = model.state {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Button("Saisir les valeurs à la main") {
                        onProduct(VerificationInput(product: Product()))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Photo")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in handle(image) }
                .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    handle(image)
                } else {
                    model.loadFailed()
                }
            }
        }
    }

    private func handle(_ image: UIImage) {
        Task {
            if let input = await model.process(image) { onProduct(input) }
        }
    }
}

/// Appareil photo système (prise de vue unique).
private struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
