import Foundation

@Observable class PreferenceExamples {

    @MainActor var placeholder: String = examples[0]
    @MainActor var preferences: [String] = []

    private var exampleIndex = 0
    private var charIndex = 0
    private var timer: Timer?
    
    private static let examples = [
        "Add your preferences here",
        "Avoid Gluten",
        "No Palm oil for me",
        "No animal products, but eggs & dairy are ok",
        "No peanuts but other nuts are ok",
        "I don't like pine nuts",
        "I can't stand garlic"
    ]

    func startAnimatingExamples() {
        stopAnimatingExamples()
        animateExamples()
    }

    func stopAnimatingExamples() {
        timer?.invalidate()
        timer = nil
        exampleIndex = 0
        charIndex = 0
        Task { @MainActor in
            placeholder = PreferenceExamples.examples[0]
        }
    }

    private func animateExamples() {
        if exampleIndex >= PreferenceExamples.examples.count {
            exampleIndex = 0
        }
        
        if charIndex == 0 {
            Task { @MainActor in
                if exampleIndex > 1 {
                    preferences.append(PreferenceExamples.examples[exampleIndex-1])
                } else {
                    preferences = []
                }
            }
        }
        
        let example = PreferenceExamples.examples[exampleIndex]

        if charIndex <= example.count {
            let index = example.index(example.startIndex, offsetBy: charIndex)
            charIndex += 1
            Task { @MainActor in
                placeholder = String(example[..<index])
            }
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                self?.animateExamples()
            }
        } else {
            charIndex = 0
            exampleIndex += 1
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.animateExamples()
            }
        }
    }
}
