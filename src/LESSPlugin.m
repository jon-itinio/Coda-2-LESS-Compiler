#import "LESSPlugin.h"
#import "CodaPlugInsController.h"
#import "DDLog.h"
#import "DDASLLogger.h"
#import "FileView.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface LESSPlugin ()

- (id)initWithController:(CodaPlugInsController*)inController;

@end


@implementation LESSPlugin

//2.0 and lower
- (id)initWithPlugInController:(CodaPlugInsController*)aController bundle:(NSBundle*)aBundle
{
    return [self initWithController:aController];
}


//2.0.1 and higher
- (id)initWithPlugInController:(CodaPlugInsController*)aController plugInBundle:(NSObject <CodaPlugInBundle> *)p
{
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    return [self initWithController:aController andPlugInBundle:p];
}

- (id)initWithController:(CodaPlugInsController*)inController andPlugInBundle:(NSObject <CodaPlugInBundle> *)p
{
    if ( (self = [super init]) != nil )
	{
		controller = inController;
	}
    plugInBundle = p;
    bundle = [NSBundle bundleWithIdentifier:[p bundleIdentifier]];
    [self registerActions];
    [self setupDb];
	return self;
}

- (id)initWithController:(CodaPlugInsController*)inController
{
	if ( (self = [super init]) != nil )
	{
		controller = inController;
	}
    
    [self registerActions];
	return self;
}

-(void) registerActions
{
    [controller registerActionWithTitle:@"Site Settings" underSubmenuWithTitle:@"top menu" target:self selector:@selector(openSitesMenu) representedObject:nil keyEquivalent:nil pluginName:@"LESS Compiler"];
    [controller registerActionWithTitle:@"Preferences" underSubmenuWithTitle:@"top menu" target:self selector:@selector(openPreferencesMenu) representedObject:nil keyEquivalent:nil pluginName:@"LESS Compiler"];
    
}

-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    return true;
}

- (NSString*)name
{
	return @"LESS Compiler";
}

-(void)textViewWillSave:(CodaTextView *)textView
{
    NSString *path = [textView path];
    if ([path length]) {
        NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
        if ([[url pathExtension] isEqualToString:@"less"]) {
            
            [self handleLessFile:textView];
            
        }
    }
}

#pragma mark - Menu methods

-(void) openSitesMenu
{
    [NSBundle loadNibNamed:@"siteSettingsWindow" owner: self];
    fileDocumentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 500)];
    [self.fileScrollView setDocumentView:fileDocumentView];
    [self rebuildFileList];
}

-(void) openPreferencesMenu
{
    [NSBundle loadNibNamed:@"preferencesWindow" owner: self];
    [self.LESSVersionField setStringValue:@"1.4.2"];
    [self.versionField setStringValue:@"0.1"];
    
    if(prefs == nil)
    {
        return;
    }
    
    DDLogVerbose(@"LESS:: setting up preference window");
    for(NSButton * b in [self.preferenceWindow subviews])
    {
        if([b isKindOfClass:[NSButton class]] && [b valueForKey:@"prefKey"] != nil)
        {
            NSString * prefKey = [b valueForKey:@"prefKey"];
            NSNumber * val = [prefs objectForKey:prefKey];
            DDLogVerbose(@"LESS:: Preference: %@ : %@", prefKey, val);
            if(val != nil)
            {
                [b setState:[val integerValue]];
            }
        }
    }
}

-(NSURL *) getFileNameFromUser
{
    NSURL * chosenFile = nil;
    // Create the File Open Dialog class.
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles:YES];
    
    // Multiple files not allowed
    [openDlg setAllowsMultipleSelection:NO];
    
    // Can't select a directory
    [openDlg setCanChooseDirectories:NO];
    
    // Display the dialog. If the OK button was pressed,
    // process the files.
    if ( [openDlg runModal] == NSOKButton )
    {
        // Get an array containing the full filenames of all
        // files and directories selected.
        NSArray* files = [openDlg URLs];
        
        // Loop through all the files and process them.
        for(NSURL * url in files)
        {
            chosenFile = url;
        }
    }
    return chosenFile;
}

