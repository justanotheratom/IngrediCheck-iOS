import Foundation
import SwiftUI

class DTO {

    enum ImageLocationInfo: Codable, Equatable, Hashable {
        case url(URL)
        case imageFileHash(String)
        
        enum CodingKeys: String, CodingKey {
            case url
            case imageFileHash
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let urlString = try container.decodeIfPresent(String.self, forKey: .url),
               let url = URL(string: urlString) {
                self = .url(url)
            } else if let imageFileHash = try container.decodeIfPresent(String.self, forKey: .imageFileHash) {
                self = .imageFileHash(imageFileHash)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Unable to decode ImageLocationInfo"))
            }
        }
    }
    
    struct Ingredient: Codable, Hashable {
        let name: String
        let vegan: Bool?
        let vegetarian: Bool?
        let ingredients: [Ingredient]
        
        enum CodingKeys: String, CodingKey {
            case name
            case vegan
            case vegetarian
            case ingredients
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            vegan = try Ingredient.decodeYesNoMaybe(from: container, forKey: .vegan)
            vegetarian = try Ingredient.decodeYesNoMaybe(from: container, forKey: .vegetarian)
            ingredients = try container.decodeIfPresent([Ingredient].self, forKey: .ingredients) ?? []
        }
        
        private static func decodeYesNoMaybe(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Bool? {
            if let value = try container.decodeIfPresent(String.self, forKey: key) {
                switch value {
                case "yes":
                    return true
                case "no":
                    return false
                default:
                    return nil
                }
            } else {
                return nil
            }
        }
    }
    
    struct AnnotatedIngredient {
        let name: String
        let safetyRecommendation: SafetyRecommendation
        let reasoning: String?
        let preference: String?
        let ingredient: [AnnotatedIngredient]
    }
    
    struct DecoratedIngredientListFragment {
        let fragment: String
        let safetyRecommendation: SafetyRecommendation
        let reasoning: String?
        let preference: String?
    }
    
    struct HistoryItem: Codable, Hashable, Equatable {
        let created_at: String
        let client_activity_id: String
        let barcode: String?
        let brand: String?
        let name: String?
        let ingredients: [Ingredient]
        let images: [ImageLocationInfo]
        let ingredient_recommendations: [IngredientRecommendation]
        let rating: Int
        let favorited: Bool
    }
    
    struct ListItem: Codable, Hashable, Equatable {
        let created_at: String
        let list_id: String
        let list_item_id: String
        let barcode: String?
        let brand: String?
        let name: String?
        let ingredients: [Ingredient]
        let images: [ImageLocationInfo]
    }
    
    struct Product: Codable, Hashable {
        let barcode: String?
        let brand: String?
        let name: String?
        let ingredients: [Ingredient]
        let images: [ImageLocationInfo]

        private func productHasIngredient(ingredientName: String) -> Bool {
            func inner(ingredients: [Ingredient]) -> Bool {
                return ingredients.contains { i in
                    if i.name.caseInsensitiveCompare(ingredientName) == .orderedSame {
                        return true
                    }
                    return inner(ingredients: i.ingredients)
                }
            }
            return inner(ingredients: self.ingredients)
        }
        
        private func ingredientToString(_ ingredient: Ingredient) -> String {
            if ingredient.ingredients.isEmpty {
                return ingredient.name
            } else {
                return ingredient.name
                    + " ("
                    + ingredient.ingredients.map { i in
                        ingredientToString(i)
                      }
                      .joined(separator: ", ")
                      .capitalized
                    + ")"
            }
        }
        
        public var ingredientsListAsString: String {
            return ingredients.map { ingredient in
                ingredientToString(ingredient)
            }
            .joined(separator: ", ")
            .capitalized
        }

        func calculateMatch(
            ingredientRecommendations: [IngredientRecommendation]
        ) -> ProductRecommendation {
            var result: ProductRecommendation = .match
            for recommendation in ingredientRecommendations {
                if productHasIngredient(ingredientName: recommendation.ingredientName) {
                    switch recommendation.safetyRecommendation {
                    case .definitelyUnsafe:
                        result = .notMatch
                    case .maybeUnsafe:
                        if result == .match {
                            result = .needsReview
                        }
                    default:
                        break
                    }
                }
            }
            return result
        }
    }
    
    enum SafetyRecommendation: String, Codable {
        case maybeUnsafe = "MaybeUnsafe"
        case definitelyUnsafe = "DefinitelyUnsafe"
        case safe = "Safe"
        case none = "None"
    }
    
