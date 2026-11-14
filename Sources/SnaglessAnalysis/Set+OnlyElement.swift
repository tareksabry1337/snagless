extension Set {
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
