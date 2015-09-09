//
//  EUExBaiduNavi.m
//  EUExBaiduNavi
//
//  Created by Cerino on 15/9/8.
//  Copyright (c) 2015年 AppCan. All rights reserved.
//

#import "EUExBaiduNavi.h"
#import "JSON.h"
#import "EUtility.h"
#import "BNCoreServices.h"

@interface EUExBaiduNavi()<BNNaviRoutePlanDelegate,BNNaviUIManagerDelegate>

@property (nonatomic,assign) BOOL useExternalGPS;
@property (nonatomic,strong) NSMutableArray *externalGPSArray;
@property (nonatomic,strong) NSTimer* externalGPSTimer;
@property (nonatomic,assign) int externalGPSIndex;
@end







@implementation EUExBaiduNavi


-(instancetype)initWithBrwView:(EBrowserView *)eInBrwView{
    self=[super initWithBrwView:eInBrwView];
    if(self){
        _useExternalGPS = NO;
        _externalGPSArray = [NSMutableArray array];
    }
    return self;
}

-(void)clean{
    
}

-(void)dealloc{
    [self clean];
}




#pragma mark - 初始化

/**
 *  初始化
 *
 *  @param 
 *  inArguments = {
 *      baiduAPIKey;//百度APIKey
 *  }
 *  注：百度APIKey由用户在在百度LBS开放平台申请得来
 */
-(void)init:(NSMutableArray*)inArguments{
    
    [self parseJson:inArguments completion:^(id data, BOOL isSuccess, BOOL isDicionary) {
        if(!isSuccess || !isDicionary){
            return;
        }
        [BNCoreServices_Instance initServices:[data objectForKey:@"baiduAPIKey"]];
        [BNCoreServices_Instance startServicesAsyn:^{
            [self callBackJsonWithName:@"cbInit" object:@{@"isSuccess":@(YES)}];
        } fail:^{
            [self callBackJsonWithName:@"cbInit" object:@{@"isSuccess":@(NO)}];
        }];

        
    }];
}



#pragma mark - 路径规划
//通过输入起点与终点，可以发起路径规划。

/**
 *  开始路径规划
 *
 *  @param 
 *  inArguments = {
 *      startNode;//[X,Y]起点坐标
 *      endNode;//[X,Y]终点坐标
 *      throughNodes;//由[X,Y]组成的数组 途经点坐标 可选参数
 *      mode;// 路径规划模式 1-默认模式 2-高速优先 3-少走高速
 *      extras:// 可选，用户传入的参数
 *	}
 */
-(void)startRoutePlan:(NSMutableArray *)inArguments{
    
    [self parseJson:inArguments completion:^(id data, BOOL isSuccess, BOOL isDicionary) {
        if(!isSuccess||!isDicionary){
            return;
        }
        NSMutableArray *nodesArray = [NSMutableArray array];
        
        BNRoutePlanNode *startNode = [[BNRoutePlanNode alloc] init];
        startNode.pos = [[BNPosition alloc] init];
        NSArray *startPosition=[data objectForKey:@"startNode"];
        startNode.pos.x = [startPosition[0] doubleValue];
        startNode.pos.y = [startPosition[1] doubleValue];
        startNode.pos.eType = BNCoordinate_BaiduMapSDK;
        
        [nodesArray addObject:startNode];
        
        id throughNodes=[data objectForKey:@"throughNodes"];
        if(throughNodes && [throughNodes isKindOfClass:[NSArray class]] &&[throughNodes count]>0){
            for(NSArray * throughPosition in throughNodes){
                BNRoutePlanNode *throughNode = [[BNRoutePlanNode alloc] init];
                throughNode.pos = [[BNPosition alloc] init];
                throughNode.pos.x = [throughPosition[0] doubleValue];
                throughNode.pos.y = [throughPosition[1] doubleValue];
                throughNode.pos.eType = BNCoordinate_BaiduMapSDK;
                [nodesArray addObject:throughNode];
                
                
            }
        }
        
        BNRoutePlanNode *endNode = [[BNRoutePlanNode alloc] init];
        endNode.pos = [[BNPosition alloc] init];
        NSArray *endPosition=[data objectForKey:@"endNode"];
        endNode.pos.x = [endPosition[0] doubleValue];
        endNode.pos.y = [endPosition[1] doubleValue];
        endNode.pos.eType = BNCoordinate_BaiduMapSDK;
        [nodesArray addObject:endNode];
        
        
        BNRoutePlanMode routeType=BNRoutePlanMode_Recommend;
        NSString* mode =[data objectForKey:@"mode"];
        if([mode integerValue]==2){
            routeType = BNRoutePlanMode_Highway;
        }else if([mode  integerValue]==3){
            routeType = BNRoutePlanMode_NoHighway;
        }
        NSDictionary * extras=nil;
        if([data objectForKey:@"extras"]&&[[data objectForKey:@"extras"]isKindOfClass:[NSDictionary class]]){
            extras=[data objectForKey:@"extras"];
        }
        [BNCoreServices_RoutePlan  startNaviRoutePlan: routeType naviNodes:nodesArray time:nil delegete:self userInfo:extras];
        
    }];
}

