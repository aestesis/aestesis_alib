//
//  system.extensions.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 29/10/2023.
//

import AVFoundation
import CoreImage
import Foundation

#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension AVAsset {
    func generateThumbnail(_ fn: @escaping @Sendable (CGImage?) -> Void) {
        let imageGenerator = AVAssetImageGenerator(asset: self)
        let time = CMTime(seconds: 0.0, preferredTimescale: 600)
        let times = [NSValue(time: time)]
        imageGenerator.generateCGImagesAsynchronously(
            forTimes: times,
            completionHandler: { _, image, _, _, error in
                if let image = image {
                    fn(image)
                } else {
                    fn(nil)
                }
            })
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension CGImage {
    func croppedResize(size: CGSize) -> CGImage? {
        let width: Int = Int(size.width)
        let height: Int = Int(size.height)
        let bytesPerPixel = self.bitsPerPixel / self.bitsPerComponent
        let destBytesPerRow = width * bytesPerPixel
        guard let colorSpace = self.colorSpace else { return nil }
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: self.bitsPerComponent,
                bytesPerRow: destBytesPerRow, space: colorSpace, bitmapInfo: self.alphaInfo.rawValue
            )
        else { return nil }
        context.interpolationQuality = .high
        let rr: Double =
            (Double(self.width) / Double(self.height)) / (Double(width) / Double(height))
        if rr >= 1 {
            let dx = Int((Double(width) * rr - Double(width)) * 0.5)
            context.draw(self, in: CGRect(x: -dx, y: 0, width: width + dx * 2, height: height))
        } else {
            let dy = Int((Double(height) / rr - Double(height)) * 0.5)
            context.draw(self, in: CGRect(x: 0, y: -dy, width: width, height: height + 2 * dy))
        }
        return context.makeImage()
    }

    func jpegData() -> Data {
        #if os(iOS)
            let uiImage = UIImage(cgImage: self)
            return UIImageJPEGRepresentation(uiImage, 0.9)
        #else
            let bitmapRep = NSBitmapImageRep(cgImage: self)
            return bitmapRep.representation(
                using: NSBitmapImageRep.FileType.jpeg,
                properties: [NSBitmapImageRep.PropertyKey.compressionFactor: NSNumber(0.9)])!
        #endif
    }

    func pngData() -> Data {
        #if os(iOS)
            let uiImage = UIImage(cgImage: self)
            return UIImageJPEGRepresentation(uiImage, 0.9)
        #else
            let bitmapRep = NSBitmapImageRep(cgImage: self)
            return bitmapRep.representation(
                using: NSBitmapImageRep.FileType.jpeg,
                properties: [NSBitmapImageRep.PropertyKey.compressionFactor: NSNumber(0.9)])!
        #endif
    }

}
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public extension URL {
    var fileExtension: String {
        if isFileURL {
            let filename = self.lastPathComponent
            if let i = filename.lastIndexOf(".") {
                return String(filename[i + 1..<filename.length])
            }
        }
        return ""
    }
    func checkFile(strategy: CheckStrategy) -> URL {
        if isFileURL {
            let fm = FileManager.default
            switch strategy {
            case .replace:
                if fm.fileExists(atPath: path) {
                    do {
                        try fm.removeItem(atPath: path)
                    } catch {
                        Debug.warning("\(error)")
                        return checkFile(strategy: .rename)
                    }
                }
            case .rename:
                var i = 1
                var npath = path
                while fm.fileExists(atPath: npath) {
                    npath = path
                    npath.replace(".\(fileExtension)", with: ".\(i).\(fileExtension)")
                    i += 1
                }
                return URL(filePath: npath)
            }
        }
        return self
    }
    enum CheckStrategy {
        case replace
        case rename
    }
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