-(NSURL *) getSavenameFromUser
{
    NSURL * chosenFile = nil;
    // Create the File Open Dialog class.
    NSSavePanel* saveDlg = [NSSavePanel savePanel];
    [saveDlg setCanCreateDirectories:TRUE];

    if ( [saveDlg runModal] == NSOKButton )
    {
        chosenFile = [saveDlg URL];
    }
    return chosenFile;
}

-(void) rebuildFileList
{
    DDLogVerbose(@"LESS:: rebuildFileList");
    DDLogVerbose(@"LESS:: subviews address: %p", [fileDocumentView subviews]);
    [fileDocumentView setSubviews:[NSArray array]];

    DDLogVerbose(@"LESS: rebuild 1");
    fileViews = [NSMutableArray array];
    NSRect fRect;
    
    [fileDocumentView setFrame:NSMakeRect(0, 0, 583, MAX( (111 * currentParentFilesCount), self.fileScrollView.frame.size.height - 10))];

    DDLogVerbose(@"LESS: rebuild 2");
    for(int i = currentParentFilesCount - 1; i >= 0; i--)
    {
        NSDictionary * currentFile = [currentParentFiles objectAtIndex:i];
        DDLogVerbose(@"LESS: rebuild 3");
        
        NSArray *nibObjects = [NSArray array];
        if(![bundle loadNibNamed:@"FileView" owner:self topLevelObjects:&nibObjects])
        {
            DDLogError(@"LESS:: couldn't load FileView nib...");
            return;
        }
        
        FileView * f;
        for(FileView * o in nibObjects)
        {
            if([o isKindOfClass:[FileView class]])
            {
                f = o;
                break;
            }
        }
        fRect = f.frame;
        
        
         NSURL * url = [NSURL fileURLWithPath:[currentFile objectForKey:@"path"] isDirectory:NO];
        [f.fileName setStringValue:[url lastPathComponent]];
        [f.lessPath setStringValue:[currentFile objectForKey:@"path"]];
        [f.cssPath setStringValue:[currentFile objectForKey:@"css_path"]];
        [f.shouldMinify setState:[[currentFile objectForKey:@"minify"] intValue]];
        
        [f.deleteButton setAction:@selector(deleteParentFile:)];
        [f.deleteButton setTarget:self];
        [f.changeCssPathButton setAction:@selector(changeCssFile:)];
        [f.changeCssPathButton setTarget:self];
        [f.shouldMinify setAction:@selector(changeMinify:)];
        [f.shouldMinify setTarget:self];
        
		f.fileIndex = i;
        float frameY = currentParentFilesCount > 3 ? i * fRect.size.height : (fileDocumentView.frame.size.height - ((currentParentFilesCount - i) * fRect.size.height));
        [f setFrame:NSMakeRect(0, frameY, fRect.size.width, fRect.size.height)];
        [fileViews addObject:f];
        DDLogVerbose(@"LESS: rebuild 4");
    	[fileDocumentView addSubview:f];
    }
}
#pragma mark - database methods

