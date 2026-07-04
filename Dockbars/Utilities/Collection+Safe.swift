extension Collection {
    /// Bounds-checked subscript: returns nil instead of trapping.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
