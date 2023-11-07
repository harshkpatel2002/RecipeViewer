//
//  ContentView.swift
//  RecipeCodingChallenge
//
//  Created by Harsh Patel on 11/7/23.
//

import SwiftUI

struct MealSummary: Identifiable, Decodable {
    let idMeal: String
    let strMeal: String
    let strMealThumb: String?
    
    var id: String {
        idMeal
    }
}

struct MealDetail: Identifiable, Decodable {
    let idMeal: String
    let strMeal: String
    let strInstructions: String
    var id: String {
        idMeal
    }
    var ingredientsAndMeasurements: [(ingredient: String, measure: String)] = []
    
    enum CodingKeys: String, CodingKey {
        case idMeal
        case strMeal
        case strInstructions
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        idMeal = try container.decode(String.self, forKey: .idMeal)
        strMeal = try container.decode(String.self, forKey: .strMeal)
        strInstructions = try container.decode(String.self, forKey: .strInstructions)
        
        let additionalContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var ingredientsTemp: [(ingredient: String, measure: String)] = []
        
        // We have up to 20 ingredients and measurements
        for index in 1...20 {
            let ingredientKey = DynamicCodingKeys(stringValue: "strIngredient\(index)")
            let measureKey = DynamicCodingKeys(stringValue: "strMeasure\(index)")
            if let ingredientKey = ingredientKey, let measureKey = measureKey,
               let ingredient = try additionalContainer.decodeIfPresent(String.self, forKey: ingredientKey),
               let measure = try additionalContainer.decodeIfPresent(String.self, forKey: measureKey),
               !ingredient.isEmpty && !measure.isEmpty {
                ingredientsTemp.append((ingredient: ingredient, measure: measure))
            }
        }
        ingredientsAndMeasurements = ingredientsTemp
    }
    
    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        var intValue: Int?
        init?(intValue: Int) {
            return nil
        }
    }
    
}

class MealsViewModel: ObservableObject {
    @Published var meals: [MealSummary] = []
    @Published var selectedMealDetail: MealDetail?
    
    init() {
        loadMeals()
    }
    
    func loadMeals() {
        let url = URL(string: "https://themealdb.com/api/json/v1/1/filter.php?c=Dessert")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decodedResponse = try JSONDecoder().decode([String: [MealSummary]].self, from: data)
                    DispatchQueue.main.async {
                        self.meals = decodedResponse["meals"]?.sorted(by: { $0.strMeal < $1.strMeal }) ?? []
                    }
                } catch {
                    print("Decoding error: \(error)")
                }
            }
        }.resume()
    }
    
    func loadMealDetail(id: String) {
        let url = URL(string: "https://themealdb.com/api/json/v1/1/lookup.php?i=\(id)")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decodedResponse = try JSONDecoder().decode([String: [MealDetail]].self, from: data)
                    DispatchQueue.main.async {
                        if let details = decodedResponse["meals"]?.first {
                            self.selectedMealDetail = details
                        }
                    }
                } catch {
                    print("Decoding error: \(error)")
                }
            }
        }.resume()
    }
}

struct ContentView: View {
    @ObservedObject var viewModel = MealsViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.meals) { meal in
                NavigationLink(destination: MealDetailView(mealId: meal.idMeal, viewModel: viewModel)) {
                    MealRow(meal: meal)
                }
            }
            .navigationTitle("Desserts")
        }
    }
}

struct MealRow: View {
    var meal: MealSummary
    
    var body: some View {
        HStack {
            if let urlString = meal.strMealThumb, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            }
            
            Text(meal.strMeal)
        }
    }
}

struct MealDetailView: View {
    let mealId: String
    @ObservedObject var viewModel: MealsViewModel
    @State private var showInstructions = false
    
    var body: some View {
        VStack(alignment: .leading) {
            if let mealDetail = viewModel.selectedMealDetail {
                Text(mealDetail.strMeal)
                    .font(.title)
                    .padding()
                VStack(alignment: .leading) {
                    ScrollView{
                        
                        ForEach(mealDetail.ingredientsAndMeasurements, id: \.ingredient) { ingredient, measure in
                            HStack {
                                Text(ingredient)
                                    .padding(.leading)
                                Spacer()
                                Text(measure)
                                    .padding(.trailing)
                            }
                        }
                    }
                    .border(Color.gray, width: 1)
                    .padding()
                }
                .padding(.bottom)
                
                Button(action: {
                    showInstructions.toggle()
                }) {
                    Text(showInstructions ? "Hide Recipe" : "Show Recipe")
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                }
                if showInstructions {
                    ScrollView {
                        Text(mealDetail.strInstructions)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                    }
                    .border(Color.gray, width: 1)
                    .padding()
                }
                
            } else {
                Text("Unable to retrieve. Please try again later.")
            }
        }
        .onAppear {
            viewModel.loadMealDetail(id: mealId)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
