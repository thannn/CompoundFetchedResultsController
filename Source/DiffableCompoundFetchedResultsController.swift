//
//  DiffableCompoundFetchedResultsController.swift
//  CompoundFetchedResultsController
//
//  Created by Jonathan Provo on 27/04/2022.
//

import CoreData
import UIKit

@available(iOS 13.0, *)
public final class DiffableCompoundFetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>, NSFetchedResultsControllerDelegate {
	// MARK: - Properties

	public override var cacheName: String? { nil }
	public override var fetchRequest: NSFetchRequest<NSFetchRequestResult> { .init() }
	public override var managedObjectContext: NSManagedObjectContext { controllers.first!.managedObjectContext }
	public override var sectionNameKeyPath: String? { nil }

	private let controllers: [NSFetchedResultsController<NSFetchRequestResult>]
	private var snapshot: NSDiffableDataSourceSnapshotReference = .init()
	private lazy var sectionIdentifiers: [NSFetchedResultsController<NSFetchRequestResult>: String] = createSectionIdentifiers()

	// MARK: - Lifecycle

	public init(controllers: [NSFetchedResultsController<NSFetchRequestResult>]) {
		self.controllers = controllers
		super.init()
		setDelegates()
	}

	// MARK: - NSFetchedResultsController

	public override func performFetch() throws {
		performFetches()
	}

	// MARK: - Controller management
	
	/// Sets the delegates of the NSFetchedResultsController instances.
	private func setDelegates() {
		controllers.forEach { $0.delegate = self }
	}

	/// Executes the fetch requests of the NSFetchedResultsController instances.
	private func performFetches() {
		do {
			try controllers.forEach { try $0.performFetch() }
		} catch let error {
			assertionFailure("Error performing controller fetch: \(error)")
		}
	}

	private func createSectionIdentifiers() -> [NSFetchedResultsController<NSFetchRequestResult>: String] {
		controllers.reduce([:]) {
			var result = $0
			result[$1] = UUID().uuidString
			return result
		}
	}

	private func getSectionIdentifier(before controller: NSFetchedResultsController<NSFetchRequestResult>) -> String? {
		guard let index = controllers.firstIndex(of: controller) else { preconditionFailure("Error retrieving controller's index: \(controller)") }
		guard index > 0 else { return nil }
		return sectionIdentifiers[controllers[index - 1]]
	}

	private func getSectionIdentifier(after controller: NSFetchedResultsController<NSFetchRequestResult>) -> String? {
		guard let index = controllers.firstIndex(of: controller) else { preconditionFailure("Error retrieving controller's index: \(controller)") }
		guard index < controllers.count - 1 else { return nil }
		return sectionIdentifiers[controllers[index + 1]]
	}

	// MARK: - NSFetchedResultsControllerDelegate

	public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		delegate?.controllerWillChangeContent?(self)
	}

	public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
		func snapshotContains(_ snapshot: NSDiffableDataSourceSnapshotReference, sectionIdentifier: String) -> Bool {
			snapshot.sectionIdentifiers.contains { $0 as? String == sectionIdentifier}
		}
		guard let sectionIdentifierforController = sectionIdentifiers[controller] else { preconditionFailure("Error retrieving controller's section: \(controller)") }
		self.snapshot.deleteSections(withIdentifiers: [sectionIdentifierforController])
		snapshot.sectionIdentifiers.forEach { sectionIdentifier in
			if let sectionIdentifierBefore = getSectionIdentifier(before: controller), snapshotContains(self.snapshot, sectionIdentifier: sectionIdentifierBefore) {
				self.snapshot.insertSections(withIdentifiers: [sectionIdentifierforController], afterSectionWithIdentifier: sectionIdentifierBefore)
			} else if let sectionIdentifierAfter = getSectionIdentifier(after: controller), snapshotContains(self.snapshot, sectionIdentifier: sectionIdentifierAfter) {
				self.snapshot.insertSections(withIdentifiers: [sectionIdentifierforController], beforeSectionWithIdentifier: sectionIdentifierAfter)
			} else {
				self.snapshot.appendSections(withIdentifiers: [sectionIdentifierforController])
			}
			let itemIdentifiers = snapshot.itemIdentifiersInSection(withIdentifier: sectionIdentifier)
			self.snapshot.appendItems(withIdentifiers: itemIdentifiers, intoSectionWithIdentifier: sectionIdentifierforController)
		}
		delegate?.controller?(self, didChangeContentWith: self.snapshot)
	}

	public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		delegate?.controllerDidChangeContent?(self)
	}
}
