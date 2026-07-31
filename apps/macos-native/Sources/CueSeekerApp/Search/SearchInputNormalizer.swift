import Foundation

enum SearchInputNormalizer {
    static func singleLine(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.utf8.count)
        var previousScalarWasCarriageReturn = false

        for scalar in text.unicodeScalars {
            if scalar.value == 0x0A, previousScalarWasCarriageReturn {
                previousScalarWasCarriageReturn = false
                continue
            }
            if CharacterSet.newlines.contains(scalar) {
                result.append(" ")
                previousScalarWasCarriageReturn = scalar.value == 0x0D
            } else {
                result.append(contentsOf: String(scalar))
                previousScalarWasCarriageReturn = false
            }
        }
        return result
    }
}
