//
//  CDVialBlend+CoreDataProperties.swift
//  TestoSim
//
//  Created by Jesper Vang on 02/05/2025.
//
//

import Foundation
import CoreData


extension CDVialBlend {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDVialBlend> {
        return NSFetchRequest<CDVialBlend>(entityName: "CDVialBlend")
    }

    @NSManaged public var blendDescription: String?
    @NSManaged public var id: UUID?
    @NSManaged public var manufacturer: String?
    @NSManaged public var name: String?
    @NSManaged public var components: NSSet?

}

// MARK: Generated accessors for components
extension CDVialBlend {

    @objc(addComponentsObject:)
    @NSManaged public func addToComponents(_ value: CDVialComponent)

    @objc(removeComponentsObject:)
    @NSManaged public func removeFromComponents(_ value: CDVialComponent)

    @objc(addComponents:)
    @NSManaged public func addToComponents(_ values: NSSet)

    @objc(removeComponents:)
    @NSManaged public func removeFromComponents(_ values: NSSet)

}

extension CDVialBlend : Identifiable {

}
