import Foundation

struct ReceiptFormatter {
    private static func cellToken(_ state: CellState) -> String {
        switch state {
        case .hidden: return "■"
        case .empty: return " "
        case .flagged: return "⚑"
        case .mine: return "☀"
        case .exploded: return "X"
        case .revealed(let count): return "\(count)"
        }
    }
    
    private static func charLabel(_ index: Int) -> String {
        return String(UnicodeScalar(65 + index)!)
    }
    
    static func formatBoard(_ board: [[CellState]], action: PlayerAction, coordinate: Coordinate, status: String) -> String {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        
        var output = ""
        
        // Header
        output += "   " + (0..<10).map { "\($0)" }.joined(separator: " ") + "\n"
        
        // Board
        for y in 0..<10 {
            let label = charLabel(y)
            let row = board[y].map { cellToken($0) }.joined(separator: " ")
            output += " \(label) \(row)\n"
        }
        
        // Footer
        output += "\n"
        output += "ACTION: \(action.rawValue.uppercased()) @ \(charLabel(coordinate.y))\(coordinate.x)\n"
        output += "STATUS: \(status)\n"
        output += "TIME: \(timestamp)\n"
        output += "-------------------------\n\n\n"
        
        return output
    }
}
