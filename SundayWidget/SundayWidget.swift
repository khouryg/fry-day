import WidgetKit
import SwiftUI
import ActivityKit
import Foundation

// Shared number formatter for widget
private let sharedNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter
}()

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { makeEntry(at: Date(), forecast: nil) }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        Task { completion(makeEntry(at: Date(), forecast: await WidgetForecastLoader.shared.cached())) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        Task {
            let forecast = await WidgetForecastLoader.shared.forecast()
            let now = Date()
            let entries = ForecastRefreshPolicy.timelineDates(from: now).map { makeEntry(at: $0, forecast: forecast) }
            // iOS controls delivery. Existing entries remain useful if the refresh is delayed.
            let refresh = now.addingTimeInterval(ForecastRefreshPolicy.refreshInterval + Double.random(in: 0...300))
            completion(Timeline(entries: entries, policy: .after(refresh)))
        }
    }
    private func makeEntry(at date: Date, forecast: WeatherSnapshot?) -> SimpleEntry {
        let shared = UserDefaults(suiteName: "group.com.khouryg.fryday")
        let totalsDate = shared?.object(forKey: "totalsUpdatedAt") as? Date
        let today = totalsDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false
        let uv = forecast.flatMap { ForecastRefreshPolicy.uv(at: date, snapshot: $0) }
        return SimpleEntry(date: date, uvIndex: uv ?? 0,
            todaysTotal: today ? shared?.double(forKey: "todaysTotal") ?? 0 : 0,
            isTracking: shared?.bool(forKey: "isTracking") ?? false,
            vitaminDRate: 0,
            locationName: shared?.string(forKey: "locationName") ?? "",
            moonPhaseName: shared?.string(forKey: "moonPhaseName") ?? "", altitude: forecast?.altitude ?? 0,
            uvMultiplier: 1, cloudCover: forecast?.cloudCover ?? 0,
            isStale: uv == nil, sessionID: shared?.string(forKey: "sessionID"), forecastUpdatedAt: forecast?.updatedAt)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let uvIndex: Double
    let todaysTotal: Double
    let isTracking: Bool
    let vitaminDRate: Double
    let locationName: String
    let moonPhaseName: String
    let altitude: Double
    let uvMultiplier: Double
    let cloudCover: Double
    var isStale: Bool = false
    var sessionID: String? = nil
    var forecastUpdatedAt: Date? = nil
}

struct SundayWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            Text("Not Supported")
        }
    }
}

