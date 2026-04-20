//
//  EdgeInsets.swift
//  Alib
//
//  Created by renan jegouzo on 05/10/2020.
//  Copyright © 2020 aestesis. All rights reserved.
//

import Foundation

public struct EdgeInsets {
    public let top:Double
    public let left:Double
    public let bottom:Double
    public let right:Double
    init() {
        top=0
        left=0
        bottom=0
        right=0
    }
    #if os(iOS)
    init(ei:UIEdgeInsets) {
        top = Double(ei.top)
        left = Double(ei.left)
        bottom = Double(ei.bottom)
        right = Double(ei.right)
    }
    #endif
}
