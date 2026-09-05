import Foundation

func ABBLog(_ format: String, _ args: CVarArg...) {
    withVaList(args) { NSLogv(format, $0) }
}