struct SmallWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack {
            // Main content
            VStack(spacing: 8) {
                // UV Index
                VStack(spacing: 2) {
                    Text("UV · Open-Meteo")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text(entry.isStale ? "—" : String(format: "%.1f", entry.uvIndex))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Today's total
                VStack(spacing: 2) {
                    Text("TODAY")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text(formatNumber(entry.todaysTotal))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("IU est.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Tracking indicator
                if entry.isTracking {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                }
            }
            
            Spacer()
            
            // Location at bottom left
            if !entry.locationName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                    Text(entry.locationName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var gradientColors: [Color] {
        let hour = Calendar.current.component(.hour, from: entry.date)
        let minute = Calendar.current.component(.minute, from: entry.date)
        let timeProgress = Double(hour) + Double(minute) / 60.0
        
        if timeProgress < 5 || timeProgress > 22 {
            return [Color(hex: "0f1c3d"), Color(hex: "0a1228")]
        } else if timeProgress < 8 {
            return [Color(hex: "ee9b7a"), Color(hex: "fdb095")]
        } else if timeProgress < 10 {
            return [Color(hex: "fdb095"), Color(hex: "87ceeb")]
        } else if timeProgress < 17 {
            return [Color(hex: "4a90e2"), Color(hex: "7bb7e5")]
        } else if timeProgress < 19 {
            return [Color(hex: "87ceeb"), Color(hex: "fdb095")]
        } else if timeProgress < 20.5 {
            return [Color(hex: "ee9b7a"), Color(hex: "c44569")]
        } else {
            return [Color(hex: "c44569"), Color(hex: "6a4c93")]
        }
    }
    
    func formatNumber(_ value: Double) -> String {
        if value < 1000 {
            return "\(Int(value))"
        } else if value < 10000 {
            return sharedNumberFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        } else {
            return String(format: "%.0fK", value / 1000)
        }
    }
}

struct MediumWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Top row with UV info and button
                HStack(alignment: .top, spacing: 0) {
                    // Left side: UV Index and metrics
                    HStack(alignment: .top, spacing: 16) {
                        // UV Index section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("UV · Open-Meteo")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            Text(entry.isStale ? "—" : String(format: "%.1f", entry.uvIndex))
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        // TODAY and RATE/POTENTIAL to the right
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TODAY")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                HStack(spacing: 2) {
                                    Text(formatNumber(entry.todaysTotal))
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("IU est.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            
                            if let updated = entry.forecastUpdatedAt {
                                VStack(spacing: 3) {
                                    Text("FORECAST").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6))
                                    Text(updated, style: .time).font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Right side: Button/Moon icon at top
                    if entry.uvIndex > 0 || entry.isTracking {
                        Link(destination: URL(string: entry.isTracking ? "fryday://end?session=\(entry.sessionID ?? "")" : "fryday://session")!) {
                            VStack(spacing: 4) {
                                Image(systemName: entry.isTracking ? "stop.circle.fill" : "sun.max.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white)
                                Text(entry.isTracking ? "End" : "Open")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    } else {
                        // Moon phase when UV is 0
                        VStack(spacing: 4) {
                            Image(systemName: moonPhaseIcon(from: entry.moonPhaseName))
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.8))
                                .symbolRenderingMode(.hierarchical)
                            Text(entry.isStale ? "Refresh UV" : "Night")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Bottom info line: location, elevation, cloud
                HStack(spacing: 12) {
                    // Location with flexible space
                    if !entry.locationName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.6))
                            Text(entry.locationName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .layoutPriority(0)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Elevation with fixed space
                    if entry.altitude > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.to.line")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                            Text("\(Int(entry.altitude))m")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            if entry.uvMultiplier > 1.0 {
                                Text("(+\(Int((entry.uvMultiplier - 1.0) * 100))%)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .layoutPriority(1)
                    }
                    
                    // Cloud cover with fixed space
                    if entry.cloudCover > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                            Text("\(Int(entry.cloudCover))%")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .layoutPriority(1)
                    }
                }
                .padding(.top, 6)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var gradientColors: [Color] {
        let hour = Calendar.current.component(.hour, from: entry.date)
        let minute = Calendar.current.component(.minute, from: entry.date)
        let timeProgress = Double(hour) + Double(minute) / 60.0
        
        if timeProgress < 5 || timeProgress > 22 {
            return [Color(hex: "0f1c3d"), Color(hex: "0a1228")]
        } else if timeProgress < 8 {
            return [Color(hex: "ee9b7a"), Color(hex: "fdb095")]
        } else if timeProgress < 10 {
            return [Color(hex: "fdb095"), Color(hex: "87ceeb")]
        } else if timeProgress < 17 {
            return [Color(hex: "4a90e2"), Color(hex: "7bb7e5")]
        } else if timeProgress < 19 {
            return [Color(hex: "87ceeb"), Color(hex: "fdb095")]
        } else if timeProgress < 20.5 {
            return [Color(hex: "ee9b7a"), Color(hex: "c44569")]
        } else {
            return [Color(hex: "c44569"), Color(hex: "6a4c93")]
        }
    }
    
    func formatNumber(_ value: Double) -> String {
        if value < 1000 {
            return "\(Int(value))"
        } else if value < 10000 {
            return sharedNumberFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        } else {
            return String(format: "%.0fK", value / 1000)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

func moonPhaseIcon(from phaseName: String) -> String {
    // Default icon if empty
    guard !phaseName.isEmpty else {
        return "moonphase.waxing.gibbous"
    }
    
    let phase = phaseName.lowercased()
    
    // Map phase names to SF Symbols
    // Note: Farmsense API has typo "Cresent" instead of "Crescent"
    let icon: String
    if phase.contains("new") {
        icon = "moonphase.new.moon"
    } else if phase.contains("waxing") && phase.contains("cres") {
        icon = "moonphase.waxing.crescent"
    } else if phase.contains("first quarter") {
        icon = "moonphase.first.quarter"
    } else if phase.contains("waxing") && phase.contains("gibbous") {
        icon = "moonphase.waxing.gibbous"
    } else if phase.contains("full") {
        icon = "moonphase.full.moon"
    } else if phase.contains("waning") && phase.contains("gibbous") {
        icon = "moonphase.waning.gibbous"
    } else if phase.contains("last quarter") || phase.contains("third quarter") {
        icon = "moonphase.last.quarter"
    } else if phase.contains("waning") && phase.contains("cres") {
        icon = "moonphase.waning.crescent"
    } else {
        // Fallback
        icon = "moonphase.waxing.gibbous"
    }
    
    return icon
}

@main
struct SundayWidgetBundle: WidgetBundle {
    init() {
    }
    
    var body: some Widget {
        SundayWidget()
        SunSessionLiveActivity()
    }
}

struct SundayWidget: Widget {
    let kind: String = "SundayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SundayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Fry Day")
        .description("UV forecasts and estimated sun exposure")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}


struct SunSessionLiveActivity: Widget {
    private let orange = Color.orange
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SunSessionAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Fry Day", systemImage: "sun.max.fill").font(.headline).foregroundStyle(.orange)
                    Spacer()
                    Text(context.attributes.startedAt, style: .timer).font(.title2.monospacedDigit())
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sun session running").font(.subheadline)
                        Text("Check in at \(context.state.reminderDate.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Link(destination: endURL(context.attributes)) {
                        Label("End", systemImage: "stop.fill").font(.headline).padding(.horizontal, 16).padding(.vertical, 10)
                            .background(.orange, in: Capsule()).foregroundStyle(.black)
                    }
                }
                if !context.isStale, let uv = context.state.uv {
                    Text("Open-Meteo forecast UV \(uv, specifier: "%.1f")").font(.caption).foregroundStyle(.secondary)
                }
            }.padding().activityBackgroundTint(Color(red: 0.09, green: 0.11, blue: 0.14))
                .activitySystemActionForegroundColor(.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("Fry Day", systemImage: "sun.max.fill").foregroundStyle(.orange) }
                DynamicIslandExpandedRegion(.trailing) { Text(context.attributes.startedAt, style: .timer).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Check in at \(context.state.reminderDate.formatted(date: .omitted, time: .shortened))").font(.caption)
                        Spacer()
                        Link("End session", destination: endURL(context.attributes)).foregroundStyle(.orange)
                    }
                }
            } compactLeading: {
                Image(systemName: "sun.max.fill").foregroundStyle(.orange)
            } compactTrailing: {
                Text(context.attributes.startedAt, style: .timer).monospacedDigit().frame(width: 48)
            } minimal: {
                Image(systemName: "sun.max.fill").foregroundStyle(.orange)
            }
            .widgetURL(URL(string: "fryday://session"))
            .keylineTint(.orange)
        }
    }
    private func endURL(_ attributes: SunSessionAttributes) -> URL {
        URL(string: "fryday://end?session=\(attributes.sessionID.uuidString)")!
    }
}
