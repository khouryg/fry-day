import Foundation
import HealthKit

@MainActor
final class HealthManager: ObservableObject {
    @Published var lastError: String?
    private let healthStore = HKHealthStore()

    // Optional, read-only personalization. Never write synthesized vitamin D as dietary intake.
    func loadProfile(completion: @escaping (Int?, SkinType?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            lastError = "Health is not available on this device. You can set your profile manually."
            return
        }
        let birth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        let skin = HKObjectType.characteristicType(forIdentifier: .fitzpatrickSkinType)!
        healthStore.requestAuthorization(toShare: [], read: [birth, skin]) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }
                guard success else { self.lastError = error?.localizedDescription; return }
                // Read denial is intentionally indistinguishable from unavailable data.
                var age: Int?
                if let components = try? self.healthStore.dateOfBirthComponents(), let date = Calendar.current.date(from: components) {
                    age = Calendar.current.dateComponents([.year], from: date, to: Date()).year
                }
                let raw = try? self.healthStore.fitzpatrickSkinType().skinType.rawValue
                let skinType = raw.flatMap { SkinType(rawValue: $0) }
                self.lastError = age == nil && skinType == nil ? "No profile data was available. You can set your profile manually." : nil
                completion(age, skinType)
            }
        }
    }
}
