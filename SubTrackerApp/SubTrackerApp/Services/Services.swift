import Foundation
import EventKit
import UserNotifications

class SystemIntegrations {
    static let shared = SystemIntegrations()
    let eventStore = EKEventStore()

    func requestPermissions(completion: (() -> Void)? = nil) {
        let group = DispatchGroup()

        group.enter()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in group.leave() }

        group.enter()
        if #available(iOS 17.0, macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { _, _ in group.leave() }
        } else {
            eventStore.requestAccess(to: .event) { _, _ in group.leave() }
        }

        group.notify(queue: .main) {
            completion?()
        }
    }

    func scheduleNotificationAndEventAfterPermissionGranted(for subscription: Subscription) {
        requestPermissions {
            self.scheduleNotificationAndEvent(for: subscription)
        }
    }

    func scheduleNotificationAndEvent(for subscription: Subscription) {
        let nextBillingDate = BillingLogic.calculateNextBillingDate(billingDay: subscription.billingDay)

        // Schedule Notification (1 day before)
        guard let notificationDate = Calendar.current.date(byAdding: .day, value: -1, to: nextBillingDate) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Payment Reminder"
        content.body = "Your subscription for \(subscription.name) is due tomorrow."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [subscription.id])
        let request = UNNotificationRequest(identifier: subscription.id, content: content, trigger: trigger)
        center.add(request)

        // Add to Calendar
        if EKEventStore.authorizationStatus(for: .event) == .authorized || EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            let event = EKEvent(eventStore: eventStore)
            event.title = "Pay \(subscription.name)"
            event.startDate = nextBillingDate
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: nextBillingDate)
            event.calendar = eventStore.defaultCalendarForNewEvents

            do {
                try eventStore.save(event, span: .thisEvent)
            } catch {
                print("Failed to save event: \(error)")
            }
        }
    }

    func cancelNotification(for subscriptionId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [subscriptionId])
    }
}

class BillingLogic {
    static func calculateNextBillingDate(billingDay: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()

        var components = calendar.dateComponents([.year, .month], from: today)
        components.day = billingDay

        // Handle short months (e.g. Feb 31 -> Feb 28)
        if let targetDate = calendar.date(from: components) {
            let actualComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)

            if actualComponents.month != components.month {
                // It overflowed to the next month, so get the last day of the current month
                components.day = 0
                components.month! += 1
                if let lastDayOfCurrentMonth = calendar.date(from: components) {
                    components = calendar.dateComponents([.year, .month, .day], from: lastDayOfCurrentMonth)
                }
            }
        }

        guard var targetDate = calendar.date(from: components) else { return today }

        if targetDate < today {
            // Next month
            components.month! += 1
            if let nextMonthDate = calendar.date(from: components) {
                let actualComponents = calendar.dateComponents([.year, .month, .day], from: nextMonthDate)
                if actualComponents.month != components.month {
                     var adjustedComponents = components
                     adjustedComponents.day = 0
                     adjustedComponents.month! += 1
                     targetDate = calendar.date(from: adjustedComponents) ?? today
                } else {
                     targetDate = nextMonthDate
                }
            }
        }

        return targetDate
    }
}
