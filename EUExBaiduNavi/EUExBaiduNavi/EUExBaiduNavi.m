//
//  EUExBaiduNavi.m
//  EUExBaiduNavi
//
//  Created by Cerino on 15/9/8.
//  Copyright (c) 2015年 AppCan. All rights reserved.
//

#import "EUExBaiduNavi.h"
#import "BNCoreServices.h"

@interface EUExBaiduNavi()<BNNaviRoutePlanDelegate,BNNaviUIManagerDelegate>

@property (nonatomic,assign) BOOL useExternalGPS;
@property (nonatomic,strong) NSMutableArray *externalGPSArray;
@property (nonatomic,strong) NSTimer* externalGPSTimer;
@property (nonatomic,assign) int externalGPSIndex;
@property (nonatomic,strong) ACJSFunctionRef *cbStartRoutePlan;
@end







@implementation EUExBaiduNavi


- (instancetype)initWithWebViewEngine:(id<AppCanWebViewEngineObject>)engine{
    self = [super initWithWebViewEngine:engine];
    if (self) {
        _useExternalGPS = NO;
        _externalGPSArray = [NSMutableArray array];
    }
    return self;
}


- (void)clean{
    [self.externalGPSTimer invalidate];
    self.externalGPSTimer = nil;
    self.cbStartRoutePlan = nil;
}

- (void)dealloc{
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
- (void)init:(NSMutableArray*)inArguments{
    
    ACArgsUnpack(NSDictionary *info,ACJSFunctionRef *cb) = inArguments;
    NSString *key = stringArg(info[@"baiduAPIKey"]);
    
    void (^callback)(BOOL result) = ^(BOOL result){
        NSDictionary *dict = @{@"isSuccess":@(result)};
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexBaiduNavi.cbInit" arguments:ACArgsPack(dict.ac_JSONFragment)];
        [cb executeWithArguments:ACArgsPack(dict)];
    };
    
    [BNCoreServices_Instance initServices:key];
    [BNCoreServices_Instance startServicesAsyn:^{
        callback(YES);
    } fail:^{
        callback(NO);
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
- (void)startRoutePlan:(NSMutableArray *)inArguments{
    
    ACArgsUnpack(NSDictionary *info,ACJSFunctionRef *cb) = inArguments;
    
    NSMutableArray *nodesArray = [NSMutableArray array];
    
    BNRoutePlanNode *startNode = [[BNRoutePlanNode alloc] init];
    startNode.pos = [[BNPosition alloc] init];
    NSArray *startPosition = arrayArg(info[@"startNode"]);
    startNode.pos.x = [startPosition[0] doubleValue];
    startNode.pos.y = [startPosition[1] doubleValue];
    startNode.pos.eType = BNCoordinate_BaiduMapSDK;
    
    [nodesArray addObject:startNode];
    
    NSArray * throughNodes=arrayArg(info[@"throughNodes"]);
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
    NSArray *endPosition=arrayArg(info[@"endNode"]);
    endNode.pos.x = [endPosition[0] doubleValue];
    endNode.pos.y = [endPosition[1] doubleValue];
    endNode.pos.eType = BNCoordinate_BaiduMapSDK;
    [nodesArray addObject:endNode];
    
    BNRoutePlanMode routeType=BNRoutePlanMode_Recommend;
    NSInteger mode = [info[@"mode"] integerValue];
    if(mode == 2){
        routeType = BNRoutePlanMode_Highway;
    }else if(mode == 3){
        routeType = BNRoutePlanMode_NoHighway;
    }
    NSDictionary * extras = dictionaryArg(info[@"extras"]);
    
    [BNCoreServices_RoutePlan  startNaviRoutePlan: routeType naviNodes:nodesArray time:nil delegete:self userInfo:extras];
    self.cbStartRoutePlan = cb;
}




- (void)cbStartRoutePlan:(NSDictionary *)dict{
    [self.webViewEngine callbackWithFunctionKeyPath:@"uexBaiduNavi.cbStartRoutePlan" arguments:ACArgsPack(dict.ac_JSONFragment)];
    [self.cbStartRoutePlan executeWithArguments:ACArgsPack(dict)];
    self.cbStartRoutePlan = nil;
}

/**
 *  路径规划成功回调
 *
 *  @param
 *      extras 用户传入的参数
 */


- (void)routePlanDidFinished:(NSDictionary *)userInfo{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@1 forKey:@"resultCode"];
    [dict setValue:userInfo forKey:@"extras"];
    [self cbStartRoutePlan:dict];
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
    NSNumber *errorCode = @0;
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
    [self cbStartRoutePlan:dict];
}



/**
 *  路径规划取消回调
 *
 *  @param
 *      extras 用户传入的参数
 */
- (void)routePlanDidUserCanceled:(NSDictionary*)userInfo {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@3 forKey:@"resultCode"];
    [dict setValue:userInfo forKey:@"extras"];
    [self cbStartRoutePlan:dict];
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
- (void)startNavi:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info) = inArguments;
    BN_NaviType naviType=BN_NaviTypeReal;
    BOOL isNeedLandscape = YES;

    if([info[@"naviType"] integerValue] == 2){
        naviType = BN_NaviTypeSimulator;
    }
    if([info[@"isNeedLandscape"] integerValue] == 2){
        isNeedLandscape = NO;
    }
    [BNCoreServices_UI showNaviUI:naviType delegete:self isNeedLandscape:isNeedLandscape];

   
    
    
}


- (void)exitNavi:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSDictionary* extras = dictionaryArg(info[@"extras"]);
    [BNCoreServices_UI exitNaviUI:extras];
}


