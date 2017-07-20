//
//  PreferencesWindowController.swift
//  ApplicationLogger
//
//  Created by Paul McCartney on 2017/07/07.
//  Copyright © 2017年 shiba. All rights reserved.
//

import Cocoa
import CoreLocation
import AppAuth
import GTMAppAuth

class PreferencesWindowController: NSWindowController, URLSessionDelegate {
    
    static var sharedController = PreferencesWindowController()
    
    var activity: Any? = nil
    
    @IBOutlet var generalView:      NSView!
    @IBOutlet var googleView:       NSView!
    @IBOutlet var generalTextView:  NSTextView?
    @IBOutlet var googleTextView:   NSTextView?
    
    let USER_ID_KEY:        String = "userId"
    let USER_EMAIL_KEY:     String = "userMail"
    let USERNAME_KEY:       String = "username"
    let FAMILY_NAME_KEY:    String = "familyName"
    let GIVEN_NAME_KEY:     String = "givenName"
    let UUID_KEY:           String = "uuid"
    let DEVICE_TYPE:        String = "Mac"
    
    let SCOPE:              String = "profile"
    let CLIENT_ID:          String = "809572683387-sp7clti629vvepm6fa36ckp9ae1q8ak0.apps.googleusercontent.com"
    let CLIENT_SECRET:      String = "4PPH0IGB7GlgrPKwcEjwFPEc"
    let ISSUER:             String = "https://accounts.google.com"
    let REDIRECT_URI:       String = "com.googleusercontent.apps.809572683387-sp7clti629vvepm6fa36ckp9ae1q8ak0:/oauthredirect"
    let AUTHORIZATION_KEY:  String = "authorization"
    
    let POST_URL: String = "http://life-cloud.ht.sfc.keio.ac.jp/~shiba/ApplicationLogger/php/saveLogFile.php"
    
    let ud: UserDefaults = UserDefaults.standard
    
    var userID:         String = ""
    var userEmail:      String = ""
    var username:       String = ""
    var familyName:     String = ""
    var givenName:      String = ""
    
    var uuidKey:    String = ""
    var uuid:       String = ""
    
    var unixtime:               Double = 0
    var currentTime:            String = ""
    var currentActiveAppName:   String = ""
    var pastActiveAppName:      String = ""
    
    var logInterval:        Int = 60
    var isActive:           Bool = true
    var moveAmount:         Int = 0
    var typeCount:          Int = 0
    var pastMouseLocation:  NSPoint = NSEvent.mouseLocation()
    
    var filePath:       String = ""
    var logFileName:    String = ""
    var csv:            String = ""
    var serverURL:      String = ""
    
    var changeStateInterval:    Double = 0
    var sendActionLogInterval:  Double = 0
    var lastUptadeTime:         Double = 0
    
    var authorization: GTMAppAuthFetcherAuthorization? = nil
    
    private init() {
        super.init(window: nil)
        Bundle.main.loadNibNamed("PreferencesWindowController", owner: self, topLevelObjects: nil)
        setPreferenceView(view: generalView)
        setShowLogTimer()
    }
    
    override init(window: NSWindow!) {
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented. Use init()")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }

    /**
     * ========================================
     * ユーザ情報の初期化
     * ========================================
     */
    
    func initUserInfo() {
        userID = ud.string(forKey: USER_ID_KEY)!
        userEmail = ud.string(forKey: USER_EMAIL_KEY)!
        username = ud.string(forKey: USERNAME_KEY)!
        familyName = ud.string(forKey: FAMILY_NAME_KEY)!
        givenName = ud.string(forKey: GIVEN_NAME_KEY)!
        logFileName = userID + "_ApplicationLogger.csv"
        uuid = getUUID()
    }
    
    func getUUID() -> String {
        var uuidStr = ud.string(forKey: UUID_KEY)
        if uuidStr == nil {
            let u = CFUUIDCreate(nil)
            uuidStr = CFUUIDCreateString(nil, u) as String?
            ud.set(uuidStr, forKey: UUID_KEY)
        }
        return uuidStr!
    }
    
    /**
     * ========================================
     * ログ
     * ========================================
     */

    
    func startLogging() {
        
        // バックグラウンドでの実行を可能にする
        if ProcessInfo.processInfo.responds(to: #selector(ProcessInfo.beginActivity(options:reason:))) {
            activity = ProcessInfo.processInfo.beginActivity(options: ProcessInfo.ActivityOptions(rawValue: 0x00FFFFFF), reason: "receiving OSC messages")
        }
        
        initUserInfo()
        
        monitorKeyboard()
        setTimer()
        sendLogFile()
        
    }

    func setTimer() {
        let writingLogFileTimer = Timer(timeInterval: 1.0,
                           target: self,
                           selector: #selector(self.writeLogFile),
                           userInfo: nil,
                           repeats: true)
        RunLoop.main.add(writingLogFileTimer, forMode: .commonModes)
        
        let checkActiveStateTimer = Timer(timeInterval: 1.0,
                                          target: self,
                                          selector: #selector(self.checkActiveState),
                                          userInfo: nil,
                                          repeats: true)
        RunLoop.main.add(checkActiveStateTimer, forMode: .commonModes)
        
        let sendLogFileTimer = Timer(timeInterval: 60.0,
                                     target: self,
                                     selector: #selector(self.sendLogFile),
                                     userInfo: nil,
                                     repeats: true)
        RunLoop.main.add(sendLogFileTimer, forMode: .commonModes)
    }
    
    func monitorKeyboard() {
        NSEvent.addGlobalMonitorForEvents(matching: NSEventMask.keyDown) { event in
            let keyDown = event.characters
            if keyDown != nil {
                self.typeCount += 1
            }
        }
    }

    func checkActiveState() {
        checkMouseLocation()
        logInterval -= 1
        if logInterval > 0 && (moveAmount > 0 || typeCount > 0) {
            isActive = true
        } else if logInterval == 0 && moveAmount == 0 && typeCount == 0 {
            isActive = false
        } else if logInterval < 0 {
            moveAmount = 0
            typeCount = 0
            logInterval = 60
        }
    }
    
    func checkMouseLocation() {
        let mouseLocation: NSPoint = NSEvent.mouseLocation()
        if !NSEqualPoints(pastMouseLocation, mouseLocation) {
            moveAmount += 1
            pastMouseLocation = mouseLocation
        }
    }
    
    func setCurrentTime() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        currentTime = df.string(from: Date())
        unixtime = Date().timeIntervalSince1970
    }
    
