//
//  CDInjectionProtocol+CoreDataProperties.swift
//  TestoSim
//
//  Created by Jesper Vang on 02/05/2025.
//
//

import Foundation
import CoreData


extension CDInjectionProtocol {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDInjectionProtocol> {
        return NSFetchRequest<CDInjectionProtocol>(entityName: "CDInjectionProtocol")
    }

    @NSManaged public var doseMg: Double
    @NSManaged public var frequencyDays: Double
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var notes: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var bloodSamples: NSSet?
    @NSManaged public var ester: CDCompound?
    @NSManaged public var profile: CDUserProfile?

}

// MARK: Generated accessors for bloodSamples
extension CDInjectionProtocol {

    @objc(addBloodSamplesObject:)
    @NSManaged public func addToBloodSamples(_ value: CDBloodSample)

    @objc(removeBloodSamplesObject:)
    @NSManaged public func removeFromBloodSamples(_ value: CDBloodSample)

    @objc(addBloodSamples:)
    @NSManaged public func addToBloodSamples(_ values: NSSet)

    @objc(removeBloodSamples:)
    @NSManaged public func removeFromBloodSamples(_ values: NSSet)

}

extension CDInjectionProtocol : Identifiable {

}