/**
 *  路径规划成功回调
 *
 *  @param
 *      extras 用户传入的参数
 */


-(void)routePlanDidFinished:(NSDictionary *)userInfo{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@1 forKey:@"resultCode"];
    [dict setValue:userInfo forKey:@"extras"];
    [self callBackJsonWithName:@"cbStartRoutePlan" object:dict];
}




/**
 *  路径规划失败回调
 *
 *  @param
 *      error	1-获取地理位置失败 2-无法发起算路 3-定位服务未开启 4-节点之间距离太近 5-节点输入有误 6-上次算路取消了，需要等一会儿
 *      extras  用户传入的参数
 */



- (void)routePlanDidFailedWithError:(NSError *)error andUserInfo:(NSDictionary *)userInfo{
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSNumber *errorCode=@0;
    if ([error code] == BNRoutePlanError_LocationFailed) {
        errorCode = @1;
    }else if ([error code] == BNRoutePlanError_RoutePlanFailed){
        errorCode = @2;
    }else if ([error code] == BNRoutePlanError_LocationServiceClosed){
        errorCode = @3;
    }else if ([error code] == BNRoutePlanError_NodesTooNear){
        errorCode = @4;
    }else if ([error code] == BNRoutePlanError_NodesInputError){
        errorCode = @5;
    }else if([error code] == BNRoutePlanError_WaitAMoment){
        errorCode = @6;
    }
    [dict setValue:errorCode forKey:@"error"];
    [dict setValue:@2 forKey:@"resultCode"];
    [dict setValue:userInfo forKey:@"extras"];
    [self callBackJsonWithName:@"cbStartRoutePlan" object:dict];
}



/**
 *  路径规划取消回调
 *
 *  @param
 *      extras 用户传入的参数
 */
-(void)routePlanDidUserCanceled:(NSDictionary*)userInfo {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@3 forKey:@"resultCode"];
    [dict setValue:userInfo forKey:@"extras"];
    [self callBackJsonWithName:@"cbStartRoutePlan" object:dict];
}




#pragma mark - 导航功能
//成功发起路径规划后，即可以进入真实GPS导航或模拟导航。真实导航中点击转向标可以切换到文字导航模式，文字导航界面点击HUD按钮可以进入HUD导航。






/**
 *  开始导航
 *
 *  @param 
 *  inArguments = {
 *      naviType;//导航模式 1-真实导航(默认) 2-模拟导航
 *      isNeedLandscape;// 是否需要横竖屏切换 默认竖屏 1-需要(默认) 2-不需要
 *  }
 */
-(void)startNavi:(NSMutableArray *)inArguments{
    [self parseJson:inArguments completion:^(id data, BOOL isSuccess, BOOL isDicionary) {
        BN_NaviType naviType=BN_NaviTypeReal;
        BOOL isNeedLandscape = YES;
        if(isSuccess&&isDicionary){
            if([[data objectForKey:@"naviType"]integerValue]==2){
                naviType = BN_NaviTypeSimulator;
            }
            if([[data objectForKey:@" isNeedLandscape"]integerValue]==2){
                isNeedLandscape = NO;
            }

        }
        [BNCoreServices_UI showNaviUI:naviType delegete:self isNeedLandscape:isNeedLandscape];

    }];
   
    
    
}


-(void)exitNavi:(NSMutableArray *)inArguments{
    [self parseJson:inArguments completion:^(id data, BOOL isSuccess, BOOL isDicionary) {
        NSDictionary* extras=nil;
        if(isSuccess&&isDicionary&&[data objectForKey:@"extras"]&&[[data objectForKey:@"extras"] isKindOfClass:[NSDictionary class]]){
            extras =[data objectForKey:@"extras"];
        }
        [BNCoreServices_UI exitNaviUI:extras];
    }];
    
}


/**
 *  退出导航回调
 *  退出外部GPS导航回调
 *
 *  @param
 */