/**
 *  退出导航回调
 *  退出外部GPS导航回调
 *
 *  @param
 */
- (void)onExitNaviUI:(NSDictionary*)extraInfo{
    if(!self.useExternalGPS){
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexBaiduNavi.onExitNavi" arguments:nil];
    }else{
        [BNCoreServices_Location setGpsFromExternal:NO];
        self.useExternalGPS = NO;
        [self stopPostGPS];
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexBaiduNavi.onExitExternalGPSNavi" arguments:nil];
    }
    
}



/**
 *  退出导航声明页面回调
 *
 *  @param 
 *  注：仅在第一次进入导航页面时，会显示导航声明页面
 */
- (void)onExitDeclarationUI:(NSDictionary*)extraInfo{
    [self.webViewEngine callbackWithFunctionKeyPath:@"uexBaiduNavi.onExitDeclaration" arguments:nil];

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


- (void)startDigitDog:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info) = inArguments;
    BOOL isNeedLandscape = YES;
    if ([info[@"isNeedLandscape"] integerValue] == 2) {
        isNeedLandscape = NO;
    }
    [BNCoreServices_UI showDigitDogUI:isNeedLandscape delegete:self];
}

/**
 *  退出巡航回调
 *  退出外部GPS巡航回调
 *
 *  @param
 */
- (void)onExitDigitDogUI:(NSDictionary*)extraInfo
{
    
    if(!self.useExternalGPS){
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexBaiduNavi.onExitDigitDog" arguments:nil];
    }else{
        self.useExternalGPS = NO;
        [BNCoreServices_Location setGpsFromExternal:NO];
        [self stopPostGPS];
         [self.webViewEngine callbackWithFunctionKeyPath:@"uexBaiduNavi.onExitExternalGPSDigitDog" arguments:nil];
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

- (void)loadExternalGPSData:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *filePath = stringArg(info[@"filePath"]);

    
    [self.externalGPSArray removeAllObjects];
    self.externalGPSIndex = 0;
    NSError *error = nil;
    NSString* gpsText = [NSString stringWithContentsOfFile:[self absPath:filePath]
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
    if (error || !gpsText || gpsText.length == 0) {
        return;
    }
    NSArray* gpsArray = [gpsText componentsSeparatedByString:@"\n"];
    [gpsArray enumerateObjectsUsingBlock:^(NSString *  _Nonnull aGPS, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *aGPSInfo = dictionaryArg([aGPS stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
        if (!aGPSInfo) {
            return;
        }
        BNLocation* oneGPSInfo = [[BNLocation alloc] init];
        double longitude = [aGPSInfo[@"longitude"] doubleValue];
        double latitude = [aGPSInfo[@"latitude"] doubleValue];
        double speed = [aGPSInfo[@"speed"] doubleValue];
        double direction =[aGPSInfo[@"direction"] doubleValue];
        double accuracy = [aGPSInfo[@"accuracy"] doubleValue];
        double attitude = [aGPSInfo[@"attitude"] doubleValue];
        oneGPSInfo.coordinate = CLLocationCoordinate2DMake(longitude,latitude);
        oneGPSInfo.speed = speed;
        oneGPSInfo.course = direction;
        oneGPSInfo.horizontalAccuracy = accuracy;
        oneGPSInfo.verticalAccuracy = 0;
        oneGPSInfo.altitude = attitude;
        [self.externalGPSArray addObject:oneGPSInfo];
    }];
    
}


- (void)startPostGPS{
    self.externalGPSIndex = 0;
    self.externalGPSTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(postGPS) userInfo:nil repeats:YES];
    [self.externalGPSTimer fire];
}

- (void)stopPostGPS{
    [self.externalGPSTimer invalidate];
    self.externalGPSTimer = nil;
}

- (void)postGPS{
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
- (void) startExternalGPSNavi:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info) = inArguments;
    self.useExternalGPS = YES;
    
    
    BOOL isNeedLandscape = YES;
    if ([info[@"isNeedLandscape"] integerValue] == 2) {
        isNeedLandscape = NO;
    }
    [BNCoreServices_Location setGpsFromExternal:YES];
    [BNCoreServices_UI showNaviUI:BN_NaviTypeReal delegete:self isNeedLandscape:isNeedLandscape];
    [self startPostGPS];


}

/**
 *  开始外部GPS巡航
 *
 *  @param 
 *  inArguments = {
 *      isNeedLandscape;// 可选参数 是否需要横竖屏切换 默认竖屏 1-需要 2-不需要
 *  }
 */
- (void)startExternalGPSDigitDog:(NSMutableArray *)inArguments{
    self.useExternalGPS = YES;
    ACArgsUnpack(NSDictionary *info) = inArguments;
    BOOL isNeedLandscape = YES;
    if ([info[@"isNeedLandscape"] integerValue] == 2) {
        isNeedLandscape = NO;
    }
    [BNCoreServices_Location setGpsFromExternal:YES];
    //显示巡航UI
    [BNCoreServices_UI showDigitDogUI:isNeedLandscape delegete:self];
    //开始发送gps
    [self startPostGPS];
}

/*


#pragma mark - json I/O
//回调名为name 内容为dict的json字符串
- (void) callBackJsonWithName:(NSString *)name object:(id)obj{
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


- (void)parseJson:(NSMutableArray *)inArguments completion:(void (^)(id data,BOOL isSuccess,__unused BOOL isDicionary))completion{
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

*/
@end