    struct IngredientRecommendation: Codable, Equatable, Hashable {
        let ingredientName: String
        let safetyRecommendation: SafetyRecommendation
        let reasoning: String
        let preference: String
    }
    
    enum ProductRecommendation {
        case match
        case needsReview
        case notMatch
    }

    struct ImageInfo: Codable {
        let imageFileHash: String
        let imageOCRText: String
        let barcode: String?
    }
    
    struct FeedbackData: Codable {
        var rating: Int?
        var reasons: [String]?
        var note: String?
        var images: [ImageInfo]?
    }
            
    static func decoratedIngredientsList(
        ingredients: [Ingredient],
        ingredientRecommendations: [IngredientRecommendation]?
    ) -> [DecoratedIngredientListFragment] {
        func annotatedIngredients(ingredients: [Ingredient]) -> [AnnotatedIngredient] {
            return ingredients.map { i in
                let recommendation = ingredientRecommendations?.first { r in
                    return r.ingredientName.caseInsensitiveCompare(i.name) == .orderedSame
                }
                if let recommendation {
                    return AnnotatedIngredient(
                        name: i.name,
                        safetyRecommendation: recommendation.safetyRecommendation,
                        reasoning: recommendation.reasoning,
                        preference: recommendation.preference,
                        ingredient: annotatedIngredients(ingredients: i.ingredients)
                    )
                } else {
                    return AnnotatedIngredient(
                        name: i.name,
                        safetyRecommendation: .safe,
                        reasoning: nil,
                        preference: nil,
                        ingredient: annotatedIngredients(ingredients: i.ingredients)
                    )
                }
            }
        }
        func decoratedIngredientListFragments(annotatedIngredients: [AnnotatedIngredient]) -> [DecoratedIngredientListFragment] {
            var result: [DecoratedIngredientListFragment] = []
            for (i, ai) in annotatedIngredients.enumerated() {
                if ai.ingredient.isEmpty {
                    var fragment = ai.name.capitalized
                    if i != (annotatedIngredients.count - 1) {
                        fragment += ", "
                    }
                    result.append(DecoratedIngredientListFragment(
                        fragment: fragment,
                        safetyRecommendation: ai.safetyRecommendation,
                        reasoning: ai.reasoning,
                        preference: ai.preference
                    ))
                } else {
                    result.append(contentsOf: [
                        DecoratedIngredientListFragment(
                            fragment: ai.name.capitalized + " ",
                            safetyRecommendation: ai.safetyRecommendation,
                            reasoning: ai.reasoning,
                            preference: ai.preference
                        ),
                        DecoratedIngredientListFragment(
                            fragment: "(",
                            safetyRecommendation: .none,
                            reasoning: nil,
                            preference: nil
                        )
                    ])
                    var subFragments = decoratedIngredientListFragments(annotatedIngredients: ai.ingredient)
                    let suffix = (i == annotatedIngredients.count - 1) ? ")" : "), "
                    let lastFragment = DecoratedIngredientListFragment(
                        fragment: subFragments.last!.fragment + suffix,
                        safetyRecommendation: subFragments.last!.safetyRecommendation,
                        reasoning: subFragments.last?.reasoning,
                        preference: subFragments.last?.preference
                    )
                    subFragments[subFragments.count - 1] = lastFragment
                    result.append(contentsOf: subFragments)
                }
            }
            return result
        }
        func splitStringPreservingSpaces(_ input: String) -> [String] {
            var result = input.split(separator: " ", omittingEmptySubsequences: true).map { String($0) + " " }

            if let last = result.last, input.last != " " {
                result[result.count - 1] = last.trimmingCharacters(in: .whitespaces)
            }

            return result
        }
        func splitDecoratedFragmentsIfNeeded(decoratedFragments: [DecoratedIngredientListFragment]) -> [DecoratedIngredientListFragment] {
            var result: [DecoratedIngredientListFragment] = []
            for fragment in decoratedFragments {
                if case .safe = fragment.safetyRecommendation {
                    for word in splitStringPreservingSpaces(fragment.fragment) {
                        result.append(DecoratedIngredientListFragment(
                            fragment: word,
                            safetyRecommendation: .safe,
                            reasoning: nil,
                            preference: nil
                        ))
                    }
                } else {
                    result.append(fragment)
                }
            }
            return result
        }
        let annotatedIngredients = annotatedIngredients(ingredients: ingredients)
        let decoratedFragments = decoratedIngredientListFragments(annotatedIngredients: annotatedIngredients)
        return splitDecoratedFragmentsIfNeeded(decoratedFragments: decoratedFragments)
    }
}
