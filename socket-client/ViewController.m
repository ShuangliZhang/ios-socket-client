//
//  ViewController.m
//  socket-client
//
//  Created by hzzhangshuangli on 2017/9/25.
//  Copyright © 2017年 hzzhangshuangli. All rights reserved.
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"

@interface ViewController()

@property(nonatomic)IBOutlet UITextField *addressTF;
@property(nonatomic)IBOutlet UITextField *portTF;
@property(nonatomic)IBOutlet UITextField *messageTF;
@property(nonatomic)IBOutlet UITextView *showMessageTF;

//客户端socket

@property(nonatomic) GCDAsyncSocket *clientSocket;

@end
@implementation ViewController

#pragma mark - GCDAsynSocket Delegate

- (void)socket:(GCDAsyncSocket*)sock didConnectToHost:(NSString*)host port:(uint16_t)port{
    [self showMessageWithStr:@"链接成功"];
    [self showMessageWithStr:[NSString stringWithFormat:@"服务器IP：%@", host]];
    [self.clientSocket readDataWithTimeout:-1 tag:0];
}

//收到消息

- (void)socket:(GCDAsyncSocket*)sock didReadData:(NSData*)data withTag:(long)tag{
    //if your server is windows
    NSLog(@"receive data:%@",[[NSString alloc]initWithData:data encoding:NSISOLatin1StringEncoding]);
    //if your server is IOS
    NSString *text = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    [self showMessageWithStr:text];
    [self.clientSocket readDataWithTimeout:-1 tag:0];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent*)event{
    [self.view endEditing:YES];
}

//开始连接
- (IBAction)connectAction:(id)sender {
    //2、连接服务器
    [self.clientSocket connectToHost:self.addressTF.text onPort:self.portTF.text.integerValue withTimeout:-1 error:nil];
}

//发送消息

- (IBAction)sendMessageAction:(id)sender {
    NSData *data = [self.messageTF.text dataUsingEncoding:NSUTF8StringEncoding];
    //withTimeout -1 :无穷大
    //tag：消息标记
    [self.clientSocket writeData:data withTimeout:-1 tag:0];
    NSLog(@"message%@ send", self.messageTF.text);
}

- (IBAction)cleanMessageTV:(id)sender {
    self.showMessageTF.text = @"";
}

- (IBAction)saveMessage:(id)sender {
    NSString *newFilePath = @"messageLog.txt";
    [[NSFileManager defaultManager] createFileAtPath:newFilePath contents:nil attributes:nil];
    // Then as a you have an NSString you could simple use the writeFile: method
    [self.showMessageTF.text writeToFile: newFilePath atomically: YES];
}

//接收消息

- (IBAction)receiveMessageAction:(id)sender {
    [self.clientSocket readDataWithTimeout:11 tag:0];
}

- (void)showMessageWithStr:(NSString*)str{
    self.showMessageTF.text= [self.showMessageTF.text stringByAppendingFormat:@"%@\n", str];
}

- (void)uiSetup {
    
    UILabel *port = [[UILabel alloc] initWithFrame:CGRectMake(20, 30, 60, 30)];
    port.text = @"ip";
    [self.view addSubview:port];
    UILabel *msg = [[UILabel alloc] initWithFrame:CGRectMake(20, 65, 60, 30)];
    msg.text = @"消息";
    [self.view addSubview:msg];
    
    UIButton *startListen = [[UIButton alloc] initWithFrame:CGRectMake(220, 30, 45, 30)];
    [self.view addSubview:startListen];
    [startListen setTitle:@"连接" forState:UIControlStateNormal];
    [startListen setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [startListen addTarget:self action:@selector(connectAction:) forControlEvents:UIControlEventTouchUpInside];

    UIButton *sendMsg= [[UIButton alloc] initWithFrame:CGRectMake(260, 30, 70, 30)];
    [self.view addSubview:sendMsg];
    [sendMsg setTitle:@"发消息" forState:UIControlStateNormal];
    [sendMsg setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [sendMsg addTarget:self action:@selector(sendMessageAction:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *clearTV = [[UIButton alloc] initWithFrame:CGRectMake(220, 60, 45, 30)];
    [self.view addSubview:clearTV];
    [clearTV setTitle:@"清空" forState:UIControlStateNormal];
    [clearTV setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [clearTV addTarget:self action:@selector(cleanMessageTV:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *receiveMsg = [[UIButton alloc] initWithFrame:CGRectMake(260, 60, 70, 30)];
    [self.view addSubview:receiveMsg];
    [receiveMsg setTitle:@"存储" forState:UIControlStateNormal];
    [receiveMsg setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [receiveMsg addTarget:self action:@selector(saveMessage:) forControlEvents:UIControlEventTouchUpInside];
    
    self.addressTF = [[UITextField alloc] initWithFrame:CGRectMake(60, 30, 100, 30)];
    self.addressTF.layer.borderColor = [[UIColor blackColor]CGColor];
    self.addressTF.layer.cornerRadius=8.0f;
    self.addressTF.layer.borderWidth= 1.0f;
    self.portTF = [[UITextField alloc] initWithFrame:CGRectMake(160, 30, 60, 30)];
    self.portTF.layer.borderColor = [[UIColor blackColor]CGColor];
    self.portTF.layer.cornerRadius = 8.0f;
    self.portTF.layer.borderWidth= 1.0f;
    self.messageTF = [[UITextField alloc] initWithFrame:CGRectMake(60, 65, 150, 30)];
    self.messageTF.layer.borderColor = [[UIColor blackColor]CGColor];
    self.messageTF.layer.cornerRadius=8.0f;
    self.messageTF.layer.borderWidth= 1.0f;
    self.showMessageTF = [[UITextView alloc] initWithFrame:CGRectMake(20, 100, 280, 400)];
    self.showMessageTF.layer.backgroundColor =[[UIColor grayColor]CGColor];
    [self.view addSubview:self.addressTF];
    [self.view addSubview:self.portTF];
    [self.view addSubview:self.messageTF];
    [self.view addSubview:self.showMessageTF];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self uiSetup];
    NSString *homeDirectory;
    homeDirectory = NSHomeDirectory(); // Get app's home directory - you could check for a folder here too.
    BOOL isWriteable = [[NSFileManager defaultManager] isWritableFileAtPath: homeDirectory]; //Check file path is writealbe
    // You can now add a file name to your path and the create the initial empty file
    // Do any additional setup after loading the view, typically from a nib.
    //1、初始化
    self.clientSocket= [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

