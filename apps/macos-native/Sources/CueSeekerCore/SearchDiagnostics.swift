import Foundation

public struct SubtitleSearchDiagnosticField: Sendable {
    public let name: String
    public let value: String

    public init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }

    public init(_ name: String, _ value: Int) {
        self.name = name
        self.value = String(value)
    }

    public init(_ name: String, _ value: Int64) {
        self.name = name
        self.value = String(value)
    }
}

public struct SubtitleSearchDiagnosticEvent: Sendable {
    public let name: String
    public let phaseMilliseconds: Double
    public let fields: [SubtitleSearchDiagnosticField]

    public init(
        name: String,
        phaseMilliseconds: Double,
        fields: [SubtitleSearchDiagnosticField] = []
    ) {
        self.name = name
        self.phaseMilliseconds = phaseMilliseconds
        self.fields = fields
    }
}

public typealias SubtitleSearchDiagnosticSink = @Sendable (SubtitleSearchDiagnosticEvent) -> Void