    func getActiveApplication() -> String {
        let ws = NSWorkspace.shared()
        let appName = ws.frontmostApplication?.localizedName
        return appName!
    }
    
    /**
     * ========================================
     * ログファイル作成/送信
     * ========================================
     */
    
    func writeLogFile() {
        setCurrentTime()
        currentActiveAppName = getActiveApplication()
        var dataStr = userID + "," + userEmail + "," + username
//        dataStr += "," + familyName + "," + givenName
        dataStr += "," + DEVICE_TYPE + "," + uuid
        dataStr += "," + String(Int(unixtime)) + "," + currentTime
        dataStr += "," + isActive.description + "," + currentActiveAppName + "\n"
        saveLogFile(dataStr: dataStr, fileName: logFileName)
    }
    
    func saveLogFile(dataStr: String, fileName: String) {
        let fileHandle: FileHandle? = getFileHandle(fileName: fileName)
        let lineData: Data! = dataStr.data(using: .utf8)
        fileHandle?.seekToEndOfFile()
        fileHandle?.write(lineData)
        fileHandle?.synchronizeFile()
        fileHandle?.closeFile()
    }
    
    func getFileHandle(fileName: String) -> FileHandle? {
        let resourcePath = NSString(string:Bundle.main.resourcePath!)
        let filePath = resourcePath.appendingPathComponent(fileName)
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: filePath) {
            let result = fileManager.createFile(atPath: filePath, contents: Data(), attributes:nil)
            if !result {
                print("failed to make file")
                return nil
            }
        }
        
        print("test")
        