-(void) setupDb
{
    dbQueue = [FMDatabaseQueue databaseQueueWithPath:[[plugInBundle resourcePath] stringByAppendingString:@"/db.sqlite"]];
    
    [dbQueue inDatabase:^(FMDatabase *db) {
		FMResultSet * prefSet = [db executeQuery:@"SELECT * FROM preferences"];
        if([prefSet next])
        {
            prefs = [[NSJSONSerialization JSONObjectWithData:[[prefSet stringForColumn:@"json"] dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil] mutableCopy];
            DDLogVerbose(@"LESS:: prefs: %@", prefs);
        }
        else
        {
            DDLogVerbose(@"LESS:: no preferences found!");
            prefs = [NSMutableDictionary dictionaryWithObjectsAndKeys: nil];
        }
    }];
    [self updateParentFilesListWithCompletion:nil];
}



-(void) updateParentFilesListWithCompletion:(void(^)(void))handler;
{
    [dbQueue inDatabase:^(FMDatabase *db) {
        DDLogVerbose(@"LESS:: updateParentFilesWithCompletion");
        FMResultSet * d = [db executeQuery:@"SELECT * FROM less_files WHERE parent_id == -1"];
        if(currentParentFiles == nil)
        {
            currentParentFiles = [NSMutableArray array];
        }
        else
        {
            [currentParentFiles removeAllObjects];
        }
		while([d next])
        {
            [currentParentFiles addObject:[d resultDictionary]];
        }
        
        FMResultSet *s = [db executeQuery:@"SELECT COUNT(*) FROM less_files WHERE parent_id == -1"];
        if ([s next])
        {
            currentParentFilesCount = [s intForColumnIndex:0];
        }
        
        if(handler != nil)
        {
            handler();
        }
    }];
}

-(void) updatePreferenceNamed:(NSString *)pref withValue:(id)val
{
    [dbQueue inDatabase:^(FMDatabase *db) {
        [prefs setObject:val forKey:pref];
		NSData * jData = [NSJSONSerialization dataWithJSONObject:prefs options:kNilOptions error:nil];
        [db executeUpdate:@"UPDATE preferences SET json = :json WHERE id == 1" withParameterDictionary:@{@"json" : jData}];
    }];
}
-(FMResultSet *) getRegisteredFilesForSite:(NSString *) siteName
{
    DDLogVerbose(@"LESS:: getting registered files for site: %@", siteName);
    __block FMResultSet * ret;
    [dbQueue inDatabase:^(FMDatabase *db) {
       ret = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM less_files WHERE site_id == '%@'", siteName]];
    }];
    
    return ret;
}

-(NSString *) getResourceIdFromURL:(NSURL *)url
{
    NSString * r;
	NSError * error;
    [url getResourceValue:&r forKey:NSURLFileResourceIdentifierKey error:&error];
    if(error)
    {
        DDLogError(@"LESS:: Error getting file resource id: %@", error);
        return nil;
    }
    return r;
}

-(NSString *) getResolvedPathForPath:(NSString *)path
{
    NSURL * url = [NSURL fileURLWithPath:path];
    url = [NSURL URLWithString:[url absoluteString]];	//absoluteString returns path in file:// format
	NSString * newPath = [[url URLByResolvingSymlinksInPath] path];	//URLByResolvingSymlinksInPath expects file:// format for link, then resolves all symlinks
    DDLogVerbose(@"LESS:: Converted from: %@ \n to: %@", path, newPath);
    return newPath;
}


-(void) registerFile:(NSURL *)url
{
    if(url == nil)
    {
        return;
    }
    
    NSString * fileName = [self getResolvedPathForPath:[url path]];
    NSString *cssFile = [fileName stringByReplacingOccurrencesOfString:[url lastPathComponent] withString:[[url lastPathComponent] stringByReplacingOccurrencesOfString:@"less" withString:@"css"]];
    [dbQueue inDatabase:^(FMDatabase *db) {
        DDLogVerbose(@"LESS:: registerFile");
        if(![db executeUpdate:@"DELETE FROM less_files WHERE path = :path" withParameterDictionary:@{@"path" : fileName}])
        {
            DDLogError(@"LESS:: Whoa, big problem trying to delete sql rows");
        }
        
        NSDictionary * args = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:0], @"minify", cssFile, @"css_path", fileName, @"path", [NSNumber numberWithInteger:-1], @"parent_id", nil];

        if(![db executeUpdate:@"INSERT OR REPLACE INTO less_files (minify, css_path, path, parent_id) VALUES (:minify, :css_path, :path, :parent_id)"
    			withParameterDictionary:args ])
        {
			DDLogError(@"LESS:: SQL ERROR: %@", [db lastError]);
            return;
        }
        DDLogVerbose(@"LESS:: Inserted registered file");
        [self performSelectorOnMainThread:@selector(performDependencyCheckOnFile:) withObject:fileName waitUntilDone:FALSE];
    }];
}

