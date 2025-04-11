/*
Abstract:
An enumeration that represents each part of the bone and defines the joint name from the hand skeleton.
*/

enum Bone: Int, CaseIterable {
    case arm
    case wrist
    case metacarpal
    case knuckle
    case intermediateBase
    case intermediateTip
    case tip
} 