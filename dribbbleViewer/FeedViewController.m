//
//  FeedViewController.m
//  dribbbleViewer
//
//  Created by iMac21 on 21.12.16.
//  Copyright © 2016 jetruby. All rights reserved.
//

#import "FeedViewController.h"
#import "DataManager.h"
#import "ShotCell.h"
#import <AFNetworking/UIImageView+AFNetworking.h>

@interface FeedViewController () <UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate>
@property (nonatomic, assign) NSUInteger currentPage;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) NSURLSessionDataTask *currentTask;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@end

@implementation FeedViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.navigationItem.title = @"App name";
  self.currentPage = 1;

  self.fetchedResultsController = [DribbbleShot MR_fetchAllSortedBy:@"uid" //не смог разобраться с сортировкой
                                                          ascending:NO
                                                      withPredicate:nil
                                                            groupBy:nil
                                                           delegate:self];

  self.refreshControl = [[UIRefreshControl alloc] init];
  self.refreshControl.backgroundColor = [UIColor whiteColor];
  self.refreshControl.tintColor = [UIColor blackColor];
  [self.refreshControl addTarget:self
                          action:@selector(reloadData)
                forControlEvents:UIControlEventValueChanged];

  [self.tableView addSubview:self.refreshControl];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  NSLog(@"prepareForSegue");
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self loadMore];
}

- (void)reloadData {
  if (!self.refreshControl.refreshing) {
    [self.refreshControl beginRefreshing];
  }
  [self.currentTask cancel];
  self.currentTask = nil;
  self.currentPage = 1;
  [self loadMore];
}

- (void)loadMore {
  if (([DribbbleShot MR_countOfEntities] >= maxShots) && (self.currentPage != 1)) {
    NSLog(@"cap %i entities",maxShots);
    return;
  }
  if (self.currentTask) {
    NSLog(@"currentTask incomplete");
    return;
  }
  __weak FeedViewController *weakself = self;
  self.currentTask = [[DataManager sharedManager] getShotsPage:self.currentPage callback:^(NSURLResponse *response, id responseObject, NSError *error) {
    weakself.currentTask = nil;
    [weakself.refreshControl endRefreshing];
    if (!error) {
      weakself.currentPage++;

      if ([[self.tableView indexPathsForVisibleRows] containsObject:[NSIndexPath indexPathForRow:self.fetchedResultsController.fetchedObjects.count-1 inSection:0]]) {
        [weakself loadMore];
      }
    } else {
      //TODO: show error, ask for reload
      [weakself performSelector:@selector(loadMore) withObject:nil afterDelay:2];
    }
  }];
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
  [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
  switch (type) {
    case NSFetchedResultsChangeInsert:
      [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationRight];
      break;
    case NSFetchedResultsChangeUpdate:
      [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
      break;
    case NSFetchedResultsChangeMove:
      if (![indexPath isEqual:newIndexPath]) {
        [self.tableView moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
      } else {
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
      }
      break;
    case NSFetchedResultsChangeDelete:
      [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
      break;

    default:
      break;
  }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
  switch (type) {
    case NSFetchedResultsChangeDelete:
      [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
      break;
    case NSFetchedResultsChangeInsert:
      [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
      break;
    default:
      NSAssert(NO, @"%s",__PRETTY_FUNCTION__);
      break;
  }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
  [self.tableView endUpdates];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.fetchedResultsController.fetchedObjects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  ShotCell *cell = [tableView dequeueReusableCellWithIdentifier:@"kShotCellId"];
  DribbbleShot *shot = self.fetchedResultsController.fetchedObjects[indexPath.row];

  NSString *url = shot.hidpi ? shot.hidpi : shot.normal;
  if (!url) {
    url = shot.teaser;
  }
  NSAssert(url != nil, @"can't find image for shot %@, %s",shot.uid, __PRETTY_FUNCTION__);
  [cell.image setImageWithURL:[NSURL URLWithString:url]];

  cell.image.layer.contentsScale = 0.7;
  cell.labelTitle.text = shot.title ? shot.title : @"No title";

  NSString *description = shot.about ? shot.about : @"No description";

  NSRange range;//dirty way to remove tags
  while ((range = [description rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
    description = [description stringByReplacingCharactersInRange:range withString:@""];
  cell.labelAbout.text = description;

  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  DribbbleShot *shot = self.fetchedResultsController.fetchedObjects[indexPath.row];
  CGFloat bestHeight = shot.height;

  CGFloat aspect = (CGFloat)shot.width/(CGFloat)shot.height;
  CGFloat maxWidth = [UIScreen mainScreen].bounds.size.width;
  CGFloat maxHeight = [UIScreen mainScreen].bounds.size.height/2;

  CGSize targetSize = CGSizeMake(maxWidth, maxWidth/aspect);
  if (targetSize.height > maxHeight) {
    targetSize = CGSizeMake(maxHeight*aspect, maxHeight);
  }
  if (targetSize.height > bestHeight) {
    targetSize = CGSizeMake(bestHeight*aspect, bestHeight);
  }
  return targetSize.height;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row >= self.fetchedResultsController.fetchedObjects.count-1) {
    [self loadMore];
  }
}

@end
