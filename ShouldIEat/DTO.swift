//
//  DTO.swift
//  ShouldIEat
//
//  Created by sanket patel on 2/1/24.
//

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
    
    struct Product: Codable, Hashable {
        let brand: String?
        let name: String?
        let ingredients: [Ingredient]
        let images: [ImageLocationInfo]
        
        private var ingredientsDepth: Int {
            var depth: Int = 0
            ingredients.forEach { i in
                depth = max(1, depth)
                i.ingredients.forEach { i2 in
                    depth = max(2, depth)
                    i2.ingredients.forEach { i3 in
                        depth = 3
                    }
                }
            }
            return depth
        }
        
        private func ingredientsListDepth2(ingredients: [Ingredient]) -> String {
            ingredients.map { ingredient in
                if ingredient.ingredients.isEmpty {
                    return ingredient.name
                } else {
                    return ingredient.name
                        + " ("
                        + ingredient.ingredients.map { i in i.name }.joined(separator: ", ")
                        + ")"
                }
            }
            .joined(separator: ", ")
            .capitalized
        }
        
        var ingredientsList: String {
            print(ingredients)
            if ingredientsDepth == 3 {
                return ingredients.map { ingredient in
                    return ingredient.name
                        + ": "
                        + ingredientsListDepth2(ingredients: ingredient.ingredients)
                }
                .joined(separator: "\n")
            } else {
                return ingredientsListDepth2(ingredients: ingredients)
            }
        }
        
        func decoratedIngredientsList(
            ingredientRecommendations: [DTO.IngredientRecommendation]?
        ) -> AttributedString {
            var attributedString = AttributedString(ingredientsList)
            
            guard let ingredientRecommendations = ingredientRecommendations else {
                return attributedString
            }
            
            for recommendation in ingredientRecommendations {
                let color: Color
                switch recommendation.safetyRecommendation {
                case .maybeUnsafe:
                    color = .yellow
                case .definitelyUnsafe:
                    color = .red
                }
                
                if let range = attributedString.range(of: recommendation.ingredientName, options: .caseInsensitive) {
                    attributedString[range].foregroundColor = color
                }
            }
            
            return attributedString
        }
    }
    
    enum SafetyRecommendation: String, Codable {
        case maybeUnsafe = "MaybeUnsafe"
        case definitelyUnsafe = "DefinitelyUnsafe"
    }
    
    struct IngredientRecommendation: Codable {
        let ingredientName: String
        let safetyRecommendation: SafetyRecommendation
        let reasoning: String
    }
}