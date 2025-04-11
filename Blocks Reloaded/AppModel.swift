//
//  AppModel.swift
//  Blocks Reloaded
//
//  Created by Tom Krikorian on 11/04/2025.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    
    public static let shared = AppModel()
    
    public var isPinchingLeftHand: Bool = false
    public var leftPinchPosition: SIMD3<Float> = .zero
    
    public var isPinchingRightHand: Bool = false
    public var rightPinchPosition: SIMD3<Float> = .zero
    
    public init() { }
    
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
}
