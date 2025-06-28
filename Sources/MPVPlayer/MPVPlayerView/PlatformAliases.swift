//
//  File.swift
//  MPVPlayer
//
//  Created by Zain Wu on 2025/6/28.
//

#if canImport(AppKit)
import AppKit
public typealias PlatformView = NSView
public typealias PlatformViewController = NSViewController
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
public typealias PlatformLayoutConstraint = NSLayoutConstraint
#elseif canImport(UIKit)
import UIKit
public typealias PlatformView = UIView
public typealias PlatformViewController = UIViewController
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
public typealias PlatformLayoutConstraint = NSLayoutConstraint
#endif
