//
//  ContentView.swift
//  ReceiptSweeperMac
//
//  Created by Patrick Hulin on 2/20/26.
//

import SwiftUI
import CoreBluetooth

func fileLog(_ msg: String) {
    let url = URL(fileURLWithPath: "/tmp/receiptsweeper_log.txt")
    let txt = "\(Date()): \(msg)\n"
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        if let data = txt.data(using: .utf8) {
            handle.write(data)
        }
        handle.closeFile()
    } else {
        try? txt.write(to: url, atomically: true, encoding: .utf8)
    }
}

struct ContentView: View {
    @StateObject private var printerManager = BluetoothPrinterManager()
    @StateObject private var game = MinesweeperGame()
    
    @State private var coordinateInput: String = ""
    @State private var action: PlayerAction = .test
    
    var body: some View {
        VStack(spacing: 0) {
            if printerManager.connectionState == "Connected" {
                gameView
            } else {
                connectView
            }
        }
        .font(.system(.body, design: .monospaced))
        .frame(width: 380, height: 260)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var connectView: some View {
        VStack(spacing: 20) {
            Text("ReceiptSweeper")
                .font(.system(.title, design: .monospaced))
                .bold()
            
            Text("Status: \(printerManager.connectionState)")
                .foregroundColor(.secondary)
            
            if printerManager.connectionState == "Disconnected" || printerManager.connectionState == "Bluetooth is off or unavailable" {
                Button("Scan for Printers") {
                    printerManager.startScanning()
                }
                .buttonStyle(.borderedProminent)
            } else if printerManager.connectionState == "Scanning..." {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            if !printerManager.discoveredPeripherals.isEmpty {
                List(printerManager.discoveredPeripherals, id: \.identifier) { peripheral in
                    Button(action: {
                        printerManager.connect(to: peripheral)
                    }) {
                        Text(peripheral.name ?? "Unknown Printer")
                    }
                }
                .frame(maxHeight: 120)
                .cornerRadius(8)
            }
        }
        .padding(30)
    }
    
    private var gameView: some View {
        VStack(spacing: 24) {
            Text("ReceiptSweeper")
                .font(.system(.title2, design: .monospaced))
                .bold()
                .padding(.top, 20)
            
            HStack(spacing: 12) {
                TextField("A3", text: $coordinateInput)
                    .font(.system(size: 20, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .disabled(game.isGameOver)
                    .onSubmit {
                        performMove()
                    }
                
                Picker("", selection: $action) {
                    Text("Test").tag(PlayerAction.test)
                    Text("Flag").tag(PlayerAction.flag)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
                .disabled(game.isGameOver)
                .labelsHidden()
                
                Button(action: performMove) {
                    Text("Print")
                        .bold()
                        .padding(.horizontal, 8)
                }
                .disabled(printerManager.isPrinting || coordinateInput.isEmpty || game.isGameOver)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            Button("New Game") {
                fileLog("Minesweeper: Starting New Game")
                game.reset()
                coordinateInput = ""
                printCurrentState(action: .test, coord: Coordinate(x: 0, y: 0), status: "New game started.")
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 20)
        }
    }
    
    private func performMove() {
        let input = coordinateInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        fileLog("Minesweeper: Validating input \(input)")
        guard let coord = parseCoordinate(input) else {
            fileLog("Minesweeper: Invalid coordinate \(input)")
            return
        }
        
        fileLog("Minesweeper: Applying action \(action) to \(coord)")
        let result = game.applyAction(action: action, coordinate: coord)
        fileLog("Minesweeper: Result: \(result.message)")
        
        fileLog("Minesweeper: Printing to Bluetooth...")
        printCurrentState(action: action, coord: coord, status: result.message)
        
        if !game.isGameOver {
            coordinateInput = ""
        }
    }
    
    private func printCurrentState(action: PlayerAction, coord: Coordinate, status: String) {
        let receiptText = ReceiptFormatter.formatBoard(game.board, action: action, coordinate: coord, status: status)
        fileLog("Minesweeper: Printing receipt text:\n\(receiptText)")
        let lines = TextRenderer.renderTextToPrinterLines(receiptText)
        fileLog("Minesweeper: Rendered to \(lines.count) printer lines")
        printerManager.printImageLines(lines: lines)
    }
    
    private func parseCoordinate(_ input: String) -> Coordinate? {
        let pattern = "^([A-J])(\\d)$"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let altPattern = "^(\\d)([A-J])$"
        let altRegex = try? NSRegularExpression(pattern: altPattern, options: .caseInsensitive)
        
        let range = NSRange(location: 0, length: input.utf16.count)
        
        if let match = regex?.firstMatch(in: input, options: [], range: range) {
            let letterPart = (input as NSString).substring(with: match.range(at: 1)).uppercased()
            let digitPart = (input as NSString).substring(with: match.range(at: 2))
            
            let y = Int(letterPart.unicodeScalars.first!.value) - 65
            let x = Int(digitPart)!
            
            if x >= 0 && x < 10 && y >= 0 && y < 10 {
                return Coordinate(x: x, y: y)
            }
        } else if let match = altRegex?.firstMatch(in: input, options: [], range: range) {
            let digitPart = (input as NSString).substring(with: match.range(at: 1))
            let letterPart = (input as NSString).substring(with: match.range(at: 2)).uppercased()
            
            let x = Int(digitPart)!
            let y = Int(letterPart.unicodeScalars.first!.value) - 65
            
            if x >= 0 && x < 10 && y >= 0 && y < 10 {
                return Coordinate(x: x, y: y)
            }
        }
        
        return nil
    }
}

#Preview {
    ContentView()
}
