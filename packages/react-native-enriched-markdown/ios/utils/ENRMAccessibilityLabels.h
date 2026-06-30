#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ENRMAccessibilityLabels : NSObject

@property (nonatomic, copy) NSString *bulletPoint;
@property (nonatomic, copy) NSString *nestedBulletPoint;
@property (nonatomic, copy) NSString *orderedItem;
@property (nonatomic, copy) NSString *nestedOrderedItem;
@property (nonatomic, copy) NSString *blockquote;
@property (nonatomic, copy) NSString *nestedBlockquote;
@property (nonatomic, copy) NSString *tableRow;
@property (nonatomic, copy) NSString *mathEquation;
@property (nonatomic, copy) NSString *rotorHeadings;
@property (nonatomic, copy) NSString *rotorLinks;
@property (nonatomic, copy) NSString *rotorImages;

@end

NS_ASSUME_NONNULL_END