-(void) unregisterFile:(NSURL *)url
{
    NSString * fileName = [self getResolvedPathForPath:[url path]];
    [dbQueue inDatabase:^(FMDatabase *db) {
    	FMResultSet * parentFile = [db executeQuery:@"SELECT * FROM less_files WHERE path == :path" withParameterDictionary:@{@"path":fileName}];
        if(![parentFile next])
        {
            DDLogVerbose(@"LESS:: unregisterFile: file %@ not found in db", fileName);
            return;
        }
        
        int parentFileId = [parentFile intForColumn:@"id"];
        [db executeUpdate:@"DELETE FROM less_files WHERE parent_id == :parent_id" withParameterDictionary:@{@"parent_id" : [NSNumber numberWithInt:parentFileId]}];
        
        [db executeUpdate:@"DELETE FROM less_files WHERE id == :id" withParameterDictionary:@{@"id" : [NSNumber numberWithInt:parentFileId]}];
        DDLogVerbose(@"LESS:: unregisterFile: unregistered file %@", fileName);
        [parentFile close];
    }];
}

-(void) setCssPath:(NSURL *)cssUrl forPath:(NSURL *)url
{
    NSString * fileName = [self getResolvedPathForPath:[url path]];
    NSString * cssFileName = [self getResolvedPathForPath:[cssUrl path]];
    [dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * parentFile = [db executeQuery:@"SELECT * FROM less_files WHERE path == :path" withParameterDictionary:@{@"path":fileName}];
        if(![parentFile next])
        {
            DDLogVerbose(@"LESS:: setCssPath: file %@ not found in db", fileName);
            return;
        }
		if([db executeUpdate:@"UPDATE less_files SET css_path == :css_path WHERE id == :id" withParameterDictionary:@{@"css_path":cssFileName, @"id": [NSNumber numberWithInt:[parentFile intForColumn:@"id"]]}])
        {
        	DDLogVerbose(@"LESS:: setCssPath: successfully set css path for file %@", fileName);
        }
        else
        {
            DDLogError(@"LESS:: setCssPath: error, %@",[db lastError]);
        }
        [parentFile close];
    }];
}

-(void) setLessFilePreference:(NSString *)pref toValue:(id)val forPath:(NSURL *) url
{
    NSString * fileName = [self getResolvedPathForPath:[url path]];
    [dbQueue inDatabase:^(FMDatabase *db) {
        if([db executeUpdate:[NSString stringWithFormat:@"UPDATE less_files SET %@ == :val WHERE path == :path", pref] withParameterDictionary:@{@"val": val, @"path" : fileName}])
        {
            DDLogVerbose(@"LESS:: setLessFilePreferences: successfully updated preference for %@", fileName);
        }
        else
        {
            DDLogError(@"LESS:: setLessFilePreferences: error: %@", [db lastError]);
        }
    }];
}

-(void) performDependencyCheckOnFile:(NSString *)path
{
    DDLogVerbose(@"LESS:: Performing dependency check on %@", path);

    [dbQueue inDatabase:^(FMDatabase *db) {
        
        FMResultSet * parent = [db executeQuery:@"SELECT * FROM less_files WHERE path = :path" withParameterDictionary:[NSDictionary dictionaryWithObjectsAndKeys:path, @"path", nil]];
        if(![parent next])
        {
            DDLogError(@"LESS:: Parent file not found in db!");
            return;
        }
        
        int parentId = [parent intForColumn:@"id"];
        [parent close];
        
        indexTask = [[NSTask alloc] init];
        indexPipe = [[NSPipe alloc]  init];
        
        NSString * lessc = [NSString stringWithFormat:@"%@/less/bin/lessc", [plugInBundle resourcePath]];
        
        indexTask.launchPath = [NSString stringWithFormat:@"%@/node", [plugInBundle resourcePath]];
        indexTask.arguments = @[lessc, @"--depends", path, @"DEPENDS"];
        
        indexTask.standardOutput = indexPipe;
        
        [[indexPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
        [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadToEndOfFileCompletionNotification object:[indexPipe fileHandleForReading] queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        
            NSData *output = [[notification userInfo ] objectForKey:@"NSFileHandleNotificationDataItem"];
            NSString *outStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
            NSError * error;
            outStr = [outStr stringByReplacingOccurrencesOfString:@"DEPENDS: " withString:@""];
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(/.*?\.less)" options:nil error:&error];
            NSArray * dependencies = [regex matchesInString:outStr options:nil range:NSMakeRange(0, [outStr length])];
            
            [dbQueue inDatabase:^(FMDatabase *db) {
                if(![db executeUpdate:@"DELETE FROM less_files WHERE parent_id = :parent_id" withParameterDictionary:@{@"parent_id": [NSNumber numberWithInteger:parentId]}])
                {
                    DDLogError(@"LESS:: Whoa, big problem deleting old files");
                }
            }];
            for(NSTextCheckingResult * ntcr in dependencies)
            {
                NSString * fileName =   [self getResolvedPathForPath:[outStr substringWithRange:[ntcr rangeAtIndex:1]]];
                
                [dbQueue inDatabase:^(FMDatabase *db) {
                    NSDictionary * args = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:0], @"minify", @"", @"css_path", fileName, @"path", [NSNumber numberWithInteger:parentId], @"parent_id", nil];
                    
                    if([db executeUpdate:@"INSERT OR REPLACE INTO less_files (minify, css_path, path, parent_id) VALUES (:minify, :css_path, :path, :parent_id)" withParameterDictionary:args])
                    {
                        DDLogVerbose(@"LESS:: dependency update succeeded: %@", fileName);
                    }
                    else
                    {
                        DDLogError(@"LESS:: dependency update failed: %@", fileName);
                    }
                }];
            }
            
        }];
        
        [indexTask launch];
        
    }];
}


