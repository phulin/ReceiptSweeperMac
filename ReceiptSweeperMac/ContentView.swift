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

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
    
    static let appBackground = Color(hex: 0x1E1E24)
    static let cardBackground = Color.white.opacity(0.05)
    static let accentBlue = Color(hex: 0x3A86FF)
    static let accentPurple = Color(hex: 0x8338EC)
}

struct ContentView: View {
    @StateObject private var printerManager = BluetoothPrinterManager()
    @StateObject private var game = MinesweeperGame()
    
    @State private var coordinateInput: String = ""
    @State private var action: PlayerAction = .test
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Custom Top Bar
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "printer.dotmatrix.fill")
                        .foregroundColor(Color.white)
                        .font(.system(size: 18))
                        .shadow(color: Color.accentBlue.opacity(0.5), radius: 5, x: 0, y: 0)
                    
                    Text("ReceiptSweeper")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Connection pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(printerManager.connectionState == "Connected" ? Color.green : (printerManager.connectionState == "Scanning..." ? Color.orange : Color.red))
                        .frame(width: 8, height: 8)
                        .shadow(color: (printerManager.connectionState == "Connected" ? Color.green : Color.red).opacity(0.5), radius: 3)
                    
                    Text(printerManager.connectionState == "Connected" ? "Connected" : (printerManager.connectionState == "Scanning..." ? "Scanning" : "Disconnected"))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.3))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.horizontal, 20)
            .padding(.top, 28) // extra padding to account for mac titlebar if ignored
            .padding(.bottom, 16)
            .background(
                LinearGradient(colors: [Color.accentBlue, Color.accentPurple], startPoint: .leading, endPoint: .trailing)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            .zIndex(1)
            
            // MARK: - Main Content Area
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if printerManager.connectionState == "Connected" {
                    gameView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    connectView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
        }
        .frame(minWidth: 420, idealWidth: 420, minHeight: 320, idealHeight: 320)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: printerManager.connectionState)
        .ignoresSafeArea() // Let our top bar merge with window top
    }
    
    // MARK: - Connect View
    private var connectView: some View {
        VStack(spacing: 0) {
            if printerManager.discoveredPeripherals.isEmpty {
                Spacer()
                
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentBlue.opacity(0.1))
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(Color.accentBlue)
                            .symbolEffect(.pulse, options: .repeating, isActive: printerManager.connectionState == "Scanning...")
                    }
                    
                    Text(printerManager.connectionState == "Scanning..." ? "Looking for Printers..." : "Printer Not Connected")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
                
                if printerManager.connectionState == "Disconnected" || printerManager.connectionState == "Bluetooth is off or unavailable" {
                    Button(action: { printerManager.startScanning() }) {
                        Text("Scan for Printers")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.accentBlue))
                            .shadow(color: Color.accentBlue.opacity(0.4), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 24)
                }
                
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(printerManager.discoveredPeripherals, id: \.identifier) { peripheral in
                            let name = peripheral.name?.lowercased() ?? ""
                            let isSupported = name.contains("gt01") || name.contains("mt") || name.contains("mx06")
                            
                            Button(action: { printerManager.connect(to: peripheral) }) {
                                HStack {
                                    Image(systemName: "printer")
                                        .foregroundColor(isSupported ? Color.accentBlue : .gray)
                                    Text(peripheral.name ?? "Unknown Printer")
                                        .foregroundColor(isSupported ? .white : .gray)
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    if !isSupported {
                                        Text("Unsupported")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.gray)
                                    }
                                    Image(systemName: "chevron.right")
                                        .foregroundColor((isSupported ? Color.white : Color.gray).opacity(0.3))
                                        .font(.system(size: 12))
                                }
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(!isSupported)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 20)
                }
            }
        }
    }
    
    // MARK: - Game View
    private var gameView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Controls Card
            VStack(spacing: 24) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COORDINATE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.0)
                        
                        TextField("A3", text: $coordinateInput)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .frame(width: 80, height: 48)
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
                            .disabled(game.isGameOver)
                            .onSubmit { performMove() }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ACTION")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.0)
                        
                        Picker("", selection: $action) {
                            Text("Test").tag(PlayerAction.test)
                            Text("Flag").tag(PlayerAction.flag)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 130, height: 48)
                        .disabled(game.isGameOver)
                        .labelsHidden()
                    }
                }
                
                Button(action: performMove) {
                    HStack(spacing: 8) {
                        Image(systemName: printerManager.isPrinting ? "printer.dotmatrix.fill.and.paper.empty" : "printer.fill")
                        Text(printerManager.isPrinting ? "Printing..." : "Print Move")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        (printerManager.isPrinting || coordinateInput.isEmpty || game.isGameOver) ? 
                        Color.white.opacity(0.1) : Color.accentBlue
                    )
                    .cornerRadius(10)
                    .shadow(color: (printerManager.isPrinting || coordinateInput.isEmpty || game.isGameOver) ? Color.clear : Color.accentBlue.opacity(0.4), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(printerManager.isPrinting || coordinateInput.isEmpty || game.isGameOver)
            }
            .padding(24)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 30)
            
            Spacer()
            
            Button(action: {
                fileLog("Minesweeper: Starting New Game")
                game.reset()
                coordinateInput = ""
                printCurrentState(action: .test, coord: Coordinate(x: 0, y: 0), status: "New game started.")
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Restart Game")
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Game Logic
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
