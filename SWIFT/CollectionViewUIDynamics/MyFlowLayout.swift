//
//  MyFlowLayout.swift
//  CollectionViewUIDynamics
//
//  Created by Andreas Neusüß on 29.03.15.
//  Copyright (c) 2015 Anerma. All rights reserved.
//

import UIKit

class MyFlowLayout: UICollectionViewFlowLayout {
    private var dynamicAnimator : UIDynamicAnimator!
    private var visibleIndexPaths : NSMutableSet = NSMutableSet()
    private var latestDelta : CGFloat!
    
    
    override init () {
        super.init()
        
        setUp()
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUp()
    }
    
    func setUp() {
        self.minimumInteritemSpacing = 20
        self.minimumLineSpacing = 20
        self.itemSize = CGSizeMake(44, 44)
        self.sectionInset = UIEdgeInsets(top: 20, left: 10, bottom: 10, right: 10)
        
        self.dynamicAnimator = UIDynamicAnimator(collectionViewLayout: self)
    }
    
    
    override func prepareLayout() {
        super.prepareLayout()
        
        // Need to overflow our actual visible rect slightly to avoid flickering.
        let visibleRect = CGRectInset(CGRect(origin: collectionView!.bounds.origin, size: collectionView!.bounds.size), -100, -100)//rect to setup the behaviors in – bigger rect: more behaviors calculated. Can be used to fight against too fast scrolling.
        let itemsInVisibleRect = super.layoutAttributesForElementsInRect(visibleRect) as [UICollectionViewLayoutAttributes]
        
        
        //some dance to get the indexPath property from the itemsInVisibleRect (Array of UICollectionViewLayoutAttributes)
        let obj = itemsInVisibleRect as NSObject
        let arr = obj.valueForKey("indexPath") as NSArray
        let itemsIndexPathInVisibleRect = NSSet(array: arr)

        // Step 1: Remove any behaviours that are no longer visible.
        let noLongerVisibleBehaviors = dynamicAnimator.behaviors.filter( { (obj : AnyObject)->Bool in
            let behavior = obj as? UIAttachmentBehavior
            let item = behavior?.items.last as? UICollectionViewLayoutAttributes
            
            if let indexPathOfItem = item?.indexPath {
                let currentlyVisible : Bool = itemsIndexPathInVisibleRect.member(indexPathOfItem) != nil

                return !currentlyVisible
            }
            
            return false
        })
        
        //Remove the behaviors of cells that are not visible
        for (index, behavior : UIAttachmentBehavior) in enumerate(noLongerVisibleBehaviors as [UIAttachmentBehavior]) {
            dynamicAnimator.removeBehavior(behavior)
            if let item = behavior.items.first as? UICollectionViewLayoutAttributes {
                visibleIndexPaths.removeObject(item.indexPath)
            }
        }
        
        // Step 2: Add any newly visible behaviours.
        // A "newly visible" item is one that is in the itemsInVisibleRect(Set|Array) but not in the visibleIndexPathsSet
        let newlyVisibleItems = itemsInVisibleRect.filter( { (item : AnyObject) -> Bool in
            let layoutAttribute = item as? UICollectionViewLayoutAttributes
            
            if let indexPath = layoutAttribute?.indexPath? {
                let contained : Bool = self.visibleIndexPaths.member(indexPath) != nil
                return !contained
            }
            return false
            
        })
        
        let touchLocation = collectionView!.panGestureRecognizer.locationInView(collectionView)
        
        for (index, item : UICollectionViewLayoutAttributes) in enumerate(newlyVisibleItems) {
            
            let springBehavior = UIAttachmentBehavior(item: item, attachedToAnchor: item.center)
            springBehavior.length = 0
            springBehavior.damping = 0.8
            springBehavior.frequency = 1
            
            // If our touchLocation is not (0,0), we'll need to adjust our item's center "in flight"
            if !CGPointEqualToPoint(CGPointZero, touchLocation) {
                let xDistanceFromTouch : CGFloat = fabs(touchLocation.x - springBehavior.anchorPoint.x)
                let yDistanceFromTouch : CGFloat = fabs(touchLocation.y - springBehavior.anchorPoint.y)
                let scrollResistance : CGFloat = (yDistanceFromTouch + xDistanceFromTouch) / 1500.0
                
                if latestDelta < 0 {
                    item.center.y += max(latestDelta, latestDelta * scrollResistance)
                }
                else {
                    item.center.y += min(latestDelta, latestDelta * scrollResistance)
                }
                
            }
            
            dynamicAnimator.addBehavior(springBehavior)
            visibleIndexPaths.addObject(item.indexPath)
            
            
        }
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]? {
        return dynamicAnimator.itemsInRect(rect)
    }
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        return dynamicAnimator.layoutAttributesForCellAtIndexPath(indexPath)
    }
    
    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        let delta = newBounds.origin.y - collectionView!.bounds.origin.y
        
        latestDelta = delta
        
        let locationOfTouch = collectionView!.panGestureRecognizer.locationInView(collectionView)
        
        for (index, springBehavior : UIAttachmentBehavior) in enumerate(dynamicAnimator.behaviors as [UIAttachmentBehavior]) {
            let yDistanceFromTouch = fabs(locationOfTouch.y - springBehavior.anchorPoint.y)
            let xDistanceFromTouch = fabs(locationOfTouch.x - springBehavior.anchorPoint.x)
            
            let scrollResistance = (yDistanceFromTouch + xDistanceFromTouch) / 1500.0
            
            let item = springBehavior.items.first as UICollectionViewLayoutAttributes
            
            if delta < 0 {
                item.center.y += max(delta, delta * scrollResistance)
            }
            else {
                item.center.y -= max(delta, delta + scrollResistance)
            }
            
            dynamicAnimator.updateItemUsingCurrentState(item)
        }
        
        return false
    }
}
