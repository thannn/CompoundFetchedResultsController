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
	// MARK: - Types

	public typealias DiffableCompoundSection = (sectionIdentifier: String, sectionController: NSFetchedResultsController<NSFetchRequestResult>)

	// MARK: - Properties

	public override var cacheName: String? { nil }
	public override var fetchRequest: NSFetchRequest<NSFetchRequestResult> { .init() }
	public override var managedObjectContext: NSManagedObjectContext { compoundSections.first!.sectionController.managedObjectContext }
	public override var sectionNameKeyPath: String? { nil }

	private let compoundSections: [DiffableCompoundSection]
	private var snapshot: NSDiffableDataSourceSnapshotReference = .init()
	private var controllers: [NSFetchedResultsController<NSFetchRequestResult>] {
		compoundSections.map { $0.sectionController }
	}

	// MARK: - Lifecycle

	/// Initializer when section identifiers don't need to be fixed.
	public init(controllers: [NSFetchedResultsController<NSFetchRequestResult>]) {
		compoundSections = controllers.map { (UUID().uuidString, $0) }
		super.init()
		setDelegates()
	}

	/// Initializer when section identifiers need to be fixed.
	public init(sections: [DiffableCompoundSection]) {
		compoundSections = sections
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

	// MARK: - NSFetchedResultsControllerDelegate

	public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		delegate?.controllerWillChangeContent?(self)
	}

	public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
		var modifiedSnapshot: NSDiffableDataSourceSnapshotReference = .init()
		compoundSections.forEach { (sectionIdentifier: String, sectionController: NSFetchedResultsController<NSFetchRequestResult>) in
			if sectionController == controller {
				snapshot.sectionIdentifiers.forEach {
					modifiedSnapshot.appendSections(withIdentifiers: [sectionIdentifier])
					modifiedSnapshot.appendItems(withIdentifiers: snapshot.itemIdentifiersInSection(withIdentifier: $0), intoSectionWithIdentifier: sectionIdentifier)
				}
			} else {
				modifiedSnapshot.appendSections(withIdentifiers: [sectionIdentifier])
				if self.snapshot.hasSection(withSectionIdentifier: sectionIdentifier) {
					modifiedSnapshot.appendItems(withIdentifiers: self.snapshot.itemIdentifiersInSection(withIdentifier: sectionIdentifier), intoSectionWithIdentifier: sectionIdentifier)
				}
			}
		}

		self.snapshot = modifiedSnapshot
		delegate?.controller?(self, didChangeContentWith: self.snapshot)
	}

	public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		delegate?.controllerDidChangeContent?(self)
	}
}

@available(iOS 13.0, *)
private extension NSDiffableDataSourceSnapshotReference {
	func hasSection(withSectionIdentifier sectionIdentifier: Any) -> Bool {
		index(ofSectionIdentifier: sectionIdentifier) != NSNotFound
	}
}
