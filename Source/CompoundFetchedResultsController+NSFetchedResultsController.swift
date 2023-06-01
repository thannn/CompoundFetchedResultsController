//
//  CompoundFetchedResultsController+NSFetchedResultsController.swift
//  CompoundFetchedResultsController
//
//  Created by David Jennes on 27/12/16.
//  Copyright © 2016. All rights reserved.
//

import CoreData
import UIKit

extension CompoundFetchedResultsController: NSFetchedResultsControllerDelegate {
	public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		delegate?.controllerWillChangeContent?(self)
	}

	public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
		delegate?.controller?(self, didChange: sectionInfo, atSectionIndex: sectionIndex + offsets[controller]!, for: type)
	}

	public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
		let old = indexPath.flatMap { IndexPath(item: $0.item, section: $0.section + offsets[controller]!) }
		let new = newIndexPath.flatMap { IndexPath(item: $0.item, section: $0.section + offsets[controller]!) }

		delegate?.controller?(self, didChange: anObject, at: old, for: type, newIndexPath: new)
	}

	public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		offsets = CompoundFetchedResultsController.calculateSectionOffsets(controllers: controllers)
		delegate?.controllerDidChangeContent?(self)
	}

	@available(iOS 13.0, *)
	public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
		delegate?.controller?(controller, didChangeContentWith: snapshot)
	}

	public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, sectionIndexTitleForSectionName sectionName: String) -> String? {
		return delegate?.controller?(self, sectionIndexTitleForSectionName: sectionName)
	}
}