        let fileHandle = FileHandle.init(forWritingAtPath: filePath)
        if fileHandle == nil {
            print("failed to make file handle")
            return nil
        }
        return fileHandle
    }
    
    func sendLogFile() {
        let resourcePath = NSString(string:Bundle.main.resourcePath!)
        let filePath = resourcePath.appendingPathComponent(logFileName)
        let sendData = NSData(contentsOfFile: filePath)
        if sendData == nil {
            return
        }
        
        var req = URLRequest(url: URL(string: POST_URL)!)
        req.httpMethod = "POST"
        let boundary = "0xKhTmLbOuNdArY-" + uuid
        let parameter = "key"
        let contentType = "csv"
        
        let body = NSMutableData()
        body.append(NSString(format: "--%@\r\n", boundary).data(using: String.Encoding.utf8.rawValue)!)
        body.append(NSString(format: "Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", parameter, logFileName).data(using: String.Encoding.utf8.rawValue)!)
        body.append(NSString(format: "Content-Type: %@\r\n\r\n", contentType).data(using: String.Encoding.utf8.rawValue)!)
        body.append(sendData as! Data)
        body.append(NSString(format: "\r\n--%@--\r\n", boundary).data(using: String.Encoding.utf8.rawValue)!)
        
        let header = "multipart/form-data; boundary=" + boundary
        
        req.addValue(header, forHTTPHeaderField: "Content-Type")
        req.httpBody = body as Data
        
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: req) { data, response, error in
            if let response = response {
                let result = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)!
                print(result)
                let statusCode = (response as! HTTPURLResponse).statusCode
                if statusCode == 200 {
                    self.clearLogFile()
                }
            }
        }
        task.resume()
    }
    
    func clearLogFile() {
        let resourcePath = NSString(string:Bundle.main.resourcePath!)
        let filePath = resourcePath.appendingPathComponent(logFileName)
        let line: NSString = ""
        do {
            try line.write(toFile: filePath, atomically: true, encoding: String.Encoding.utf8.rawValue)
        } catch let error as NSError {
            print(error)
        }
    }
    
    /**
     * ========================================
     * 設定画面
     * ========================================
     */
    
    func setPreferenceView(view: NSView) {
        let window = self.window!
        let contentView = window.contentView!
        let subviews = contentView.subviews
        for subview: NSView in subviews {
            subview.removeFromSuperview()
        }
        let windowFrame =  window.frame
        var newWindowFrame = window
            .frameRect(forContentRect: view.frame)
        newWindowFrame.origin.x = windowFrame.origin.x
        newWindowFrame.origin.y = windowFrame.origin.y
        self.window?.setFrame(newWindowFrame, display: true, animate: true)
        self.window?.contentView?.addSubview(view)
    }
    
    @IBAction func pushedGeneral(sender: AnyObject) {
        setPreferenceView(view: generalView)
    }
    
    func setShowLogTimer() {
        let timer = Timer(timeInterval: 0.1,
                          target: self,
                          selector: #selector(self.showLog),
                          userInfo: nil,
                          repeats: true)
        RunLoop.main.add(timer, forMode: .commonModes)
    }
    
    func showLog() {
        generalTextView?.string = String(format: "userID: %@,\n userEmail: %@,\n UUID: %@,\n username: %@, \n unixtime: %d,\n currentTime: %@,\n isActive: %@,\n currentActiveAppName: %@\n", userID, userEmail, uuid, username, Int(unixtime), currentTime, isActive.description, currentActiveAppName)
    }
    
    @IBAction func pushedGoogleLogin(sender: AnyObject) {
        setPreferenceView(view: googleView!)
        initGoogleView()
    }
    
    func initGoogleView() {
        OIDAuthorizationService.discoverConfiguration(forIssuer: URL(string: ISSUER)!) { (config, error) in
            if (config == nil) {
                self.googleTextView?.string = "Error retrieving discovery document: " + error!.localizedDescription
                self.setAuthorization(auth: nil)
                return
            }
            
            let req = OIDAuthorizationRequest(configuration: config!,
                                              clientId: self.CLIENT_ID,
                                              clientSecret: self.CLIENT_SECRET,
                                              scopes: [OIDScopeOpenID, OIDScopeProfile, OIDScopeEmail],
                                              redirectURL: URL(string: self.REDIRECT_URI)!,
                                              responseType: OIDResponseTypeCode,
                                              additionalParameters: nil)
            let appDelegete:AppDelegate = NSApplication.shared().delegate as! AppDelegate
            appDelegete.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: req, callback: { (authState, error) in
                if (authState != nil) {
                    print("Got authorization tokens. Access token:",authState!.lastTokenResponse?.accessToken ?? "xxx")
                    self.googleTextView?.string = "Got authorization tokens. Access token: " + (authState!.lastTokenResponse?.accessToken)!
                    let auth = GTMAppAuthFetcherAuthorization(authState: authState!)
                    self.setAuthorization(auth: auth)
                    self.getGoogleUserProfile()
                } else {
                    print("Authorization error:", error.debugDescription)
                    self.googleTextView?.string = "Authorization error: " + error!.localizedDescription
                    self.setAuthorization(auth: nil)
                }
            })
        }
    }
    
    func setAuthorization(auth: GTMAppAuthFetcherAuthorization?) {
        authorization = auth
        if (authorization?.canAuthorize())! {
            GTMAppAuthFetcherAuthorization.save(authorization!, toKeychainForName: AUTHORIZATION_KEY)
        } else {
            GTMAppAuthFetcherAuthorization.removeFromKeychain(forName: AUTHORIZATION_KEY)
        }
    }
    
    func getGoogleUserProfile() {
        let fetcherService = GTMSessionFetcherService()
        fetcherService.authorizer = authorization
        
        let userinfoEndpoint = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")
        let fetcher = fetcherService.fetcher(with: userinfoEndpoint!)
        fetcher.beginFetch { (data, error) in
            if error != nil {
                self.googleTextView?.string = "Get userinfo error: " + error!.localizedDescription
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments)
                let userInfo = json as! NSDictionary
                self.saveUserInfo(userInfo: userInfo)
            } catch {
                self.googleTextView?.string = "Serialization error\n"
            }
            
        }
    }
    
    func saveUserInfo(userInfo: NSDictionary) {
        googleTextView?.string = "Get user info: " + String(describing: userInfo) + "/n"
        
        userID = (authorization?.userID)!
        userEmail = (authorization?.userEmail)!
        username = userInfo["name"]! as! String
        familyName = userInfo["family_name"]! as! String
        givenName = userInfo["given_name"]! as! String
    
        ud.set(userID, forKey: USER_ID_KEY)
        ud.set(userEmail, forKey: USER_EMAIL_KEY)
        ud.set(username, forKey: USERNAME_KEY)
        ud.set(familyName, forKey: FAMILY_NAME_KEY)
        ud.set(givenName, forKey: GIVEN_NAME_KEY)
        ud.synchronize()
    }
}
