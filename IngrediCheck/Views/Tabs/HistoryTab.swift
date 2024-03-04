import SwiftUI

struct HistoryTab: View {
    
    @Environment(AppState.self) var appState
    @Environment(WebService.self) var webService

    var body: some View {
        @Bindable var appStateBinding = appState
        NavigationStack(path: $appStateBinding.historyTabState.routes) {
            List {
                ForEach(appState.historyTabState.historyItems, id:\.client_activity_id) { item in
                    Button {
                        appState.historyTabState.routes.append(item)
                    } label: {
                        HistoryItemCardView(item: item)
                    }
                }
            }
            .listStyle(.inset)
            .refreshable {
                if let history = try? await webService.fetchHistory() {
                    appState.historyTabState.historyItems = history
                }
            }
            .navigationDestination(for: DTO.HistoryItem.self) { item in
                HistoryItemDetailView(item: item)
            }
            .navigationTitle("HISTORY")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct HistoryItemCardView: View {
    let item: DTO.HistoryItem
    
    @State private var image: UIImage? = nil
    @Environment(WebService.self) var webService
    
    var placeholderImage: some View {
        Image(systemName: "photo.badge.plus.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var body: some View {
        HStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                placeholderImage
            }

            VStack(alignment: .leading) {
                Text(item.brand ?? "Unknown Brand")
                    .font(.headline)
                    .padding(.top)
                
                Text(item.name ?? "Unknown Name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Spacer()
        }
        .task {
            if let firstImage = item.images.first,
               let image = try? await webService.fetchImage(imageLocation: firstImage, imageSize: .small) {
                DispatchQueue.main.async {
                    self.image = image
                }
            }
        }
    }
}

struct HistoryItemDetailView: View {
    let item: DTO.HistoryItem
    
    @State private var feedbackData = FeedbackData()
    @Environment(WebService.self) var webService
    @Environment(AppState.self) var appState
    @Environment(UserPreferences.self) var userPreferences

    private func submitFeedback() {
        Task {
            try? await webService.submitFeedback(
                clientActivityId: item.client_activity_id,
                feedbackData: feedbackData
            )
        }
    }
    
    var body: some View {
        @Bindable var userPreferencesBindable = userPreferences
        ScrollView {
            VStack(spacing: 15) {
                if let name = item.name {
                    Text(name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal)
                }
                if !item.images.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(item.images.indices, id:\.self) { index in
                                HeaderImage(imageLocation: item.images[index])
                                    .frame(width: UIScreen.main.bounds.width - 60)
                            }
                            Button(action: {
                                appState.activeSheet = .feedback(FeedbackConfig(
                                    feedbackData: $feedbackData,
                                    feedbackCaptureOptions: .imagesOnly,
                                    onSubmit: { submitFeedback() }
                                ))
                            }, label: {
                                Image(systemName: "photo.badge.plus")
                                    .font(.largeTitle)
                                    .padding()
                            })
                        }
                        .scrollTargetLayout()
                    }
                    .padding(.leading)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                    .frame(height: (UIScreen.main.bounds.width - 60) * (4/3))
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(.largeTitle)
                        .padding()
                }
                if let brand = item.brand {
                    Text(brand)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal)
                }
                if item.ingredients.isEmpty {
                    Text("Help! Our Product Database is missing an Ingredient List for this Product. Submit Product Images and Earn IngrediPoiints\u{00A9}!")
                        .font(.subheadline)
                        .padding()
                        .multilineTextAlignment(.center)
                    Button(action: {
                        userPreferencesBindable.captureType = .ingredients
                        appState.checkTabState.routes = []
                        appState.activeTab = .check
                    }, label: {
                        Image(systemName: "photo.badge.plus")
                            .font(.largeTitle)
                    })
                    Text("Product will be analyzed instantly!")
                        .font(.subheadline)
                } else {
                    let product = DTO.Product(
                        barcode: item.barcode,
                        brand: item.brand,
                        name: item.name,
                        ingredients: item.ingredients,
                        images: item.images
                    )
                    AnalysisResultView(product: product, ingredientRecommendations: item.ingredient_recommendations)
                    
                    Text(product.decoratedIngredientsList(ingredientRecommendations: item.ingredient_recommendations))
                        .padding(.horizontal)
                }
            }
        }
        .scrollIndicators(.hidden)
        .onChange(of: feedbackData.rating) { oldRating, newRating in
            switch newRating {
            case -1:
                appState.activeSheet = .feedback(FeedbackConfig(
                    feedbackData: $feedbackData,
                    feedbackCaptureOptions: .feedbackAndImages,
                    onSubmit: { submitFeedback() }
                ))
            default:
                submitFeedback()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !item.images.isEmpty && !item.ingredients.isEmpty {
                    Button(action: {
                        appState.activeSheet = .feedback(FeedbackConfig(
                            feedbackData: $feedbackData,
                            feedbackCaptureOptions: .imagesOnly,
                            onSubmit: { submitFeedback() }
                        ))
                    }, label: {
                        Image(systemName: "photo.badge.plus")
                            .font(.subheadline)
                    })
                }
                StarButton()
                UpvoteButton(rating: $feedbackData.rating)
                DownvoteButton(rating: $feedbackData.rating)
            }
        }
    }
}
