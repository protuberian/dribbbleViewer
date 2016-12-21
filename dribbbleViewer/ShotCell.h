//
//  ShotCell.h
//  dribbbleViewer
//
//  Created by iMac21 on 21.12.16.
//  Copyright © 2016 jetruby. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ShotCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UIImageView *image;
@property (nonatomic, strong) IBOutlet UILabel *labelTitle;
@property (nonatomic, strong) IBOutlet UILabel *labelAbout;

@end
