#import "ENRMImageStore.h"

@implementation ENRMImageEntry

+ (instancetype)entryWithPosition:(NSUInteger)position
                              url:(NSString *)url
                              alt:(NSString *)alt
                            width:(CGFloat)width
                           height:(CGFloat)height
                         isInline:(BOOL)isInline
{
  ENRMImageEntry *entry = [[ENRMImageEntry alloc] init];
  entry.position = position;
  entry.url = url;
  entry.alt = alt;
  entry.width = width;
  entry.height = height;
  entry.isInline = isInline;
  return entry;
}

@end

@implementation ENRMImageStore {
  NSMutableArray<ENRMImageEntry *> *_entries;
}

- (instancetype)init
{
  if (self = [super init]) {
    _entries = [NSMutableArray array];
  }
  return self;
}

- (NSArray<ENRMImageEntry *> *)allEntries
{
  return [_entries copy];
}

- (void)addEntry:(ENRMImageEntry *)entry
{
  NSUInteger insertAt = 0;
  for (NSUInteger i = 0; i < _entries.count; i++) {
    if (_entries[i].position == entry.position) {
      _entries[i] = entry;
      return;
    }
    if (_entries[i].position > entry.position)
      break;
    insertAt = i + 1;
  }
  [_entries insertObject:entry atIndex:insertAt];
}

- (void)removeEntryAtPosition:(NSUInteger)position
{
  for (NSUInteger i = 0; i < _entries.count; i++) {
    if (_entries[i].position == position) {
      [_entries removeObjectAtIndex:i];
      return;
    }
  }
}

- (nullable ENRMImageEntry *)entryAtPosition:(NSUInteger)position
{
  for (ENRMImageEntry *entry in _entries) {
    if (entry.position == position) {
      return entry;
    }
  }
  return nil;
}

- (void)clearAll
{
  [_entries removeAllObjects];
}

- (void)adjustForEditAtLocation:(NSUInteger)editLocation
                  deletedLength:(NSUInteger)deletedLength
                 insertedLength:(NSUInteger)insertedLength
{
  if (deletedLength == 0 && insertedLength == 0)
    return;

  NSUInteger deleteEnd = editLocation + deletedLength;
  NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];

  for (NSUInteger i = 0; i < _entries.count; i++) {
    ENRMImageEntry *entry = _entries[i];
    NSUInteger pos = entry.position;

    if (deletedLength > 0) {
      if (pos >= editLocation && pos < deleteEnd) {
        [indexesToRemove addIndex:i];
      } else if (pos >= deleteEnd) {
        entry.position = pos - deletedLength + insertedLength;
      }
    } else {
      if (pos >= editLocation) {
        entry.position = pos + insertedLength;
      }
    }
  }

  [indexesToRemove enumerateIndexesWithOptions:NSEnumerationReverse
                                    usingBlock:^(NSUInteger idx, BOOL *stop) { [_entries removeObjectAtIndex:idx]; }];
}

@end