#pragma mark - LESS methods

-(void) handleLessFile:(CodaTextView *)textView
{

    NSString *path = [self getResolvedPathForPath:[textView path]];
    DDLogVerbose(@"LESS:: Handling file: %@", path);
    [dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * s = [db executeQuery:@"SELECT * FROM less_files WHERE path = :path" withParameterDictionary:@{@"path": path}];
        if([s next])
        {
            FMResultSet * parentFile = s;
            int parent_id = [parentFile intForColumn:@"parent_id"];
            DDLogVerbose(@"LESS:: initial parent_id: %d", parent_id);
            while(parent_id > -1)
            {
                parentFile = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM less_files WHERE id = %d", parent_id]];
                if([parentFile next])
                {
                    parent_id = [parentFile intForColumn:@"parent_id"];
                }
                DDLogVerbose(@"LESS:: next parent_id: %d", parent_id);
            }
            
			NSString * parentPath = [parentFile stringForColumn:@"path"];
            NSString *cssPath = [parentFile stringForColumn:@"css_path"];
            DDLogVerbose(@"LESS:: parent Path: %@", parentPath);
            DDLogVerbose(@"LESS:: css Path: %@", cssPath);
            [self performSelectorOnMainThread:@selector(performDependencyCheckOnFile:) withObject:parentPath waitUntilDone:false];
            
            NSMutableArray * options  = [NSMutableArray array];
        	if([parentFile intForColumn:@"minify"] == 1)
            {
                [options addObject:@"-x"];
            }
            [self compileFile:parentPath toFile:cssPath withOptions:options];
        }
        else
        {
            DDLogError(@"LESS:: No DB entry found for file: %@", path);
        }
    }];
    

}

-(void) compileFile:(NSString *)lessFile toFile:(NSString *)cssFile withOptions:(NSArray *)options
{
    
    DDLogVerbose(@"LESS:: Compiling file: %@ to file: %@", lessFile, cssFile);
    task = [[NSTask alloc] init];
    outputPipe = [[NSPipe alloc] init];
    errorPipe = [[NSPipe alloc]  init];
    outputText = [[NSString alloc] init];
    errorText = [[NSString alloc] init];
    NSString * lessc = [NSString stringWithFormat:@"%@/less/bin/lessc", [plugInBundle resourcePath]];
    NSMutableArray * arguments = [NSMutableArray array];
    [arguments addObject:lessc];
    [arguments addObject:@"--no-color"];
    if(options)
    {
        for(NSString * arg in options)
        {
            [arguments addObject:arg];
        }
    }
    [arguments addObject:lessFile];
    [arguments addObject:cssFile];
    
    task.launchPath = [NSString stringWithFormat:@"%@/node", [plugInBundle resourcePath]];
    task.arguments = arguments;
    task.standardOutput = outputPipe;
    
    [[outputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getOutput:) name:NSFileHandleReadToEndOfFileCompletionNotification object:[outputPipe fileHandleForReading]];
    
    task.standardError = errorPipe;
    [[errorPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getError:) name:NSFileHandleReadToEndOfFileCompletionNotification object:[errorPipe fileHandleForReading]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidTerminate:) name:NSTaskDidTerminateNotification object:task];
    
    [task launch];
}


