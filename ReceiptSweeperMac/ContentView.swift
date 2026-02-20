//
//  ContentView.swift
//  ReceiptSweeperMac
//
//  Created by Patrick Hulin on 2/20/26.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var printerManager = BluetoothPrinterManager()
    @State private var textToPrint: String = "Hello\nCat Printer!"
    @State private var selectedPrinter: UUID?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Cat Printer App")
                .font(.title)
                .bold()
            
            HStack {
                Text("Status: \(printerManager.connectionState)")
                    .foregroundColor(printerManager.connectionState == "Connected" ? .green : .secondary)
                Spacer()
                if printerManager.connectionState == "Disconnected" || printerManager.connectionState == "Bluetooth is off or unavailable" {
                    Button("Scan") {
                        printerManager.startScanning()
                    }
                } else if printerManager.connectionState == "Scanning..." {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            if !printerManager.discoveredPeripherals.isEmpty && printerManager.connectionState != "Connected" {
                List(printerManager.discoveredPeripherals, id: \.identifier) { peripheral in
                    Button(action: {
                        printerManager.connect(to: peripheral)
                    }) {
                        Text(peripheral.name ?? "Unknown Printer")
                    }
                }
                .frame(maxHeight: 100)
            }
            
            TextEditor(text: $textToPrint)
                .font(.system(size: 16))
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            
            Button(action: {
                let lines = TextRenderer.renderTextToPrinterLines(textToPrint)
                printerManager.printImageLines(lines: lines)
            }) {
                Text(printerManager.isPrinting ? "Printing..." : "Print")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .disabled(printerManager.connectionState != "Connected" || printerManager.isPrinting || textToPrint.isEmpty)
            .buttonStyle(.borderedProminent)
            
        }
        .padding()
        .frame(minWidth: 400, minHeight: 450)
    }
}

#Preview {
    ContentView()
}
