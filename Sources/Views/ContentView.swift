import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var uvService: UVService
    @EnvironmentObject var vitaminDCalculator: VitaminDCalculator
    @StateObject private var networkMonitor = NetworkMonitor()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showClothingPicker = false
    @State private var showSunscreenPicker = false
    @State private var showSkinTypePicker = false
    @State private var showInfoSheet = false
    @State private var showManualExposureSheet = false
    private let timer = Timer.publish(every: 60, tolerance: 5, on: .main, in: .common).autoconnect()
    private var displayedUV: Double { uvService.currentUV ?? 0 }

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    uvSection
                    vitaminDSection
                    exposureToggle
                    HStack(spacing: 12) { clothingSection; sunscreenSection }
                    skinTypeSection
                    reminderRow
                    if let status = vitaminDCalculator.reminderStatus ?? vitaminDCalculator.liveActivityStatus {
                        Text(status).font(.caption).foregroundColor(.white.opacity(0.8)).multilineTextAlignment(.center)
                    }
                    if vitaminDCalculator.hasIncompleteCoverage {
                        Text("Missing UV intervals are excluded from this estimate.").font(.caption).foregroundColor(.white.opacity(0.8))
                    }
                    if let updated = uvService.lastSuccessfulUpdate {
                        Text("\(uvService.isOfflineMode ? "Cached forecast" : "Forecast") · \(updated.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2).foregroundColor(.white.opacity(0.7))
                    }
                    if let error = uvService.lastError {
                        Button("Refresh UV data") { refreshWeather(force: true) }.font(.caption).tint(.white).accessibilityHint(error)
                    }
                    Link("Weather by Open-Meteo · CC BY 4.0", destination: URL(string: "https://open-meteo.com/")!)
                        .font(.caption2).foregroundColor(.white.opacity(0.7))
                }.padding(.horizontal, 20).padding(.vertical, 20)
            }
        }
        .sheet(isPresented: $showInfoSheet) { InfoSheet() }
        .sheet(isPresented: $showManualExposureSheet) { ManualExposureSheet() }
        .sheet(isPresented: Binding(get: { vitaminDCalculator.active?.end != nil }, set: { _ in })) {
            if let session = vitaminDCalculator.active { SessionCompletionSheet(session: session) }
        }
        .alert("Couldn’t complete that action", isPresented: Binding(get: { vitaminDCalculator.errorMessage != nil }, set: { if !$0 { vitaminDCalculator.errorMessage = nil } })) {
            Button("OK") { vitaminDCalculator.errorMessage = nil }
            Button("Reload saved sessions") { vitaminDCalculator.reload() }
        } message: { Text(vitaminDCalculator.errorMessage ?? "") }
        .task { locationManager.requestPermission(); refreshWeather() }
        .onChange(of: locationManager.location) { _, _ in refreshWeather() }
        .onChange(of: uvService.snapshot?.updatedAt) { _, _ in
            vitaminDCalculator.updateForecast(uvService.samples, updatedAt: uvService.lastSuccessfulUpdate)
        }
        .onChange(of: networkMonitor.isConnected) { _, connected in
            if connected {
                uvService.networkBecameAvailable()
                if scenePhase == .active { refreshWeather() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { locationManager.requestPermission(); refreshWeather() }
            else { locationManager.stopUpdatingLocation() }
        }
        .onReceive(timer) { _ in
            if scenePhase == .active { refreshWeather() }
        }
        .onOpenURL { url in
            guard url.scheme == "fryday", url.host == "end",
                  let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "session" })?.value,
                  let id = UUID(uuidString: value) else { return }
            vitaminDCalculator.prepareCompletion(sessionID: id)
        }
    }

    private func profileBinding<T>(_ key: WritableKeyPath<ExposureSettings, T>) -> Binding<T> {
        Binding(get: { vitaminDCalculator.settings[keyPath: key] }, set: {
            var settings = vitaminDCalculator.settings; settings[keyPath: key] = $0; vitaminDCalculator.updateSettings(settings)
        })
    }
    private func refreshWeather(force: Bool = false) {
        if let location = locationManager.location { uvService.fetchUVData(for: location, force: force, isTracking: vitaminDCalculator.isInSun) }
    }
    private var reminderRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "bell")
            if let session = vitaminDCalculator.active {
                Text(session.reminderDate > vitaminDCalculator.now ? "Check in at \(session.reminderDate.formatted(date: .omitted, time: .shortened))" : "Time to check in. Still outdoors?")
            } else {
                Menu {
                    Picker("Remind me after", selection: $vitaminDCalculator.reminderMinutes) {
                        ForEach([10, 20, 30, 60], id: \.self) { Text("\($0) minutes").tag($0) }
                    }
                } label: { Text("Remind me after \(vitaminDCalculator.reminderMinutes) min"); Image(systemName: "chevron.down") }
            }
        }.font(.caption).foregroundColor(.white.opacity(0.8))
    }
    private var exposureToggle: some View {
        HStack(spacing: 12) {
            Button {
                if vitaminDCalculator.isInSun { vitaminDCalculator.prepareCompletion() }
                else { vitaminDCalculator.startSession() }
            } label: {
                HStack {
                    Image(systemName: vitaminDCalculator.isInSun ? "sun.max.fill" : displayedUV == 0 ? moonPhaseIcon() : "sun.max")
                        .font(.system(size: 24)).symbolEffect(.pulse, isActive: vitaminDCalculator.isInSun)
                    Text(vitaminDCalculator.isInSun ? "End" : displayedUV == 0 ? "No UV available" : "Begin")
                        .font(.system(size: 18, weight: .semibold))
                }.foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 20)
                    .background(vitaminDCalculator.isInSun ? Color.yellow.opacity(0.3) : Color.black.opacity(0.2)).cornerRadius(15)
            }
            .disabled(displayedUV == 0 && !vitaminDCalculator.isInSun)
            .opacity(displayedUV == 0 && !vitaminDCalculator.isInSun ? 0.6 : 1)
            Button { showManualExposureSheet = true } label: {
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 24)).foregroundColor(.white)
                    .frame(width: 60).padding(.vertical, 20).background(Color.black.opacity(0.2)).cornerRadius(15)
            }.accessibilityLabel("Log past exposure").disabled(vitaminDCalculator.active != nil).opacity(vitaminDCalculator.active != nil ? 0.4 : 1)
        }
    }
    private func formatTime(_ date: Date?) -> String {
        date?.formatted(date: .omitted, time: .shortened) ?? "--:--"
    }
    private func moonPhaseIcon() -> String { uvService.moonPhaseIcon }
    private var gradientColors: [Color] {
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        let timeProgress = Double(hour) + Double(minute) / 60.0
        
        if timeProgress < 5 || timeProgress > 22 {
            // Night (deep dark blue)
            return [Color(hex: "0f1c3d"), Color(hex: "0a1228")]
        } else if timeProgress < 6 {
            // Pre-dawn (dark blue transitioning)
            return [Color(hex: "1e3a5f"), Color(hex: "2d4a7c")]
        } else if timeProgress < 6.5 {
            // Early dawn (blue to purple)
            return [Color(hex: "3d5a80"), Color(hex: "5c7cae")]
        } else if timeProgress < 7 {
            // Dawn (purple to pink)
            return [Color(hex: "5c7cae"), Color(hex: "ee9b7a")]
        } else if timeProgress < 8 {
            // Sunrise (pink to light blue)
            return [Color(hex: "f4a261"), Color(hex: "87ceeb")]
        } else if timeProgress < 10 {
            // Morning (clear blue sky)
            return [Color(hex: "5ca9d6"), Color(hex: "87ceeb")]
        } else if timeProgress < 16 {
            // Midday (bright blue sky)
            return [Color(hex: "4a90e2"), Color(hex: "7bb7e5")]
        } else if timeProgress < 17 {
            // Late afternoon (slightly warmer blue)
            return [Color(hex: "5ca9d6"), Color(hex: "87b8d4")]
        } else if timeProgress < 18.5 {
            // Golden hour (warm golden)
            return [Color(hex: "f4a261"), Color(hex: "e76f51")]
        } else if timeProgress < 19.5 {
            // Sunset (orange to pink)
            return [Color(hex: "e76f51"), Color(hex: "c44569")]
        } else if timeProgress < 20.5 {
            // Late sunset (pink to purple)
            return [Color(hex: "c44569"), Color(hex: "6a4c93")]
        } else {
            // Dusk (purple to dark blue)
            return [Color(hex: "6a4c93"), Color(hex: "1e3a5f")]
        }
    }
    
    private var headerSection: some View {
        Button(action: { showInfoSheet = true }) {
            Text("FRY DAY")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .tracking(2)
        }
    }
    
    private var uvSection: some View {
        VStack(spacing: 8) {
            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                VStack(spacing: 10) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.7))
                    Text("LOCATION ACCESS REQUIRED")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1.5)
                    Button(action: {
                        locationManager.openSettings()
                    }) {
                        Text("Enable Location")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(20)
                    }
                }
            } else {
                Text("UV INDEX")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(1.5)
                
                Text(uvService.currentUV.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 15) {
                VStack(spacing: 3) {
                    Text("CHECK-IN")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(vitaminDCalculator.reminderMinutes) min")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(" ")
                        .font(.system(size: 8, weight: .medium))
                        .opacity(0)
                }
                
                VStack(spacing: 3) {
                    Text(uvService.shouldShowTomorrowTimes ? "MAX TMRW" : "MAX UVI")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text(String(format: "%.1f", uvService.displayMaxUV))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(" ")
                        .font(.system(size: 8, weight: .medium))
                        .opacity(0)
                }
                
                VStack(spacing: 3) {
                    Text("SUNRISE")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text(formatTime(uvService.displaySunrise))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    if uvService.shouldShowTomorrowTimes {
                        Text("TOMORROW")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        Text(" ")
                            .font(.system(size: 8, weight: .medium))
                            .opacity(0)
                    }
                }
                
                VStack(spacing: 3) {
                    Text("SUNSET")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text(formatTime(uvService.displaySunset))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    if uvService.shouldShowTomorrowTimes {
                        Text("TOMORROW")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        Text(" ")
                            .font(.system(size: 8, weight: .medium))
                            .opacity(0)
                    }
                }
            }
            
            // Show cloud/altitude/location info
            VStack(spacing: 2) {
                HStack(spacing: 15) {
                    HStack(spacing: 5) {
                        Image(systemName: displayedUV == 0 ?
                                         (uvService.currentCloudCover < 70 ? moonPhaseIcon() : "cloud.fill") :
                                         uvService.currentCloudCover == 0 ? "sun.max" : 
                                         uvService.currentCloudCover > 50 ? "cloud.fill" : "cloud")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(Int(uvService.currentCloudCover))% clouds")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    if uvService.currentAltitude > 100 {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.to.line")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                            Text("\(Int(uvService.currentAltitude))m")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))

                        }
                    }
                }
                
                // Location name
                if !locationManager.locationName.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        Text(locationManager.locationName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.top, 3)
            
            
            // Vitamin D winter warning
            if uvService.isVitaminDWinter {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Seasonal UV")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.yellow)
                        Text("Seasonal UV estimates can be less reliable.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(10)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.2))
        .cornerRadius(20)
    }
    
    private var clothingSection: some View {
        Button(action: { showClothingPicker.toggle() }) {
            VStack(spacing: 10) {
                Text("CLOTHING")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(1.5)
                
                HStack {
                    Text(vitaminDCalculator.settings.clothing.shortDescription)
                        .font(.system(size: 16, weight: .medium))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.black.opacity(0.2))
            .cornerRadius(15)
        }
        .sheet(isPresented: $showClothingPicker) {
            ClothingPicker(selection: profileBinding(\.clothing))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var sunscreenSection: some View {
        Button(action: { showSunscreenPicker.toggle() }) {
            VStack(spacing: 10) {
                Text("SUNSCREEN")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(1.5)
                
                HStack {
                    Text(vitaminDCalculator.settings.sunscreen.description)
                        .font(.system(size: 16, weight: .medium))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.black.opacity(0.2))
            .cornerRadius(15)
        }
        .sheet(isPresented: $showSunscreenPicker) {
            SunscreenPicker(selection: profileBinding(\.sunscreen))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var skinTypeSection: some View {
        Button(action: { showSkinTypePicker.toggle() }) {
            VStack(spacing: 10) {
                Text("SKIN TYPE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(1.5)
                
                HStack {
                    Text(vitaminDCalculator.settings.skin.description)
                        .font(.system(size: 16, weight: .medium))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.black.opacity(0.2))
            .cornerRadius(15)
        }
        .sheet(isPresented: $showSkinTypePicker) {
            SkinTypePicker(selection: profileBinding(\.skin))
        }
    }

    private var vitaminDSection: some View {
        VStack(spacing: 15) {
            HStack(alignment: .top, spacing: 15) {
                VStack(spacing: 8) {
                    ZStack {
                        Text("POTENTIAL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1.2)
                            .opacity(vitaminDCalculator.isInSun ? 0 : 1)
                        
                        Text("RATE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1.2)
                            .opacity(vitaminDCalculator.isInSun ? 1 : 0)
                    }
                    .frame(height: 12)
                    
                    Text(formatVitaminDNumber(vitaminDCalculator.currentVitaminDRate / 60.0))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .frame(minWidth: 80)
                        .frame(height: 34)
                    
                    Text("IU/min")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(height: 16)
                }
                .frame(minWidth: 100)
                
                VStack(spacing: 8) {
                    Text("SESSION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1.2)
                        .frame(height: 12)
                    
                    HStack(spacing: 4) {
                        Text(formatVitaminDNumber(vitaminDCalculator.sessionVitaminD))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .frame(minWidth: 80, alignment: .trailing)
                        
                        Text("IU")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 20, alignment: .leading)
                    }
                    .frame(height: 34)
                    
                    ZStack {
                        Text("Not tracking")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                            .opacity(vitaminDCalculator.isInSun ? 0 : 1)
                        
                        if vitaminDCalculator.isInSun, let startTime = vitaminDCalculator.sessionStartTime {
                            Text(sessionDurationString(from: startTime))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .frame(height: 16)
                }
                .frame(minWidth: 100)
                
                VStack(spacing: 8) {
                    Text("TODAY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(1.2)
                        .frame(height: 12)
                    
                    Text(formatTodaysTotal(vitaminDCalculator.todayTotal))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .frame(minWidth: 80)
                        .frame(height: 34)
                    
                    Text("IU estimated")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(height: 16)
                }
                .frame(minWidth: 100)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.2))
        .cornerRadius(20)
    }
    
    private func formatVitaminDNumber(_ value: Double) -> String {
        if value < 1 {
            return String(format: "%.2f", value)
        } else if value < 10 {
            return String(format: "%.1f", value)
        } else if value < 1000 {
            return "\(Int(value))"
        } else if value < 100000 {
            // Add comma formatting for readability (shared formatter)
            return Formatters.decimal.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        } else {
            // Handle very large numbers with K notation
            return String(format: "%.0fK", value / 1000)
        }
    }
    
    private func formatTodaysTotal(_ value: Double) -> String {
        if value < 1000 {
            return "\(Int(value))"
        } else if value < 100000 {
            // Add comma formatting for readability (shared formatter)
            return Formatters.decimal.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        } else {
            return String(format: "%.0fK", value / 1000)
        }
    }

    private enum Formatters {
        static let decimal: NumberFormatter = {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 0
            return f
        }()
    }
    
    private func sessionDurationString(from startTime: Date) -> String {
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration / 60)
        
        if minutes == 0 {
            return "< 1 min"
        } else if minutes == 1 {
            return "1 min"
        } else {
            return "\(minutes) mins"
        }
    }
    
}

struct ClothingPicker: View {
    @Binding var selection: ClothingLevel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            List {
                ForEach(ClothingLevel.allCases, id: \.self) { level in
                    Button(action: {
                        selection = level
                        dismiss()
                    }) {
                        HStack {
                            Text(level.description)
                                .foregroundColor(.primary)
                            Spacer()
                            if selection == level {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Clothing Level")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .preferredColorScheme(.dark)
        }
        .presentationBackground(Color(UIColor.systemBackground).opacity(0.99))
    }
}

struct SkinTypePicker: View {
    @Binding var selection: SkinType
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var vitaminDCalculator: VitaminDCalculator
    
    var body: some View {
        NavigationView {
            List {
                ForEach(SkinType.allCases, id: \.self) { type in
                    Button(action: {
                        selection = type
                        dismiss()
                    }) {
                        HStack {
                            Circle()
                                .fill(skinColor(for: type))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Type \(type.rawValue)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(type.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(skinTypeDetail(for: type))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                            
                            Spacer()
                            
                            if selection == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Fitzpatrick Skin Type")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .preferredColorScheme(.dark)

        }
        .presentationBackground(Color(UIColor.systemBackground).opacity(0.99))
    }
    
    private func skinTypeDetail(for type: SkinType) -> String {
        switch type {
        case .type1: return "Always burns, never tans"
        case .type2: return "Usually burns, tans minimally"
        case .type3: return "Sometimes burns, tans uniformly"
        case .type4: return "Burns minimally, tans well"
        case .type5: return "Rarely burns, tans profusely"
        case .type6: return "Deeply pigmented; can still burn"
        }
    }
    
    private func skinColor(for type: SkinType) -> Color {
        switch type {
        case .type1: return Color(red: 1.0, green: 0.92, blue: 0.84)      // Very fair
        case .type2: return Color(red: 0.98, green: 0.87, blue: 0.73)     // Fair
        case .type3: return Color(red: 0.94, green: 0.78, blue: 0.63)     // Light brown
        case .type4: return Color(red: 0.82, green: 0.63, blue: 0.48)     // Moderate brown
        case .type5: return Color(red: 0.63, green: 0.47, blue: 0.36)     // Dark brown
        case .type6: return Color(red: 0.4, green: 0.26, blue: 0.18)      // Very dark brown
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
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
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


struct InfoSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var sessions: VitaminDCalculator
    @EnvironmentObject private var health: HealthManager
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("About").font(.headline)
                        Text("Fry Day estimates vitamin D from UV forecasts, clothing, sunscreen, skin type, and optional age. The inherited model has not been clinically validated.").font(.caption).foregroundColor(.secondary)
                        Text("Estimates are not measurements or safe-exposure limits. Check with a clinician before making medical decisions. Reminders are check-ins, not burn predictions.").font(.caption).foregroundColor(.secondary)
                        Link("View detailed methodology", destination: URL(string: "https://github.com/khouryg/fry-day/blob/main/METHODOLOGY.md")!).font(.caption)
                    }
                    NavigationLink("Saved sessions") { SessionHistoryView() }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Optional Health profile").font(.headline)
                        Text("Sessions save on this device. No vitamin D estimates are written to Health.").font(.caption).foregroundColor(.secondary)
                        Button("Use available age and skin type") {
                            health.loadProfile { age, skin in
                                var settings = sessions.settings
                                if let age { settings.age = age }
                                if let skin { settings.skin = skin }
                                sessions.updateSettings(settings)
                            }
                        }.font(.caption)
                        if let age = sessions.settings.age {
                            Text("Age used: \(age)").font(.caption)
                            Button("Clear imported age") { var settings = sessions.settings; settings.age = nil; sessions.updateSettings(settings) }.font(.caption)
                        }
                        if let error = health.lastError { Text(error).font(.caption).foregroundColor(.secondary) }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data Sources & Privacy").font(.headline)
                        Link("UV data from Open-Meteo", destination: URL(string: "https://open-meteo.com/")!).font(.caption)
                        Link("Weather license: CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!).font(.caption)
                        Text("Hourly forecast values are interpolated for exposure estimates. Moon icons use an approximate on-device lunar cycle.").font(.caption).foregroundColor(.secondary)
                        Link("Privacy policy", destination: URL(string: "https://github.com/khouryg/fry-day/blob/main/PRIVACY.md")!).font(.caption)
                        Link("Support and source code", destination: URL(string: "https://github.com/khouryg/fry-day")!).font(.caption)
                        Text("An independent continuation of Sun Day by jackjackbits and contributors, released under the Unlicense.").font(.caption).foregroundColor(.secondary)
                        Link("Original project", destination: URL(string: "https://github.com/jackjackbits/sunday")!).font(.caption)
                    }
                }.padding()
            }.navigationTitle("How It Works").navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Done") { dismiss() }).preferredColorScheme(.dark)
        }.presentationBackground(Color(UIColor.systemBackground).opacity(0.99))
    }
}

struct SessionHistoryView: View {
    @EnvironmentObject private var sessions: VitaminDCalculator
    @State private var deleteID: UUID?
    var body: some View {
        List {
            if sessions.completed.isEmpty { ContentUnavailableView("No saved sessions", systemImage: "sun.horizon", description: Text("Completed sessions will appear here.")) }
            ForEach(sessions.completed) { session in
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.start.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                    let end = session.end ?? session.start
                    Text("\(Int(end.timeIntervalSince(session.start) / 60)) min · \(session.totals(until: end).iu, specifier: "%.0f") IU estimated").foregroundStyle(.secondary)
                }.swipeActions {
                    Button("Delete", role: .destructive) { deleteID = session.id }
                }
            }
        }.navigationTitle("Session history")
            .confirmationDialog("Delete this saved session?", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) {
                Button("Delete session", role: .destructive) { if let id = deleteID { sessions.deleteSession(id: id) }; deleteID = nil }
            }
    }
}