-(void)onExitNaviUI:(NSDictionary*)extraInfo{
    
    if(!self.useExternalGPS){
        [self callBackJsonWithName:@"onExitNavi" object:nil];
    }else{
        [BNCoreServices_Location setGpsFromExternal:NO];
        self.useExternalGPS=NO;
        [self stopPostGPS];
        [self callBackJsonWithName:@"onExitExternalGPSNavi" object:nil];
    }
    
}



/**
 *  退出导航声明页面回调
 *
 *  @param 
 *  注：仅在第一次进入导航页面时，会显示导航声明页面
 */
-(void)onExitDeclarationUI:(NSDictionary*)extraInfo
{
    [self callBackJsonWithName:@"onExitDeclaration" object:nil];
}

#pragma mark - 巡航功能
//也即电子狗功能，不用输入起点终点，一键即可进行巡航模式，准确发现前方电子眼信息。



/**
 *  开始巡航
 *
 *  @param
 *  inArguments = {
 *      isNeedLandscape:,// 是否需要横竖屏切换 默认竖屏 1-需要(默认) 2-不需要
 *  }
 */


-(void) startDigitDog:(NSMutableArray *)inArguments{
    [self parseJson:inArguments completion:^(id data, BOOL isSuccess, BOOL isDicionary) {
        BOOL isNeedLandscape = YES;
        if(isSuccess&&isDicionary){
            if([[data objectForKey:@"isNeedLandscape"] integerValue]==2){
                isNeedLandscape = NO;
            }
        }
        
        [BNCoreServices_UI showDigitDogUI:isNeedLandscape delegete:self];

    }];
}

/**
 *  退出巡航回调
 *  退出外部GPS巡航回调
 *
 *  @param
 */
-(void)onExitDigitDogUI:(NSDictionary*)extraInfo
{
    
    if(!self.useExternalGPS){
        
        [self callBackJsonWithName:@"onExitDigitDog" object:nil];
    }else{
        self.useExternalGPS=NO;
        [BNCoreServices_Location setGpsFromExternal:NO];
        [self stopPostGPS];
        [self callBackJsonWithName:@"onExitExternalGPSDigitDog" object:nil];
    }
}

#pragma mark - 外部GPS功能
//当SDK运行于无法获取GPS数据的设备时，可以利用其它GPS模块获取GPS信息，然后通过SDK提供的接口传入GPS数据发起导航或者巡航。



/**
 *  载入外部GPS数据
 *
 *  @param 
 *  inArguments = {
 *      filePath;//外部GPS数据文件路径
 *  }
 *  注：GPS数据文件要求utf8编码
 *	每一行为一个GPSLocation结构的JSON字符串
 *  var GPSLocation={//GPS数据
 *      longitude:,//经度
 *      latitude:,//纬度
 *      speed:,//速度
 *      direction:,//方向角度
 *      accuracy:,//水平精度
 *      attitude:,//(可选参数)海拔
 *  }
 */

-(void)loadExternalGPSData:(NSMutableArray *)inArguments{
    
    [self parseJson:inArguments completion:^(id data, BOOL isSuccess, BOOL isDicionary) {
        if(!isSuccess||!isDicionary){
            return;
        }
        [self.externalGPSArray removeAllObjects];
        self.externalGPSIndex=0;
        NSError *error = nil;
        NSString* gpsText = [NSString stringWithContentsOfFile:[self absPath:[data objectForKey:@"filePath"]]
                                                      encoding:NSUTF8StringEncoding
                                                         error:&error];
        if(error||[gpsText length]==0){
            return;
        }
        NSArray* gpsArray = [gpsText componentsSeparatedByString:@"\r\n"];
        
        for (NSString* aGPS in gpsArray){
            error=nil;
            NSData *jsonData= [aGPS dataUsingEncoding:NSUTF8StringEncoding];
            id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData
                                                            options:NSJSONReadingMutableContainers
                                                              error:&error];
            
            if(!error&&[jsonObject isKindOfClass:[NSDictionary class]]){
                //设置gps数据
                BNLocation* oneGPSInfo = [[BNLocation alloc] init];
                double longitude = [[jsonObject objectForKey:@"longitude"] doubleValue];
                double latitude = [[jsonObject objectForKey:@"latitude"] doubleValue];
                double speed = [[jsonObject objectForKey:@"speed"] doubleValue];
                double direction =[[jsonObject objectForKey:@"direction"] doubleValue];
                double accuracy = [[jsonObject objectForKey:@"accuracy"] doubleValue];
                double attitude = [[jsonObject objectForKey:@"attitude"] doubleValue];
                oneGPSInfo.coordinate = CLLocationCoordinate2DMake(longitude,latitude);
                oneGPSInfo.speed = speed;
                oneGPSInfo.course = direction;
                oneGPSInfo.horizontalAccuracy = accuracy;
                oneGPSInfo.verticalAccuracy = 0;
                oneGPSInfo.altitude = attitude;
                [self.externalGPSArray addObject:oneGPSInfo];
            }
            
        }
    }];
}


