import SwiftUI

/// A custom search bar component following design system patterns
struct SearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    let placeholder: String
    let onSearchButtonClicked: () -> Void
    let onCancelButtonClicked: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    init(
        text: Binding<String>,
        isSearching: Binding<Bool>,
        placeholder: String = "Search for places...",
        onSearchButtonClicked: @escaping () -> Void = {},
        onCancelButtonClicked: @escaping () -> Void = {}
    ) {
        self._text = text
        self._isSearching = isSearching
        self.placeholder = placeholder
        self.onSearchButtonClicked = onSearchButtonClicked
        self.onCancelButtonClicked = onCancelButtonClicked
    }
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField(placeholder, text: $text)
                    .focused($isTextFieldFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        onSearchButtonClicked()
                    }
                    .onChange(of: isTextFieldFocused) { _, focused in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearching = focused
                        }
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if isSearching {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        text = ""
                        isTextFieldFocused = false
                        isSearching = false
                        onCancelButtonClicked()
                    }
                }
                .foregroundColor(.blue)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    @Previewable @State var searchText = ""
    @Previewable @State var isSearching = false
    
    return VStack {
        SearchBar(
            text: $searchText,
            isSearching: $isSearching,
            onSearchButtonClicked: {
                print("Search button clicked")
            },
            onCancelButtonClicked: {
                print("Cancel button clicked")
            }
        )
        
        Spacer()
    }
    .padding()
}