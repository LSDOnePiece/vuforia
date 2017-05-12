/*===============================================================================
Copyright (c) 2012-2015 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of PTC Inc., registered in the United States and other 
countries.
===============================================================================*/


#import <UIKit/UIKit.h>

@class Book;
@class StarRatingView;

@interface TargetOverlayView : UIView
{
}

@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *authorsLabel;
@property (nonatomic, strong) IBOutlet UILabel *ratingsLabel;
@property (nonatomic, strong) IBOutlet UILabel *priceLabel;
@property (nonatomic, strong) IBOutlet UILabel *oldPriceLabel;
@property (nonatomic, strong) IBOutlet UIImageView *bookCoverImageView;
@property (nonatomic, strong) IBOutlet UIView *priceContainerView;
@property (nonatomic, strong) IBOutlet StarRatingView *starRatingView;

- (void)setBook:(Book *)book;

@end
