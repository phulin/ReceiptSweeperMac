import Foundation
import Combine

enum CellState: Equatable {
    case hidden, empty, flagged, mine, exploded
    case revealed(Int)
}

struct Coordinate: Equatable {
    let x: Int
    let y: Int
}

enum PlayerAction: String {
    case test = "test"
    case flag = "flag"
}

struct GameResult {
    let message: String
}

class MinesweeperGame: ObservableObject {
    @Published var board: [[CellState]]
    @Published var isGameOver: Bool = false
    @Published var isWon: Bool = false
    
    private let rows = 10
    private let cols = 10
    private let totalMines = 15
    private var mines: Set<Int> = [] // Stored as y * cols + x
    
    init() {
        self.board = Array(repeating: Array(repeating: .hidden, count: cols), count: rows)
        placeMines()
    }
    
    func reset() {
        self.board = Array(repeating: Array(repeating: .hidden, count: cols), count: rows)
        self.isGameOver = false
        self.isWon = false
        placeMines()
    }
    
    private func placeMines() {
        mines.removeAll()
        while mines.count < totalMines {
            let index = Int.random(in: 0..<(rows * cols))
            mines.insert(index)
        }
    }
    
    private func isMine(at coord: Coordinate) -> Bool {
        return mines.contains(coord.y * cols + coord.x)
    }
    
    private func getAdjacentMines(at coord: Coordinate) -> Int {
        var count = 0
        for dy in -1...1 {
            for dx in -1...1 {
                if dy == 0 && dx == 0 { continue }
                let ny = coord.y + dy
                let nx = coord.x + dx
                if ny >= 0 && ny < rows && nx >= 0 && nx < cols {
                    if isMine(at: Coordinate(x: nx, y: ny)) {
                        count += 1
                    }
                }
            }
        }
        return count
    }
    
    private func floodReveal(from coord: Coordinate) {
        var queue = [coord]
        var visited = Set<Int>()
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            let index = current.y * cols + current.x
            if visited.contains(index) || board[current.y][current.x] != .hidden || isMine(at: current) {
                continue
            }
            
            visited.insert(index)
            
            let adjacentMines = getAdjacentMines(at: current)
            if adjacentMines > 0 {
                board[current.y][current.x] = .revealed(adjacentMines)
            } else {
                board[current.y][current.x] = .empty
                for dy in -1...1 {
                    for dx in -1...1 {
                        if dy == 0 && dx == 0 { continue }
                        let ny = current.y + dy
                        let nx = current.x + dx
                        if ny >= 0 && ny < rows && nx >= 0 && nx < cols {
                            let neighbor = Coordinate(x: nx, y: ny)
                            if !visited.contains(neighbor.y * cols + neighbor.x) && board[ny][nx] == .hidden {
                                queue.append(neighbor)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func checkWinCondition() {
        var hiddenOrFlaggedCount = 0
        for y in 0..<rows {
            for x in 0..<cols {
                if board[y][x] == .hidden || board[y][x] == .flagged {
                    hiddenOrFlaggedCount += 1
                }
            }
        }
        
        if hiddenOrFlaggedCount == totalMines {
            isWon = true
            isGameOver = true
        }
    }
    
    func applyAction(action: PlayerAction, coordinate: Coordinate) -> GameResult {
        if isGameOver {
            return GameResult(message: "Game is already over.")
        }
        
        let currentState = board[coordinate.y][coordinate.x]
        
        switch action {
        case .test:
            if currentState == .flagged {
                return GameResult(message: "Cannot test a flagged cell.")
            }
            if currentState != .hidden {
                return GameResult(message: "Cell is already revealed.")
            }
            
            if isMine(at: coordinate) {
                board[coordinate.y][coordinate.x] = .exploded
                isGameOver = true
                return GameResult(message: "BOOM! You hit a mine.")
            } else {
                let adjacentCounts = getAdjacentMines(at: coordinate)
                if adjacentCounts > 0 {
                    board[coordinate.y][coordinate.x] = .revealed(adjacentCounts)
                } else {
                    floodReveal(from: coordinate)
                }
                
                checkWinCondition()
                if isWon {
                    return GameResult(message: "Congratulations! You won!")
                }
                return GameResult(message: "Safe. Continuing...")
            }
            
        case .flag:
            if currentState == .hidden {
                board[coordinate.y][coordinate.x] = .flagged
                return GameResult(message: "Flag added.")
            } else if currentState == .flagged {
                board[coordinate.y][coordinate.x] = .hidden
                return GameResult(message: "Flag removed.")
            } else {
                return GameResult(message: "Cannot flag a revealed cell.")
            }
        }
    }
}
