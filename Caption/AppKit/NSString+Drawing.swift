//
//  NSString+Drawing.swift
//  Dice
//
//  Created by Blue on 3/6/19.
//  Copyright © 2019 Blue. All rights reserved.
//

import Foundation

extension NSString {
//    draw(in rect: NSRect, withAttributes attrs: [NSAttributedString.Key : Any]? = nil)
    func drawCentered(in rect: NSRect, withAttributes attrs: [NSAttributedString.Key: Any]? = nil) {
        let stringSize = size(withAttributes: attrs)
        let point = NSPoint(x: rect.origin.x + (rect.width - stringSize.width) / 2.0,
                            y: rect.origin.y + (rect.height - stringSize.height) / 2.0)
        draw(at: point, withAttributes: attrs)
    }
}
