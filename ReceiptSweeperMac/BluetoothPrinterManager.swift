//
//  BluetoothPrinterManager.swift
//  ReceiptSweeperMac
//
//  Created by Patrick Hulin on 2/20/26.
//

import Foundation
import CoreBluetooth
import Combine

class BluetoothPrinterManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var connectionState: String = "Disconnected"
    @Published var isPrinting: Bool = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    
    private var centralManager: CBCentralManager!
    private var printerPeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    
    // Commands
    private let CMD_GET_STATE: UInt8 = 0xA3
    private let CMD_START_LATTICE: UInt8 = 0xA6
    private let CMD_SET_DPI: UInt8 = 0xA4
    private let CMD_SET_SPEED: UInt8 = 0xBD
    private let CMD_SET_ENERGY: UInt8 = 0xAF
    private let CMD_APPLY_ENERGY: UInt8 = 0xBE
    private let CMD_FEED_PAPER: UInt8 = 0xA1
    private let CMD_DRAW_BITMAP: UInt8 = 0xA2
    
    private var isPaused = false
    private var dataQueue: [[UInt8]] = []
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        if centralManager.state == .poweredOn {
            connectionState = "Scanning..."
            discoveredPeripherals.removeAll()
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            connectionState = "Bluetooth not available."
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        centralManager.stopScan()
        connectionState = "Connecting..."
        printerPeripheral = peripheral
        printerPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            connectionState = "Disconnected"
            startScanning()
        } else {
            connectionState = "Bluetooth is off or unavailable"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, !name.isEmpty {
            if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredPeripherals.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = "Connected"
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionState = "Disconnected"
        txCharacteristic = nil
        rxCharacteristic = nil
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            // TX
            if characteristic.uuid.uuidString.lowercased().contains("ae01") {
                txCharacteristic = characteristic
            }
            // RX
            if characteristic.uuid.uuidString.lowercased().contains("ae02") {
                rxCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        let bytes = [UInt8](data)
        
        // Check for flow control
        if bytes.count >= 9 && bytes[0] == 0x51 && bytes[1] == 0x78 && bytes[2] == 0xAE && bytes[3] == 0x01 {
            if bytes[6] == 0x10 && bytes[7] == 0x70 { // Pause
                isPaused = true
            } else if bytes[6] == 0x00 && bytes[7] == 0x00 { // Resume
                isPaused = false
                sendNextChunk()
            }
        }
    }
    
    // MARK: - Printing Pipeline
    
    func printImageLines(lines: [[UInt8]]) {
        guard txCharacteristic != nil else { return }
        isPrinting = true
        dataQueue = lines
        
        // 1. Get State
        sendCommand(cmd: CMD_GET_STATE, payload: [])
        // 2. Start Print
        sendCommand(cmd: CMD_GET_STATE, payload: [0x00, 0x01, 0x00, 0x00, 0x00])
        // 3. Set DPI
        sendCommand(cmd: CMD_SET_DPI, payload: [50])
        // 4. Set Speed
        sendCommand(cmd: CMD_SET_SPEED, payload: [32])
        // 5. Set Energy
        sendCommand(cmd: CMD_SET_ENERGY, payload: [0x60, 0x00])
        // 6. Apply Energy
        sendCommand(cmd: CMD_APPLY_ENERGY, payload: [0x01])
        // 7. Start Lattice
        sendCommand(cmd: CMD_START_LATTICE, payload: [0xaa, 0x55, 0x17, 0x38, 0x44, 0x5f, 0x5f, 0x5f, 0x44, 0x38, 0x2c])
        
        isPaused = false
        sendNextChunk()
    }
    
    private func sendNextChunk() {
        guard !isPaused, !dataQueue.isEmpty else {
            if dataQueue.isEmpty && isPrinting {
                finishPrintJob()
            }
            return
        }
        
        let chunk = dataQueue.removeFirst()
        sendCommand(cmd: CMD_DRAW_BITMAP, payload: chunk)
        
        // Recursively send next if not paused (simulating a bit of delay might be good, but we rely on flow control here or simple dispatch)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.sendNextChunk()
        }
    }
    
    private func finishPrintJob() {
        // End Lattice
        sendCommand(cmd: CMD_START_LATTICE, payload: [0xaa, 0x55, 0x17, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x17])
        // Reset Speed
        sendCommand(cmd: CMD_SET_SPEED, payload: [8])
        // Feed Paper
        sendCommand(cmd: CMD_FEED_PAPER, payload: [0x00, 0x80])
        
        DispatchQueue.main.async {
            self.isPrinting = false
        }
    }
    
    // MARK: - Protocol Utilities
    
    private func sendCommand(cmd: UInt8, payload: [UInt8]) {
        guard let p = printerPeripheral, let tx = txCharacteristic else { return }
        
        var packet: [UInt8] = []
        packet.append(contentsOf: [0x51, 0x78])     // Header
        packet.append(cmd)                          // Command
        packet.append(0x00)
        packet.append(UInt8(payload.count))         // Payload length
        packet.append(0x00)
        packet.append(contentsOf: payload)          // Payload
        
        let crc = calculateCRC8(data: payload)
        packet.append(crc)                          // CRC8
        packet.append(0xFF)                         // Suffix
        
        p.writeValue(Data(packet), for: tx, type: .withoutResponse)
    }
    
    private func calculateCRC8(data: [UInt8]) -> UInt8 {
        var crc: UInt8 = 0
        for byte in data {
            crc ^= byte
            for _ in 0..<8 {
                if (crc & 0x80) != 0 {
                    crc = (crc << 1) ^ 0x07
                } else {
                    crc <<= 1
                }
            }
        }
        return crc
    }
}
