

@objc(CameraPreview) class CameraPreview : CDVPlugin {


    var window: UIWindow?
    var fontVC = FontCameraViewController()
    var backVC = BackCameraViewController()
    var isBack = true
    var colorBackground: String? = "#1d3664"


    @objc(startCamera:)
    func startCamera(command: CDVInvokedUrlCommand) {
    if(command.arguments[13] as! String == 'white'){
    colorBackground = "#FFFFFF"
    }
        if command.arguments[4] as! String == "back" {
            isBack = true
            fontVC = FontCameraViewController()
            fontVC.colorBackground =colorBackground!
            window = UIWindow(frame: UIScreen.main.bounds)
            window?.rootViewController = fontVC
            window?.makeKeyAndVisible()

            fontVC.segmentSelectionAtIndex = {[weak self] (str) in
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: str);
                pluginResult?.setKeepCallbackAs(true)
                self!.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
        }else {
            isBack = false
            backVC = BackCameraViewController()
            backVC.colorBackground = colorBackground!
            window = UIWindow(frame: UIScreen.main.bounds)
            window?.rootViewController = backVC
            window?.makeKeyAndVisible()

            backVC.segmentSelectionAtIndex = {[weak self] (str) in
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: str);
                pluginResult?.setKeepCallbackAs(true)
                self!.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
        }
    }


    @objc(takeSnapshot:)
    func takeSnapshot(command: CDVInvokedUrlCommand) {
        if isBack == true {
            fontVC.segmentSelectionAtIndex2 = {[weak self] (image) in
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: image as Data);
                self!.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
            fontVC.tapShot()
        }else {
            backVC.segmentSelectionAtIndex2 = {[weak self] (image) in
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: image as Data);
                self!.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
            backVC.tapShot()
        }
    }


    @objc(stopCamera:)
    func stopCamera(command: CDVInvokedUrlCommand) {
        if isBack == true {
            fontVC.tapStop()
            window?.removeFromSuperview()
            self.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "stop Camera");
            self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
        }else {
            backVC.tapStop()
            window?.removeFromSuperview()
            self.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "stop Camera");
            self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
        }
    }


    @objc(takePicture:)
    func takePicture(command: CDVInvokedUrlCommand) {
        if isBack == true {
            fontVC.segmentSelectionAtIndex2 = {[weak self] (image) in
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: image as Data);
                self!.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
            fontVC.tapShot()
        }else {
            backVC.segmentSelectionAtIndex2 = {[weak self] (image) in
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: image as Data);
                self!.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
            backVC.tapShot()
        }
    }

    @objc(onBackButton:)
    func onBackButton(command: CDVInvokedUrlCommand) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        if self.isBack == true {
            self.fontVC.backCallBack = {[weak self] () in
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "back Button");
                self!.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
        }else {
            self.backVC.backCallBack = {[weak self] () in
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "back Button");
                self!.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
        }
    }
    }
}
