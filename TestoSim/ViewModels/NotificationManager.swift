import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    enum LeadTime: String, CaseIterable, Identifiable {
        case oneHour = "1 hour"
        case sixHours = "6 hours"
        case twelveHours = "12 hours"
        
        var id: String { self.rawValue }
        
        var timeInterval: TimeInterval {
            switch self {
            case .oneHour: return 3600
            case .sixHours: return 21600
            case .twelveHours: return 43200
            }
        }
    }
    
    enum AdherenceStatus: String, Codable {
        case onTime, late, missed
    }
    
    struct InjectionRecord: Codable, Identifiable {
        let id: UUID
        let protocolID: UUID
        let scheduledDate: Date
        let acknowledgedDate: Date?
        let status: AdherenceStatus
        let doseMg: Double
        let compoundOrBlendName: String
        
        var isAcknowledged: Bool {
            return acknowledgedDate != nil
        }
    }
    
    // User preferences
    var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notificationsEnabled") }
    }
    
    var soundEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationSoundEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notificationSoundEnabled") }
    }
    
    var selectedLeadTime: LeadTime {
        get {
            if let storedValue = UserDefaults.standard.string(forKey: "notificationLeadTime"),
               let leadTime = LeadTime(rawValue: storedValue) {
                return leadTime
            }
            return .oneHour
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "notificationLeadTime")
        }
    }
    
    // Adherence tracking
    private var injectionRecords: [InjectionRecord] = []
    
    override init() {
        super.init()
        
        // Set delegate for handling notifications when app is in foreground
        UNUserNotificationCenter.current().delegate = self
        
        // Load adherence records
        loadInjectionRecords()
    }
    
    // MARK: - Notification Permissions
    
    func requestNotificationPermission() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            return try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    // MARK: - Scheduling Notifications
    
    func scheduleNotifications(for protocol: InjectionProtocol, using compoundLibrary: CompoundLibrary) {
        guard notificationsEnabled else { return }
        
        // Cancel existing notifications for this protocol
        cancelNotifications(for: `protocol`.id)
        
        // Calculate next injection dates from today onwards
        let today = Date()
        let simulationEndDate = today.addingTimeInterval(365 * 24 * 3600) // Schedule for up to a year
        let injectionDates = `protocol`.injectionDates(from: today, upto: simulationEndDate)
        
        // Get compound or blend name for the notification
        let itemName: String
        if let compoundID = `protocol`.compoundID, 
           let compound = compoundLibrary.compound(withID: compoundID) {
            itemName = compound.commonName
        } else if let blendID = `protocol`.blendID,
                  let blend = compoundLibrary.blend(withID: blendID) {
            itemName = blend.name
        } else {
            itemName = "medication"
        }
        
        // Schedule notifications for each upcoming injection
        for injectionDate in injectionDates {
            // Calculate notification time based on lead time preference
            let notificationDate = injectionDate.addingTimeInterval(-selectedLeadTime.timeInterval)
            
            // Only schedule if the notification date is in the future
            if notificationDate > today {
                scheduleInjectionNotification(
                    for: `protocol`.id,
                    protocolName: `protocol`.name,
                    compoundName: itemName,
                    doseMg: `protocol`.doseMg,
                    injectionDate: injectionDate,
                    notificationDate: notificationDate
                )
                
                // Also track this upcoming injection in our records
                let newRecord = InjectionRecord(
                    id: UUID(),
                    protocolID: `protocol`.id,
                    scheduledDate: injectionDate,
                    acknowledgedDate: nil,
                    status: .onTime, // Default status will be updated later
                    doseMg: `protocol`.doseMg,
                    compoundOrBlendName: itemName
                )
                
                // Only add if we don't already have a record for this date
                if !injectionRecords.contains(where: { 
                    $0.protocolID == newRecord.protocolID && 
                    Calendar.current.isDate($0.scheduledDate, inSameDayAs: newRecord.scheduledDate)
                }) {
                    injectionRecords.append(newRecord)
                }
            }
        }
        
        // Save the updated records
        saveInjectionRecords()
    }
    
    private func scheduleInjectionNotification(for protocolID: UUID, protocolName: String, compoundName: String, doseMg: Double, injectionDate: Date, notificationDate: Date) {
        // Create a unique identifier for this notification
        let identifier = "injection-\(protocolID.uuidString)-\(injectionDate.timeIntervalSince1970)"
        
        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = "Injection Reminder"
        content.body = "Time for your \(doseMg)mg \(compoundName) injection (\(protocolName))"
        content.sound = soundEnabled ? UNNotificationSound.default : nil
        content.userInfo = [
            "protocolID": protocolID.uuidString,
            "injectionDate": injectionDate.timeIntervalSince1970,
            "type": "injection-reminder"
        ]
        
        // Create date components for a precise date
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: notificationDate
        )
        
        // Create the trigger
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // Create the request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Add it to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    func cancelNotifications(for protocolID: UUID) {
        // Get all pending notification requests
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            // Find all requests for this protocol
            let identifiers = requests
                .filter { $0.content.userInfo["protocolID"] as? String == protocolID.uuidString }
                .map { $0.identifier }
            
            // Remove these notifications
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Notification Delegate Methods
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Display notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle the user's response to the notification
        let userInfo = response.notification.request.content.userInfo
        
        if userInfo["type"] as? String == "injection-reminder",
           let protocolIDString = userInfo["protocolID"] as? String,
           let protocolID = UUID(uuidString: protocolIDString),
           let injectionTimeInterval = userInfo["injectionDate"] as? TimeInterval {
            
            let injectionDate = Date(timeIntervalSince1970: injectionTimeInterval)
            acknowledgeInjection(protocolID: protocolID, injectionDate: injectionDate)
        }
        
        completionHandler()
    }
    
    // MARK: - Adherence Tracking
    
    func acknowledgeInjection(protocolID: UUID, injectionDate: Date) {
        let now = Date()
        
        // Find the record for this injection
        if let index = injectionRecords.firstIndex(where: { 
            $0.protocolID == protocolID && 
            Calendar.current.isDate($0.scheduledDate, inSameDayAs: injectionDate)
        }) {
            // Update the record
            let record = injectionRecords[index]
            
            // Determine adherence status
            let hoursBetween = injectionDate.distance(to: now) / 3600
            
            var status: AdherenceStatus
            if hoursBetween < 24 {
                status = .onTime
            } else if hoursBetween < 48 {
                status = .late
            } else {
                status = .missed
            }
            
            // Create new record with updated status
            let updatedRecord = InjectionRecord(
                id: record.id,
                protocolID: record.protocolID,
                scheduledDate: record.scheduledDate,
                acknowledgedDate: now,
                status: status,
                doseMg: record.doseMg,
                compoundOrBlendName: record.compoundOrBlendName
            )
            
            // Update the record
            injectionRecords[index] = updatedRecord
            saveInjectionRecords()
        }
    }
    
    // MARK: - Analytics
    
    func adherenceStats() -> (total: Int, onTime: Int, late: Int, missed: Int) {
        let acknowledged = injectionRecords.filter { $0.isAcknowledged }
        
        let onTime = acknowledged.filter { $0.status == .onTime }.count
        let late = acknowledged.filter { $0.status == .late }.count
        let missed = acknowledged.filter { $0.status == .missed }.count
        
        return (total: acknowledged.count, onTime: onTime, late: late, missed: missed)
    }
    
    func adherencePercentage() -> Double {
        let stats = adherenceStats()
        guard stats.total > 0 else { return 0 }
        
        return Double(stats.onTime) / Double(stats.total) * 100.0
    }
    
    // MARK: - Persistence
    
    private func saveInjectionRecords() {
        if let encodedData = try? JSONEncoder().encode(injectionRecords) {
            UserDefaults.standard.set(encodedData, forKey: "injectionRecords")
        }
    }
    
    private func loadInjectionRecords() {
        if let savedData = UserDefaults.standard.data(forKey: "injectionRecords"),
           let decodedRecords = try? JSONDecoder().decode([InjectionRecord].self, from: savedData) {
            self.injectionRecords = decodedRecords
        }
    }
    
    func injectionHistory(for protocolID: UUID? = nil) -> [InjectionRecord] {
        if let protocolID = protocolID {
            return injectionRecords.filter { $0.protocolID == protocolID }
        } else {
            return injectionRecords
        }
    }
    
    // Cleanup old records older than 6 months
    func cleanupOldRecords() {
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        injectionRecords = injectionRecords.filter { $0.scheduledDate > sixMonthsAgo }
        saveInjectionRecords()
    }
} 