//
//  DiffableCompoundFetchedResultsController.swift
//  CompoundFetchedResultsController
//
//  Created by Jonathan Provo on 27/04/2022.
//

import CoreData
import FetchedDataSource
import UIKit

@available(iOS 13.0, *)
public final class DiffableCompoundFetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>, NSFetchedResultsControllerDelegate {
	// MARK: - Types

	public typealias DiffableCompoundSectionID = String
	public typealias DiffableCompoundSection = (sectionIdentifier: DiffableCompoundSectionID, sectionController: NSFetchedResultsController<NSFetchRequestResult>)
	public enum DiffableCompoundUpdatePolicy {
		/// Submits updates immediately.
		case immediate
		/// Submits updates with a minimum delay.
		case debounce(delay: TimeInterval)
	}

	// MARK: - Properties

	public override var cacheName: String? { nil }
	public override var fetchRequest: NSFetchRequest<NSFetchRequestResult> { .init() }
	public override var managedObjectContext: NSManagedObjectContext { moc }
	public override var sectionNameKeyPath: String? { nil }

	private let compoundSections: [DiffableCompoundSection]
	private var compoundSnapshots: [DiffableCompoundSectionID: NSDiffableDataSourceSnapshot<String, NSObject>] = [:]
	private var controllers: [NSFetchedResultsController<NSFetchRequestResult>] {
		compoundSections.map { $0.sectionController }
	}

	private var debounceTimer: Timer?
	private let updatePolicy: DiffableCompoundUpdatePolicy
	private lazy var moc: NSManagedObjectContext = .init(concurrencyType: .mainQueueConcurrencyType)

	// MARK: - Lifecycle

	/// Initializer when section identifiers don't need to be fixed.
	public init(controllers: [NSFetchedResultsController<NSFetchRequestResult>], updatePolicy: DiffableCompoundUpdatePolicy = .immediate) {
		compoundSections = controllers.map { (UUID().uuidString, $0) }
		self.updatePolicy = updatePolicy
		super.init()
		setManagedObjectContext()
		setDelegates()
	}

	/// Initializer when section identifiers need to be fixed.
	public init(sections: [DiffableCompoundSection], updatePolicy: DiffableCompoundUpdatePolicy = .immediate) {
		compoundSections = sections
		self.updatePolicy = updatePolicy
		super.init()
		setManagedObjectContext()
		setDelegates()
	}

	deinit {
		debounceTimer?.invalidate()
	}

	// MARK: - NSFetchedResultsController

	public override func performFetch() throws {
		performFetches()
	}

	// MARK: - Controller management

	private func setManagedObjectContext() {
		guard let controller = controllers.first(where: { $0.managedObjectContext.parent != nil || $0.managedObjectContext.persistentStoreCoordinator != nil }) else { return }
		if let parent = controller.managedObjectContext.parent { moc.parent = parent }
		if let persistentStoreCoordinator = controller.managedObjectContext.persistentStoreCoordinator { moc.persistentStoreCoordinator = persistentStoreCoordinator }
	}
	
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
		guard let itemIdentifiers = snapshot.itemIdentifiers as? [NSObject] else { return }
		var sectionSnapshot: NSDiffableDataSourceSnapshot<String, NSObject> = .init()
		sectionSnapshot.appendSections([sectionIdentifier])
		sectionSnapshot.appendItems(itemIdentifiers, toSection: sectionIdentifier)
		compoundSnapshots[sectionIdentifier] = sectionSnapshot
		notifyDelegate()
	}

	public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		delegate?.controllerDidChangeContent?(self)
	}

	// MARK: - Helpers

	private func notifyDelegate() {
		switch updatePolicy {
		case .immediate:
			doNotifyDelegate()
		case .debounce(let delay):
			debounceTimer?.invalidate()
			debounceTimer = Timer.scheduledTimer(timeInterval: max(0.1, delay), target: self, selector: #selector(doNotifyDelegate), userInfo: nil, repeats: false)
		}
	}

	@objc
	private func doNotifyDelegate() {
		let sortedSnapshots = compoundSnapshots.sorted { lhs, rhs in
			guard let lhsIndex = compoundSections.firstIndex(where: { $0.sectionIdentifier == lhs.key }) else { return true }
			guard let rhsIndex = compoundSections.firstIndex(where: { $0.sectionIdentifier == rhs.key }) else { return true }
			return lhsIndex < rhsIndex
		}

		let snapshot: NSDiffableDataSourceSnapshotReference = .init()
		sortedSnapshots.forEach { compoundSnapshot in
			snapshot.appendSections(withIdentifiers: [compoundSnapshot.key])
			snapshot.appendItems(withIdentifiers: compoundSnapshot.value.itemIdentifiers.map { FetchedDiffableItem(item: $0, sectionIdentifier: compoundSnapshot.key) }, intoSectionWithIdentifier: compoundSnapshot.key)
		}
		
		delegate?.controller?(self, didChangeContentWith: snapshot)
	}
}
