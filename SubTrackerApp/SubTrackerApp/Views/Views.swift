import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var subscriptions: [Subscription]
    @Query private var ratesCache: [ExchangeRatesCache]

    @State private var showingAddSubscription = false

    var body: some View {
        NavigationStack {
            VStack {
                summarySection

                List {
                    ForEach(subscriptions) { sub in
                        NavigationLink(destination: EditSubscriptionView(subscription: sub)) {
                            SubscriptionRow(subscription: sub, rates: currentRates)
                        }
                    }
                    .onDelete(perform: deleteSubscriptions)
                }
            }
            .navigationTitle("SubTracker")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSubscription = true }) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSubscription) {
                AddSubscriptionView()
            }
            .task {
                await syncData()
            }
            .onAppear {
                SystemIntegrations.shared.requestPermissions()
            }
        }
    }

    private var currentRates: ExchangeRatesCache {
        ratesCache.first ?? ExchangeRatesCache()
    }

    private var summarySection: some View {
        let totalMonthly = subscriptions.reduce(0.0) { $0 + convertToPEN(amount: $1.cost, currency: $1.currency) }
        let totalYearly = totalMonthly * 12

        return VStack {
            Text("Total Monthly (PEN)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(String(format: "S/ %.2f", totalMonthly))
                .font(.largeTitle)
                .bold()

            Text("Total Yearly: S/ \(String(format: "%.2f", totalYearly))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private func convertToPEN(amount: Double, currency: String) -> Double {
        let rates = currentRates
        switch currency {
        case "USD": return amount * rates.usdPen
        case "ARS": return amount * rates.arsPen
        default: return amount // "PEN"
        }
    }

    private func deleteSubscriptions(offsets: IndexSet) {
        for index in offsets {
            let sub = subscriptions[index]
            modelContext.delete(sub)
            SystemIntegrations.shared.cancelNotification(for: sub.id)

            Task {
                try? await ApiClient.shared.deleteSubscription(id: sub.id)
            }
        }
    }

    private func syncData() async {
        do {
            let rates = try await ApiClient.shared.fetchRates()
            if let cache = ratesCache.first {
                cache.usdPen = rates.usd_pen
                cache.arsPen = rates.ars_pen
                cache.updatedAt = Date()
            } else {
                modelContext.insert(ExchangeRatesCache(usdPen: rates.usd_pen, arsPen: rates.ars_pen, updatedAt: Date()))
            }

            let apiSubs = try await ApiClient.shared.fetchSubscriptions()
            // In a real app, you'd do a proper diff here. For simplicity, we just clear and add.
            // Be careful to not delete local unsynced changes.
            // Simplified offline-first logic for demonstration:
            let localIds = Set(subscriptions.map { $0.id })

            for apiSub in apiSubs {
                if !localIds.contains(apiSub.id) {
                    let newSub = Subscription(id: apiSub.id, name: apiSub.name, cost: apiSub.cost, currency: apiSub.currency, billingDay: apiSub.billingDay)
                    modelContext.insert(newSub)
                    SystemIntegrations.shared.scheduleNotificationAndEvent(for: newSub)
                }
            }

        } catch {
            print("Sync failed: \(error)")
        }
    }
}

struct SubscriptionRow: View {
    let subscription: Subscription
    let rates: ExchangeRatesCache

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(subscription.name).font(.headline)
                Text("Billing day: \(subscription.billingDay)").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(subscription.currency) \(String(format: "%.2f", subscription.cost))")
                    .font(.subheadline)
                if subscription.currency != "PEN" {
                    Text("~ S/ \(String(format: "%.2f", convertToPEN()))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func convertToPEN() -> Double {
        switch subscription.currency {
        case "USD": return subscription.cost * rates.usdPen
        case "ARS": return subscription.cost * rates.arsPen
        default: return subscription.cost
        }
    }
}

struct AddSubscriptionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var cost: Double = 0.0
    @State private var currency = "PEN"
    @State private var billingDay = 1

    let currencies = ["PEN", "USD", "ARS"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Cost", value: $cost, format: .number)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif

                Picker("Currency", selection: $currency) {
                    ForEach(currencies, id: \.self) {
                        Text($0)
                    }
                }

                Picker("Billing Day", selection: $billingDay) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
            }
            .navigationTitle("New Subscription")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.isEmpty || cost <= 0)
                }
            }
        }
    }

    private func save() {
        let sub = Subscription(name: name, cost: cost, currency: currency, billingDay: billingDay)
        modelContext.insert(sub)
        SystemIntegrations.shared.scheduleNotificationAndEvent(for: sub)

        Task {
            try? await ApiClient.shared.createSubscription(sub)
        }

        dismiss()
    }
}

struct EditSubscriptionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var cost: Double
    @State private var currency: String
    @State private var billingDay: Int

    let subscription: Subscription
    let currencies = ["PEN", "USD", "ARS"]

    init(subscription: Subscription) {
        self.subscription = subscription
        _name = State(initialValue: subscription.name)
        _cost = State(initialValue: subscription.cost)
        _currency = State(initialValue: subscription.currency)
        _billingDay = State(initialValue: subscription.billingDay)
    }

    var body: some View {
        Form {
            TextField("Name", text: $name)
            TextField("Cost", value: $cost, format: .number)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif

            Picker("Currency", selection: $currency) {
                ForEach(currencies, id: \.self) {
                    Text($0)
                }
            }

            Picker("Billing Day", selection: $billingDay) {
                ForEach(1...31, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
        }
        .navigationTitle("Edit Subscription")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(name.isEmpty || cost <= 0)
            }
        }
    }

    private func save() {
        SystemIntegrations.shared.cancelNotification(for: subscription.id)

        subscription.name = name
        subscription.cost = cost
        subscription.currency = currency
        subscription.billingDay = billingDay

        SystemIntegrations.shared.scheduleNotificationAndEvent(for: subscription)

        Task {
            try? await ApiClient.shared.updateSubscription(subscription)
        }

        dismiss()
    }
}
