import SwiftUI

struct PasteRecipeView: View {
    let onParsed: (ParsedRecipe) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Collez la recette : la liste d'ingrédients suffit, avec ou sans les étapes. Vous vérifierez chaque ligne ensuite.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .focused($focused)
                .frame(minHeight: 220)
                .padding(8)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Texte de la recette")

            HStack {
                PasteButton(payloadType: String.self) { strings in
                    text = strings.joined(separator: "\n")
                }
                if !isEmpty {
                    Button("Effacer", role: .destructive) { text = "" }
                }
                Spacer()
            }

            Button {
                focused = false
                onParsed(RecipeTextParser.parse(text))
            } label: {
                Text("Analyser le texte").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isEmpty)

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("Coller une recette")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { focused = false }
            }
        }
    }
}
