import SwiftUI
import CoreLocation

struct ManualExposureSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vitaminDCalculator: VitaminDCalculator
    @EnvironmentObject var uvService: UVService
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var selectedClothing: ClothingLevel = .light
    @State private var selectedSunscreen: SunscreenLevel = .none
    @State private var showClothingPicker = false
    @State private var showSunscreenPicker = false
    @State private var isCalculating = false
    @State private var calculatedVitaminD: Double = 0
    @State private var errorMessage: String?
    @State private var uvDataPoints: [(time: Date, uv: Double)] = []
    
    private let calendar = Calendar.current
    
    // Time range limits - only allow today's past times
    private var timeRange: ClosedRange<Date> {
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        return startOfDay...now
    }
    
    private var formattedDuration: String {
        guard endTime > startTime else { return "--" }
        let minutes = Int(endTime.timeIntervalSince(startTime) / 60)
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining == 0 ? "\(hours) hr" : "\(hours) hr \(remaining) min"
    }

    private var formattedAmount: String {
        if calculatedVitaminD <= 0 { return "--" }
        if calculatedVitaminD < 1000 { return "\(Int(calculatedVitaminD)) IU" }
        if calculatedVitaminD < 100000 {
            let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
            return "\(f.string(from: NSNumber(value: calculatedVitaminD)) ?? "\(Int(calculatedVitaminD))") IU"
        }
        return String(format: "%.0fK IU", calculatedVitaminD / 1000)
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background to match SessionCompletionSheet
                LinearGradient(
                    colors: [Color(hex: "4a90e2"), Color(hex: "7bb7e5")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                    // Header icon
                    VStack(spacing: 20) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                            .symbolEffect(.pulse)
                            .padding(.top, 10)
                    }
                    
                    // Time selection
                    VStack(spacing: 16) {
                        // Start time
                        VStack(alignment: .leading, spacing: 8) {
                            Text("START TIME")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(1.2)
                            
                            DatePicker("", selection: $startTime, in: timeRange, displayedComponents: [.hourAndMinute])
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .onChange(of: startTime) { _, newValue in
                                    // Ensure end time is after start time
                                    if endTime <= newValue {
                                        endTime = min(newValue.addingTimeInterval(300), Date()) // Add 5 minutes
                                    }
                                    // Recalculate vitamin D
                                    calculateVitaminD()
                                }
                        }
                        
                        // End time
                        VStack(alignment: .leading, spacing: 8) {
                            Text("END TIME")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(1.2)
                            
                            DatePicker("", selection: $endTime, in: startTime...Date(), displayedComponents: [.hourAndMinute])
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .onChange(of: endTime) { _, _ in
                                    // Recalculate vitamin D
                                    calculateVitaminD()
                                }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(12)
                    
                    // Duration displayed in header above
                    
                    // Clothing and Sunscreen selection
                    HStack(spacing: 12) {
                        // Clothing button
                        Button(action: { showClothingPicker.toggle() }) {
                            VStack(spacing: 10) {
                                Text("CLOTHING")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .tracking(1.5)
                                
                                HStack {
                                    Text(selectedClothing.shortDescription)
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
                            ClothingPicker(selection: $selectedClothing)
                                .presentationDetents([.medium])
                                .presentationDragIndicator(.visible)
                        }
                        .onChange(of: selectedClothing) { _, _ in
                            calculateVitaminD()
                        }
                        
                        // Sunscreen button
                        Button(action: { showSunscreenPicker.toggle() }) {
                            VStack(spacing: 10) {
                                Text("SUNSCREEN")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .tracking(1.5)
                                
                                HStack {
                                    Text(selectedSunscreen.description)
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
                            SunscreenPicker(selection: $selectedSunscreen)
                                .presentationDetents([.medium])
                                .presentationDragIndicator(.visible)
                        }
                        .onChange(of: selectedSunscreen) { _, _ in
                            calculateVitaminD()
                        }
                    }
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Result display
                    if isCalculating {
                        ProgressView("Calculating...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .frame(maxWidth: .infinity)
                    } else if calculatedVitaminD > 0 {
                        VStack(spacing: 16) {
                            Text("UV DURING EXPOSURE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(1.2)
                            
                            // UV data points used
                            if !uvDataPoints.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(uvDataPoints, id: \.time) { point in
                                        HStack {
                                            Text(point.time, style: .time)
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.8))
                                            Spacer()
                                            Text("UV: \(String(format: "%.1f", point.uv))")
                                                .font(.caption2)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(12)

                        // Summary + Save card
                        VStack(spacing: 12) {
                            // Summary just above the Save button (no surrounding box)
                            VStack(spacing: 6) {
                                Text("VITAMIN D ESTIMATE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .tracking(1.2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .allowsTightening(true)
                                Text(formattedAmount)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .allowsTightening(true)
                            }
                            .frame(maxWidth: .infinity)

                            // Save button
                            Button(action: saveSession) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                    Text("Save Session")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(15)
                            }
                            .disabled(isCalculating || calculatedVitaminD <= 0)
                        }
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(12)
                    }
                    // Close button
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
            }
            .navigationTitle("Log Past Exposure")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
        .onAppear {
            // Set default times - 1 hour ago to now
            let now = Date()
            selectedClothing = vitaminDCalculator.settings.clothing
            selectedSunscreen = vitaminDCalculator.settings.sunscreen
            startTime = max(calendar.startOfDay(for: now), now.addingTimeInterval(-3600)) // 1 hour ago
            endTime = now
            
            // Calculate initial vitamin D
            calculateVitaminD()
        }
    }
    
    private var entrySettings: ExposureSettings {
        var value = vitaminDCalculator.settings
        value.clothing = selectedClothing
        value.sunscreen = selectedSunscreen
        return value
    }
    private func calculateVitaminD() {
        isCalculating = false
        let session = ExposureSession(start: startTime, end: endTime, reminderDate: endTime,
            segments: [ExposureSegment(start: startTime, settings: entrySettings, forecast: uvService.samples)])
        let totals = session.totals(until: endTime)
        guard startTime < endTime, totals.coveredSeconds >= endTime.timeIntervalSince(startTime) - 1 else {
            calculatedVitaminD = 0
            errorMessage = "Choose an interval covered by the available UV forecast. Missing weather data is not estimated."
            uvDataPoints = []
            return
        }
        errorMessage = nil
        calculatedVitaminD = totals.iu
        uvDataPoints = uvService.samples.filter { $0.date >= startTime && $0.date <= endTime }.map { (time: $0.date, uv: $0.uv) }
    }
    private func saveSession() {
        if vitaminDCalculator.addManualSession(start: startTime, end: endTime, settings: entrySettings, forecast: uvService.samples) {
            dismiss()
        } else { errorMessage = vitaminDCalculator.errorMessage }
    }
}
