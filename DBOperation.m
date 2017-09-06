//
//  DBOperation.m
//  Puzzle
//
//  Created by hbmac1 on 9/22/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "DBOperation.h"

static sqlite3 *database = nil;
static int conn;
@implementation DBOperation

+(void)checkCreateDB
{
    @try
    {
        NSString *dbPath,*databaseName;
        
        databaseName=@"";
        

        NSArray *docPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
        NSString *docDir = [docPaths objectAtIndex:0];
        dbPath = [docDir stringByAppendingPathComponent:databaseName];
        BOOL success;
        NSFileManager *fm = [NSFileManager defaultManager];
        success=[fm fileExistsAtPath:dbPath];
        
        NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
        
        if(success)
        {

            if ([[self checkForNullString:[[NSUserDefaults standardUserDefaults] objectForKey:@"VERSION"]] isEqualToString:@""] || ![[[NSUserDefaults standardUserDefaults] objectForKey:@"VERSION"] isEqualToString:version] || [[self checkForNullString:[[NSUserDefaults standardUserDefaults] objectForKey:@"BUILDVERSION"]] isEqualToString:@""] || ![[[NSUserDefaults standardUserDefaults] objectForKey:@"BUILDVERSION"] isEqualToString:build])
            {
                
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentsDirectory = [paths objectAtIndex:0];
                NSString *filePath =  [documentsDirectory stringByAppendingPathComponent:databaseName];
                
                if([[NSFileManager defaultManager] fileExistsAtPath:filePath]){
                    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                }
                
                NSString *dbPathFromApp=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:databaseName];
                [fm copyItemAtPath:dbPathFromApp toPath:dbPath error:nil];
                [self OpenDatabase:dbPath];
                
                [[NSUserDefaults standardUserDefaults]setObject:version forKey:@"VERSION"];
                [[NSUserDefaults standardUserDefaults]setObject:build forKey:@"BUILDVERSION"];
                [[NSUserDefaults standardUserDefaults]synchronize];
                
            }
            else
            {
                [self OpenDatabase:dbPath];
            }

            return;
        }
        
        NSString *dbPathFromApp=[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:databaseName];
        [fm copyItemAtPath:dbPathFromApp toPath:dbPath error:nil];
        
        [[NSUserDefaults standardUserDefaults]setObject:version forKey:@"VERSION"];
        [[NSUserDefaults standardUserDefaults]setObject:build forKey:@"BUILDVERSION"];
        [[NSUserDefaults standardUserDefaults]synchronize];
        
        [self OpenDatabase:dbPath];

        NSLog(@"%@",dbPath);
        
    }
    @catch (NSException *exception)
    {
       NSLog(@"%@",[exception reason]);

    }
}

+(NSString *)checkForNullString:(NSString *)str
{
    if ([str isKindOfClass:[NSNull class]])
    {
        return @"";
    }
    else if (str.length<=0)
    {
        return @"";
    }
    else if ([str isEqualToString:@"(null)"])    {
        return @"";
    }
    else if ([str isEqualToString:@"<null>"])    {
        return @"";
    }
    return str;
}

//Open database
+ (void) OpenDatabase:(NSString*)path
{
	@try
	{
		conn = sqlite3_open([path UTF8String], &database);
		
        if (conn == SQLITE_OK)
        {
            
		}
		else
			sqlite3_close(database); //Even though the open call failed, close the database connection to release all the memory.
	}	
	@catch (NSException *e)
    {
		NSLog(@"%@",e);
	}	
}



