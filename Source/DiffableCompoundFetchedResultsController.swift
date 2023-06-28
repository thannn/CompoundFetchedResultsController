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

	public typealias DiffableCompoundSectionID = String
	public typealias DiffableCompoundSection = (sectionIdentifier: DiffableCompoundSectionID, sectionController: NSFetchedResultsController<NSFetchRequestResult>)

	// MARK: - Properties

	public override var cacheName: String? { nil }
	public override var fetchRequest: NSFetchRequest<NSFetchRequestResult> { .init() }
	public override var managedObjectContext: NSManagedObjectContext { compoundSections.first!.sectionController.managedObjectContext }
	public override var sectionNameKeyPath: String? { nil }

	private let compoundSections: [DiffableCompoundSection]
	private var compoundSnapshots: [DiffableCompoundSectionID: NSDiffableDataSourceSnapshotReference] = [:] // `NSDiffableDataSourceSnapshotReference` type needed in `NSFetchedResultsControllerDelegate`
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
		guard let sectionIdentifier = compoundSections.first(where: { $0.sectionController === controller })?.sectionIdentifier else { return }
		var sectionSnapshot: NSDiffableDataSourceSnapshotReference = .init()
		sectionSnapshot.appendSections(withIdentifiers: [sectionIdentifier])
		sectionSnapshot.appendItems(withIdentifiers: snapshot.itemIdentifiers, intoSectionWithIdentifier: sectionIdentifier)
		compoundSnapshots[sectionIdentifier] = sectionSnapshot
		sortSnapshotsAndNotifyDelegate()
	}

	public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		delegate?.controllerDidChangeContent?(self)
	}

	// MARK: - Helpers

	private func sortSnapshotsAndNotifyDelegate() {
		let sortedSnapshots = compoundSnapshots.sorted { lhs, rhs in
			guard let lhsIndex = compoundSections.firstIndex(where: { $0.sectionIdentifier == lhs.key }) else { return true }
			guard let rhsIndex = compoundSections.firstIndex(where: { $0.sectionIdentifier == rhs.key }) else { return true }
			return lhsIndex < rhsIndex
		}
		// not merging the snapshots in 1 single snapshot, as it would disable the possilibity for the same item to occur in different sections
		sortedSnapshots.forEach { delegate?.controller?(self, didChangeContentWith: $0.value) }
	}
}