- (void)startPostGPS
{
    self.externalGPSIndex = 0;
    self.externalGPSTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(postGPS) userInfo:nil repeats:YES];
    
    [self.externalGPSTimer fire];
}

- (void)stopPostGPS
{
    [self.externalGPSTimer invalidate];
    self.externalGPSTimer = nil;
}

- (void)postGPS
{
    if (!self.externalGPSArray || self.externalGPSArray.count == 0 || self.externalGPSArray.count <= self.externalGPSIndex){
        return;
    }
    [BNCoreServices_Location setCurrentLocation:self.externalGPSArray[self.externalGPSIndex]];
    self.externalGPSIndex = (self.externalGPSIndex + 1)%self.externalGPSArray.count;
}
/**
 *  开始外部GPS导航
 *
 *  @param 
 *  inArguments = {
 *      isNeedLandscape;// (可选参数)是否需要横竖屏切换 默认竖屏 1-需要(默认) 2-不需要
 *  }
 */
-(void) startExternalGPSNavi:(NSMutableArray *)inArguments{
    
    [self parseJson:inArguments completion:^(id data, BOOL isSuccess, BOOL isDicionary) {
        self.useExternalGPS = YES;
        
        
        BOOL isNeedLandscape = YES;
        if(isSuccess&&isDicionary&&[[data objectForKey:@" isNeedLandscape"] integerValue]==2){
            isNeedLandscape = NO;
        }
        [BNCoreServices_Location setGpsFromExternal:YES];
        [BNCoreServices_UI showNaviUI:BN_NaviTypeReal delegete:self isNeedLandscape:isNeedLandscape];
        [self startPostGPS];

    }];

}

/**
 *  开始外部GPS巡航
 *
 *  @param 
 *  inArguments = {
 *      isNeedLandscape;// 可选参数 是否需要横竖屏切换 默认竖屏 1-需要 2-不需要
 *  }
 */
-(void)startExternalGPSDigitDog:(NSMutableArray *)inArguments{
    self.useExternalGPS=YES;
    [self parseJson:inArguments completion:^(id data, BOOL isSuccess, BOOL isDicionary) {
        BOOL isNeedLandscape = YES;
        if(isSuccess&&isDicionary&&[[data objectForKey:@" isNeedLandscape"] integerValue]==2){
            isNeedLandscape = NO;
        }
        [BNCoreServices_Location setGpsFromExternal:YES];
        //显示巡航UI
        [BNCoreServices_UI showDigitDogUI:isNeedLandscape delegete:self];
        //开始发送gps
        [self startPostGPS];
    }];
}



#pragma mark - json I/O
//回调名为name 内容为dict的json字符串
-(void) callBackJsonWithName:(NSString *)name object:(id)obj{
    NSString *jsonData=[obj JSONFragment];
    NSString *jsStr = [NSString stringWithFormat:@"if(uexBaiduNavi.%@ != null){uexBaiduNavi.%@('%@');}",name,name,jsonData];
    
    [EUtility brwView:meBrwView evaluateScript:jsStr];
    
}



//通过JSON获取数据
- (id)getDataFromJson:(NSString *)jsonStr{
    NSError *error = nil;
    NSData *jsonData= [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData
                                                    options:NSJSONReadingMutableContainers
                                                      error:&error];
    
    if (jsonObject != nil && !error){
        return jsonObject;
    }else{
        // 解析錯誤
        return nil;
    }
}


-(void)parseJson:(NSMutableArray *)inArguments completion:(void (^)(id data,BOOL isSuccess,__unused BOOL isDicionary))completion{
    if([inArguments count]==0){
        if(completion){
            completion(nil,NO,NO);
        }
        return;
    }
    id info = [self getDataFromJson:inArguments[0]];
    BOOL isDictionary = YES;
    if(![info isKindOfClass:[NSDictionary class]]){
        isDictionary=NO;
    }
    if (completion) {
        completion(info,YES,isDictionary);
    }
}


@end
