//
//  CDCompound+CoreDataProperties.swift
//  TestoSim
//
//  Created by Jesper Vang on 02/05/2025.
//
//

import Foundation
import CoreData


extension CDCompound {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDCompound> {
        return NSFetchRequest<CDCompound>(entityName: "CDCompound")
    }

    @NSManaged public var classType: String?
    @NSManaged public var commonName: String?
    @NSManaged public var ester: String?
    @NSManaged public var halfLifeDays: Double
    @NSManaged public var id: UUID?
    @NSManaged public var routeBioavailabilityData: Data?
    @NSManaged public var routeKaData: Data?
    @NSManaged public var components: NSSet?
    @NSManaged public var protocols: NSSet?

}

// MARK: Generated accessors for components
extension CDCompound {

    @objc(addComponentsObject:)
    @NSManaged public func addToComponents(_ value: CDVialComponent)

    @objc(removeComponentsObject:)
    @NSManaged public func removeFromComponents(_ value: CDVialComponent)

    @objc(addComponents:)
    @NSManaged public func addToComponents(_ values: NSSet)

    @objc(removeComponents:)
    @NSManaged public func removeFromComponents(_ values: NSSet)

}

// MARK: Generated accessors for protocols
extension CDCompound {

    @objc(addProtocolsObject:)
    @NSManaged public func addToProtocols(_ value: CDInjectionProtocol)

    @objc(removeProtocolsObject:)
    @NSManaged public func removeFromProtocols(_ value: CDInjectionProtocol)

    @objc(addProtocols:)
    @NSManaged public func addToProtocols(_ values: NSSet)

    @objc(removeProtocols:)
    @NSManaged public func removeFromProtocols(_ values: NSSet)

}

extension CDCompound : Identifiable {

}
