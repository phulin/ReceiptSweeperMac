//
//  TextRenderer.swift
//  ReceiptSweeperMac
//
//  Created by Patrick Hulin on 2/20/26.
//

import AppKit
import CoreGraphics

class TextRenderer {
    
    static func renderTextToPrinterLines(_ text: String) -> [[UInt8]] {
        let width = 384
        
        let font = NSFont.systemFont(ofSize: 32)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]
        
        let attrString = NSAttributedString(string: text, attributes: attributes)
        
        let rect = attrString.boundingRect(with: NSSize(width: CGFloat(width), height: .greatestFiniteMagnitude),
                                           options: .usesLineFragmentOrigin)
        let height = Int(ceil(rect.height) + 16)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return []
        }
        
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nsContext
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        
        let drawRect = NSRect(x: 0, y: 8, width: width, height: height - 8)
        attrString.draw(in: drawRect)
        
        NSGraphicsContext.restoreGraphicsState()
        
        guard let data = context.data else { return [] }
        let ptr = data.bindMemory(to: UInt8.self, capacity: width * height)
        let buffer = UnsafeBufferPointer(start: ptr, count: width * height)
        
        var chunks: [[UInt8]] = []
        let finalBytesPerRow = width / 8
        
        for y in 0..<height {
            var rowBytes = [UInt8](repeating: 0, count: finalBytesPerRow)
            for x in 0..<width {
                let pixelValue = buffer[y * width + x]
                let isBlack = pixelValue < 128
                
                if isBlack {
                    let byteIndex = x / 8
                    let normalBitIndex = 7 - (x % 8)
                    rowBytes[byteIndex] |= (1 << normalBitIndex)
                }
            }
            
            for i in 0..<finalBytesPerRow {
                rowBytes[i] = reverseByte(rowBytes[i])
            }
            chunks.append(rowBytes)
        }
        
        return chunks
    }
    
    static func reverseByte(_ b: UInt8) -> UInt8 {
        var a = b
        a = ((a & 0xF0) >> 4) | ((a & 0x0F) << 4)
        a = ((a & 0xCC) >> 2) | ((a & 0x33) << 2)
        a = ((a & 0xAA) >> 1) | ((a & 0x55) << 1)
        return a
    }
}
