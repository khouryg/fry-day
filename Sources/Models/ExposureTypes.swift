import Foundation

enum ClothingLevel: Int, CaseIterable, Codable {
    case none = -1
    case minimal = 0
    case light = 1
    case moderate = 2
    case heavy = 3
    
    var description: String {
        switch self {
        case .none: return "Nude!"
        case .minimal: return "Minimal (swimwear)"
        case .light: return "Light (shorts, tee)"
        case .moderate: return "Moderate (pants, tee)"
        case .heavy: return "Heavy (pants, sleeves)"
        }
    }
    
    var shortDescription: String {
        switch self {
        case .none: return "Nude!"
        case .minimal: return "Minimal"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        }
    }
    
    var exposureFactor: Double {
        switch self {
        case .none: return 1.0
        case .minimal: return 0.80
        case .light: return 0.50
        case .moderate: return 0.30
        case .heavy: return 0.10
        }
    }
}

enum SunscreenLevel: Int, CaseIterable, Codable {
    case none = 0
    case spf15 = 15
    case spf30 = 30
    case spf50 = 50
    case spf100 = 100
    
    var description: String {
        switch self {
        case .none: return "None"
        case .spf15: return "SPF 15"
        case .spf30: return "SPF 30"
        case .spf50: return "SPF 50"
        case .spf100: return "SPF 100+"
        }
    }
    
    var uvTransmissionFactor: Double {
        switch self {
        case .none: return 1.0      // 100% UV passes through
        case .spf15: return 0.07    // ~7% UV passes through (blocks 93%)
        case .spf30: return 0.03    // ~3% UV passes through (blocks 97%)
        case .spf50: return 0.02    // ~2% UV passes through (blocks 98%)
        case .spf100: return 0.01   // ~1% UV passes through (blocks 99%)
        }
    }
}

enum SkinType: Int, CaseIterable, Codable {
    case type1 = 1
    case type2 = 2
    case type3 = 3
    case type4 = 4
    case type5 = 5
    case type6 = 6
    
    var description: String {
        switch self {
        case .type1: return "Very fair"
        case .type2: return "Fair"
        case .type3: return "Light"
        case .type4: return "Medium"
        case .type5: return "Dark"
        case .type6: return "Very dark"
        }
    }
    
    var vitaminDFactor: Double {
        switch self {
        case .type1: return 1.25   // Very fair produces more
        case .type2: return 1.1    // Fair produces more
        case .type3: return 1.0    // Light skin is reference
        case .type4: return 0.7    // Medium skin
        case .type5: return 0.4    // Dark skin
        case .type6: return 0.2    // Very dark skin
        }
    }
}