-(void) taskDidTerminate:(NSNotification *) notification
{
    DDLogVerbose(@"LESS:: Task terminated with status: %d", task.terminationStatus);
    if(task.terminationStatus == 0)
    {
        if([[prefs objectForKey:@"displayOnSuccess"] intValue] == 1)
        {
            NSString * sound = nil;
            if([[prefs objectForKey:@"playOnSuccess"] intValue] == 1)
            {
                sound = NSUserNotificationDefaultSoundName;
            }
            
        	[self sendUserNotificationWithTitle:@"LESS:: Compiled Successfully!" sound:sound  andMessage:@"File compiled successfully!"];
        }
    }
}

-(void) getOutput:(NSNotification *) notification
{

    NSData *output = [[notification userInfo ] objectForKey:@"NSFileHandleNotificationDataItem"];
    NSString *outStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
	DDLogVerbose(@"LESS:: getOutput: %@",outStr);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        outputText = [outputText stringByAppendingString: outStr];
    });
    
    if([task isRunning])
    {
        [[outputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    }
}


-(void) getError:(NSNotification *) notification
{
    
    NSData *output = [[notification userInfo ] objectForKey:@"NSFileHandleNotificationDataItem"];
    NSString *outStr = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    if([outStr isEqualToString:@""])
    {
        return;
    }
    DDLogError(@"LESS:: Encountered some error: %@", outStr);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary * error = [self getErrorMessage:outStr];
        if(error != nil)
        {
            if([[prefs objectForKey:@"displayOnError"] integerValue] == 1)
            {
                NSString * sound = nil;
                if([[prefs objectForKey:@"playOnError"] integerValue] == 1)
                {
                    sound = @"Basso";
                }
                
                [self sendUserNotificationWithTitle:@"LESS:: Parse Error" sound:sound andMessage:[error objectForKey:@"errorMessage"]];
            }
            
            if([[prefs objectForKey:@"openFileOnError"] integerValue] == 1)
            {
                NSError * err;
                CodaTextView * errorTextView = [controller openFileAtPath:[error objectForKey:@"filePath"] error:&err];
                if(err)
                {
                	DDLogVerbose(@"LESS:: error opening file: %@", err);
                    return;
                }
                
                [errorTextView goToLine:[[error objectForKey:@"lineNumber"] integerValue] column:[[error objectForKey:@"columnNumber"] integerValue] ];
            }
        }
    });
    
    if([task isRunning])
    {
    	[[errorPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    }
}

-(NSDictionary *) getErrorMessage:(NSString *)fullError
{
    NSError * error = nil;
    NSDictionary * output = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(.*?)Error:(.*?) in (.*?less) on line (.*?), column (.*?):" options:nil error:&error];
    
    NSArray * errorList = [regex matchesInString:fullError options:nil range:NSMakeRange(0, [fullError length])];
    for(NSTextCheckingResult * ntcr in errorList)
    {
        NSString * errorType = 	  [fullError substringWithRange:[ntcr rangeAtIndex:1]];
        NSString * errorName = 	  [fullError substringWithRange:[ntcr rangeAtIndex:2]];
        NSString * filePath = 	  [fullError substringWithRange:[ntcr rangeAtIndex:3]];
        NSString * fileName = 	  [[fullError substringWithRange:[ntcr rangeAtIndex:3]] lastPathComponent];
        NSNumber * lineNumber =   [NSNumber numberWithInteger: [[fullError substringWithRange:[ntcr rangeAtIndex:4]] integerValue]];
        NSNumber * columnNumber = [NSNumber numberWithInteger: [[fullError substringWithRange:[ntcr rangeAtIndex:5]] integerValue]];
        
        NSString * errorMessage = [NSString stringWithFormat:@"%@ in %@, on line %@ column %@", errorName, fileName, lineNumber, columnNumber];
        
        output = @{@"errorMessage": errorMessage,
                   @"errorType": errorType,
                   @"filePath": filePath,
                   @"fileName": fileName,
                   @"lineNumber":lineNumber,
                   @"columnNumber":columnNumber};
        
    }
    DDLogVerbose(@"LESS:: Error: %@", output);
    return output;
}

-(NSString *) getFileNameFromError:(NSString *)fullError
{
    NSError * error = nil;
    NSString * output = [NSString stringWithFormat:@""];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"ParseError:(.*?) in (.*?less) (.*):" options:nil error:&error];
    
    NSArray * errorList = [regex matchesInString:fullError options:nil range:NSMakeRange(0, [fullError length])];
    for(NSTextCheckingResult * ntcr in errorList)
    {
        output = [fullError substringWithRange:[ntcr rangeAtIndex:2]];
    }
    return output;
}

