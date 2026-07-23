protocol AppUsageStoring {
    func loadHistory() -> AppUsageHistory
    func saveHistory(_ history: AppUsageHistory)
}
