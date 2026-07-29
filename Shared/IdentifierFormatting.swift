import Foundation

extension BinaryInteger {
    /// A bike, station, or stand number as bare digits: interpolating an `Int` straight into a
    /// `LocalizedStringKey` formats it as a quantity, so bike 22881 would render as "#22,881".
    var identifierText: String { "\(self)" }
}
