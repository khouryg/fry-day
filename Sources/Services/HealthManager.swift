import Foundation
import HealthKit

@MainActor
final class HealthManager: ObservableObject {
    static let shared = HealthManager()
    @Published var lastError: String?
    @Published private(set) var exportStatus: String?
    @Published private(set) var exportEnabled = UserDefaults.standard.bool(forKey: "exportSunEstimatesToHealth")
    @Published private(set) var requestingExport = false
    private var exportWork: Task<Void, Never>?
    private let vitaminD = HKQuantityType.quantityType(forIdentifier: .dietaryVitaminD)!

    func setExportEnabled(_ enabled: Bool) {
        guard enabled else {
            exportEnabled = false
            UserDefaults.standard.set(false, forKey: "exportSunEstimatesToHealth")
            exportStatus = "Automatic export is off. Existing Health entries remain in Health."
            return
        }
        guard !requestingExport else { return }
        requestingExport = true
        Task {
            defer { requestingExport = false }
            do {
                guard HKHealthStore.isHealthDataAvailable() else {
                    exportStatus = "Health is not available on this device. Sessions still save locally."
                    return
                }
                try await healthStore.requestAuthorization(toShare: [vitaminD], read: [])
                exportEnabled = healthStore.authorizationStatus(for: vitaminD) == .sharingAuthorized
                UserDefaults.standard.set(exportEnabled, forKey: "exportSunEstimatesToHealth")
                exportStatus = exportEnabled
                    ? "New saved sessions will export to Health. Use Export in session history for earlier sessions."
                    : "Vitamin D write permission was not granted. Sessions still save locally."
            } catch {
                exportStatus = "Health permission could not be requested. Sessions still save locally."
            }
        }
    }

    static func vitaminDSample(for session: ExposureSession) -> HKQuantitySample? {
        guard let end = session.end, end > session.start else { return nil }
        let amount = session.totals(until: end).iu
        guard amount.isFinite, amount > 0 else { return nil }
        return HKQuantitySample(
            type: HKQuantityType.quantityType(forIdentifier: .dietaryVitaminD)!,
            quantity: HKQuantity(unit: .gramUnit(with: .micro), doubleValue: amount * 0.025),
            start: session.start, end: end,
            metadata: [
                HKMetadataKeySyncIdentifier: "com.khouryg.fryday.sun-estimate.\(session.id.uuidString)",
                HKMetadataKeySyncVersion: 1,
                "FryDayEstimateSource": "Estimated vitamin D from sun exposure; not food or supplements",
                "FryDayModel": "Inherited, unvalidated UV exposure model",
                "FryDayOriginalValueIU": amount
            ])
    }

    func export(_ session: ExposureSession) {
        guard exportEnabled else { return }
        let previous = exportWork
        exportWork = Task {
            await previous?.value
            guard exportEnabled else { return }
            guard healthStore.authorizationStatus(for: vitaminD) == .sharingAuthorized else {
                exportStatus = "Health export permission is off. Your session is saved locally; enable permission and retry from history."
                return
            }
            guard let sample = Self.vitaminDSample(for: session) else {
                exportStatus = "No positive vitamin D estimate to export. Your session remains saved locally."
                return
            }
            do {
                try await healthStore.save(sample)
                exportStatus = "Session estimate exported to Health’s dietary Vitamin D category."
            } catch {
                exportStatus = "Health export failed. Your session is saved locally; retry Export in session history."
            }
        }
    }
    private let healthStore = HKHealthStore()

    // Profile import and vitamin D export request separate permissions.
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
