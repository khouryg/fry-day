import SwiftUI

struct SessionCompletionSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vitaminDCalculator: VitaminDCalculator
    let session: ExposureSession
    private var sessionStartTime: Date { session.start }
    private var sessionAmount: Double { session.totals(until: selectedEndTime).iu }
    @State private var selectedEndTime: Date
    init(session: ExposureSession) {
        self.session = session
        _selectedEndTime = State(initialValue: session.end ?? Date())
    }

    private var sessionDuration: TimeInterval {
        selectedEndTime.timeIntervalSince(sessionStartTime)
    }
    
    private var formattedDuration: String {
        let minutes = Int(sessionDuration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(remainingMinutes) min"
            }
        }
    }
    
    private var formattedAmount: String {
        if sessionAmount < 1000 {
            return "\(Int(sessionAmount)) IU"
        } else if sessionAmount < 100000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return "\(formatter.string(from: NSNumber(value: sessionAmount)) ?? "\(Int(sessionAmount))") IU"
        } else {
            return String(format: "%.0fK IU", sessionAmount / 1000)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background matching app style (same as ManualExposureSheet)
                LinearGradient(
                    colors: [Color(hex: "4a90e2"), Color(hex: "7bb7e5")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Content
                VStack(spacing: 0) {
                    // Session summary
                    VStack(spacing: 20) {
                    // Sun icon with animation
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                        .symbolEffect(.pulse)
                        .padding(.top, 10)
                    
                    // Session stats
                    VStack(spacing: 16) {
                        // Vitamin D amount
                        VStack(spacing: 4) {
                            Text("VITAMIN D ESTIMATE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .tracking(1.2)
                            Text(formattedAmount)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        // Duration
                        VStack(spacing: 4) {
                            Text("SESSION DURATION")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .tracking(1.2)
                            Text(formattedDuration)
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Time adjustment section
                    VStack(spacing: 16) {
                        // Start time (non-editable)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("START TIME")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(1.2)
                            Text(formatTime(sessionStartTime))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(12)
                        
                        // End time picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("END TIME")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(1.2)
                            
                            DatePicker("", selection: $selectedEndTime, 
                                      in: sessionStartTime...(session.end ?? Date()),
                                      displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(height: 100)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                
                Spacer()
                
                if let error = vitaminDCalculator.errorMessage {
                    Text(error).font(.caption).foregroundColor(.white).padding(.horizontal)
                }
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        saveSession()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text("Save Session")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(15)
                    }
                    
                    Button(action: {
                        vitaminDCalculator.continueSession()
                    }) {
                        Text("Continue Tracking")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    
                    Button(action: {
                        // End session without saving
                        endWithoutSaving()
                    }) {
                        Text("End and Don't Save")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                }
            }
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
        .interactiveDismissDisabled()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // Keep the sheet background clear to match ManualExposureSheet, avoiding white flash
        .presentationBackground(.clear)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveSession() {
        _ = vitaminDCalculator.saveSession(end: selectedEndTime)
    }
    private func endWithoutSaving() {
        _ = vitaminDCalculator.discardSession()
    }
}
