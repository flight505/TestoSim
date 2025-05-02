//
//  CDUserProfile+CoreDataProperties.swift
//  TestoSim
//
//  Created by Jesper Vang on 02/05/2025.
//
//

import Foundation
import CoreData


extension CDUserProfile {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDUserProfile> {
        return NSFetchRequest<CDUserProfile>(entityName: "CDUserProfile")
    }

    @NSManaged public var biologicalSex: String?
    @NSManaged public var calibrationFactor: Double
    @NSManaged public var dateOfBirth: Date?
    @NSManaged public var heightCm: Double
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var unit: String?
    @NSManaged public var usesICloudSync: Bool
    @NSManaged public var weight: Double
    @NSManaged public var protocols: NSSet?

}

// MARK: Generated accessors for protocols
extension CDUserProfile {

    @objc(addProtocolsObject:)
    @NSManaged public func addToProtocols(_ value: CDInjectionProtocol)

    @objc(removeProtocolsObject:)
    @NSManaged public func removeFromProtocols(_ value: CDInjectionProtocol)

    @objc(addProtocols:)
    @NSManaged public func addToProtocols(_ values: NSSet)

    @objc(removeProtocols:)
    @NSManaged public func removeFromProtocols(_ values: NSSet)

}

extension CDUserProfile : Identifiable {

}
