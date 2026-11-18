/* Magnification: the icons grow under the pointer.  Measured on the real Dock (Mac VM 26.7.2, 1280 x 800, tile size 46, largesize 80, accessibility tree with the pointer at five positions on the bar; docs/development/DOCK-ANIMATIONS.md):
 * the slot of an item (what the accessibility tree gives as the distance between two items) is 49.9 at rest and 83.6 under the pointer, as a function of the distance d between the pointer and the item's centre at rest:
 *     slot(d) = 49.9 + (83.6 - 49.9) * g(d),  g(d) = (1 + cos(pi * (d / 175) ^ 1.2)) / 2 for d < 175, else 0     (fitted, error < 0.6 px on 31 points)
 * the icon is tile + (large - tile) * g(d) wide and keeps its bottom on the bar's baseline; separators grow by 0.415 of the same amount; the item under the pointer keeps the pointer at the same fraction of its slot
 * (anchor rule: model within 0.7 px of the real items for pointer positions 100 ... 900); the bar grows with the slots and stays as high as it was; the icons overflow it upwards.
 * SCAFFOLDING: the pointer is polled at 60 Hz (the real Dock gets it from SkyLight events). The grow on entering and the shrink on leaving are eased (about 0.1 s): the real timing is not measured yet. */
#import <Foundation/Foundation.h>
@class DockController;
@interface DockMagnify : NSObject
- (instancetype)initWithController:(DockController *)controller;
- (void)modelChanged;
@property (readonly) CGFloat strength;          /* 0 at rest ... 1 fully magnified */
@end
