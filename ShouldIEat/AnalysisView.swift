//
//  AnalysisView.swift
//  ShouldIEat
//
//  Created by sanket patel on 8/29/23.
//

import SwiftUI

struct IngredientLabel {
    let image: UIImage
    let imageOCRText: String?
}

enum CapturedItem {
    case barcode(String)
    case ingredientLabel(IngredientLabel)
}

struct AnalysisView: View {
    
    @Binding var userPreferenceText: String
    @Binding var analyzedItems: [AnalyzedItem]
    
    @State private var capturedItem: CapturedItem?
    @State private var analysis: String?
    @State private var errorExtractingIngredientsList: Bool = false
    
    var backend = Backend()

    var body: some View {
        if let capturedItem = self.capturedItem {
            switch capturedItem {
            case .ingredientLabel(let label):
                ingredientAnalysis(label: label)
            case .barcode(let barcode):
                barcodeAnalysis(barcode: barcode)
            }
        } else {
            CaptureView(capturedItem: $capturedItem)
        }
    }
    
    private func barcodeAnalysis(barcode: String) -> some View {
        Text(barcode)
    }

    private func ingredientAnalysis(label: IngredientLabel) -> some View {
        VStack {
            Image(uiImage: label.image)
                .resizable()
                .scaledToFit()
                .padding()
            if let analysis = self.analysis {
                Text(analysis)
                    .onAppear {
                        self.analyzedItems.append(AnalyzedItem(Image: label.image, Analysis: analysis))
                    }
            } else {
                if let imageOCRText = label.imageOCRText {
                    if errorExtractingIngredientsList {
                        Text("Failed to extract ingredients list from this food label:")
                        Text("\(imageOCRText)")
                    } else {
                        ProgressView()
                            .onAppear {
                                Task {
                                    let ingredientsList =
                                    try await backend.extractIngredients(ocrText: imageOCRText)
                                    if let ingredientsList = ingredientsList {
                                        let analysisResponse =
                                        try await backend.generateRecommendation(
                                            ingredients: ingredientsList,
                                            userPreference: userPreferenceText)
                                        DispatchQueue.main.async {
                                            self.analysis = analysisResponse
                                        }
                                    } else {
                                        DispatchQueue.main.async {
                                            self.errorExtractingIngredientsList = true
                                        }
                                    }
                                }
                            }
                    }
                } else {
                    Text("This does not look like a valid food label:")
                    Text("\(label.imageOCRText ?? "Empty")")
                }
            }
        }
    }
}

struct AnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        @State var userPreferenceText: String = ""
        @State var analyzedItems: [AnalyzedItem] = []
        AnalysisView(userPreferenceText: $userPreferenceText,
                     analyzedItems: $analyzedItems)
    }
}