#pragma mark - NSUserNotification

-(void) sendUserNotificationWithTitle:(NSString *)title sound:(NSString *)sound andMessage:(NSString * ) message
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = title;
    notification.informativeText = message;
    notification.soundName = sound;

	if([[NSUserNotificationCenter defaultUserNotificationCenter] delegate] == nil)
    {
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    }
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}


#pragma mark - NSTableViewDelegate/Datasource


#pragma mark - Site Settings
- (IBAction)filePressed:(NSButton *)sender
{
    [self registerFile:[self getFileNameFromUser]];
    [self updateParentFilesListWithCompletion:^{
	    [self rebuildFileList];
    }];

}

-(void) deleteParentFile:(NSButton *)sender
{
	FileView * f = (FileView *)[sender superview];
    if(![f isKindOfClass:[FileView class]])
    {
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:[NSString stringWithFormat:@"Really Delete %@?", f.fileName.stringValue]];
    [alert setInformativeText:[NSString stringWithFormat:@"Are you sure you want to delete %@ ?", f.fileName.stringValue]];
    NSInteger response = [alert runModal];
    if(response == NSAlertFirstButtonReturn)
    {
        NSDictionary * fileInfo = [currentParentFiles objectAtIndex:f.fileIndex];
        NSURL * url = [NSURL fileURLWithPath:[fileInfo objectForKey:@"path"]];
        [self unregisterFile:url];
        [self updateParentFilesListWithCompletion:^{
            [self rebuildFileList];
        }];
    }
    else
    {
        return;
    }
}

-(void) changeCssFile:(NSButton *)sender
{
    FileView * f = (FileView *)[sender superview];
    if(![f isKindOfClass:[FileView class]])
    {
        return;
    }
    NSDictionary * fileInfo = [currentParentFiles objectAtIndex:f.fileIndex];
    NSURL * url = [NSURL fileURLWithPath:[fileInfo objectForKey:@"path"]];
    [self setCssPath:[self getSavenameFromUser] forPath:url];
    [self updateParentFilesListWithCompletion:^{
        [self rebuildFileList];
    }];
}

-(void) changeMinify:(NSButton *)sender
{
    FileView * f = (FileView *)[sender superview];
    if(![f isKindOfClass:[FileView class]])
    {
        return;
    }
    
    int shouldMinify = [sender state];
    NSDictionary * fileInfo = [currentParentFiles objectAtIndex:f.fileIndex];
    NSURL * url = [NSURL fileURLWithPath:[fileInfo objectForKey:@"path"]];
    [self setLessFilePreference:@"minify" toValue:[NSNumber numberWithInt:shouldMinify] forPath:url];
    [self updateParentFilesListWithCompletion:^{
        [self rebuildFileList];
    }];
}

#pragma mark - preferences

- (IBAction)userChangedPreference:(NSButton *)sender
{
    if([sender valueForKey:@"prefKey"] == nil)
    {
        return;
    }
    NSString * pref = [sender valueForKey:@"prefKey"];
    NSNumber * newState = [NSNumber numberWithInteger:[sender state]];
    DDLogVerbose(@"LESS:: setting preference %@ : %@", pref, newState);
    [self updatePreferenceNamed:pref withValue:newState];
}
@end