+(NSMutableArray*) selectData:(NSString *)sql
{
    @try 
    {
        if (conn == SQLITE_OK) 
        {
            sqlite3_stmt *stmt = nil;
            if(sqlite3_prepare_v2(database, [sql UTF8String], -1, &stmt, NULL) != SQLITE_OK)
            {
                [NSException raise:@"DatabaseException" format:@"Error while creating statement. '%s'", sqlite3_errmsg(database)];
            }
            NSMutableArray *obj = [[NSMutableArray alloc]init];
            int numResultColumns = 0;
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                numResultColumns = sqlite3_column_count(stmt);
                @autoreleasepool {
                    NSMutableDictionary *tmpObj = [[NSMutableDictionary alloc]init];
                    for(int i = 0; i < numResultColumns; i++){
                        if(sqlite3_column_type(stmt, i) == SQLITE_INTEGER){
                            
                            const char *name = sqlite3_column_name(stmt, i);
                            NSString *columnName = [[NSString alloc]initWithCString:name encoding:NSUTF8StringEncoding];
                            [tmpObj setObject:[NSString stringWithFormat:@"%i",sqlite3_column_int(stmt, i)] forKey:columnName];
                            
                        } else if (sqlite3_column_type(stmt, i) == SQLITE_FLOAT) {
                            
                            const char *name = sqlite3_column_name(stmt, i);
                            NSString *columnName = [[NSString alloc]initWithCString:name encoding:NSUTF8StringEncoding];

                            [tmpObj setObject:[NSString stringWithFormat:@"%f",sqlite3_column_double(stmt, i)] forKey:columnName];
                        } else if (sqlite3_column_type(stmt, i) == SQLITE_TEXT) {
                            const char *name = sqlite3_column_name(stmt, i);
                            NSString *tmpStr = [NSString stringWithUTF8String:(char *)sqlite3_column_text(stmt, i)];
                            if ( tmpStr == nil) {
                                tmpStr = @"";
                            }
                            NSString *columnName = [[NSString alloc]initWithCString:name encoding:NSUTF8StringEncoding];
                            [tmpObj setObject:tmpStr forKey:columnName];
                            
                        } else if (sqlite3_column_type(stmt, i) == SQLITE_BLOB)
                        {
                            
                        }     
                        else if (sqlite3_column_type(stmt, i) == SQLITE_NULL) {
                            const char *name = sqlite3_column_name(stmt, i);
                            NSString *tmpStr = @"";
                            
                            NSString *columnName = [[NSString alloc]initWithCString:name encoding:NSUTF8StringEncoding];
                            [tmpObj setObject:tmpStr forKey:columnName];
                        }
                        
                    }
                    [obj addObject:tmpObj];
                
                }
            }
            return obj;
        } else {
            return nil;
        }
    }
    @catch (NSException *exception) {
       NSLog(@"%@",[exception reason]);
        return nil;
    }
 }



+(BOOL) executeSQL:(NSString *)sqlTmp
{
	@try
    {
        
        if(conn == SQLITE_OK)
        {
            
            const char *sqlStmt = [sqlTmp cStringUsingEncoding:NSUTF8StringEncoding];
            sqlite3_stmt *cmp_sqlStmt1;
            int returnValue = sqlite3_prepare_v2(database, sqlStmt, -1, &cmp_sqlStmt1, NULL);
            
            returnValue == SQLITE_OK ?  NSLog(@"\n Inserted \n") :NSLog(@"\n Not Inserted \n");
            
            sqlite3_step(cmp_sqlStmt1);
            sqlite3_finalize(cmp_sqlStmt1);
            
            if (returnValue == SQLITE_OK)
            {
                return TRUE;
            }
        }
        
        return FALSE;
    }
    @catch (NSException *exception)
    {
       NSLog(@"%@",[exception reason]);
        return NO;
    }
}

+ (NSString *) getDBPath // This function retrives database path
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
	NSString *documentsDir = [paths objectAtIndex:0];
	return [documentsDir stringByAppendingPathComponent:@""];
}

+ (NSInteger) getCountForFavouriteProduct : (NSString *)querySQL
{
    @try {
        int count = 0;
        sqlite3 *database;
        if (sqlite3_open([[self getDBPath] UTF8String], &database) == SQLITE_OK)
        {
            const char *sql = [querySQL UTF8String];
            sqlite3_stmt *searchStatement;
            if (sqlite3_prepare_v2(database, sql, -1, &searchStatement, NULL) == SQLITE_OK)
            {
                while (sqlite3_step(searchStatement) == SQLITE_ROW)
                {
                    count = sqlite3_column_int(searchStatement, 0);
                }
            }
            sqlite3_finalize(searchStatement);
            
        }
        sqlite3_close(database);
        return count;
    }
    @catch (NSException *exception) {
        NSLog(@"Exception in getTotalPlayQuizCount");
    }
    
}

@end
