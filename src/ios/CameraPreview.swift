

@objc(CameraPreview) class CameraPreview : CDVPlugin {


    var window: UIWindow?
    var fontVC = FontCameraViewController()
    var backVC = BackCameraViewController()
    var isBack = true


    @objc(startCamera:)
    func startCamera(command: CDVInvokedUrlCommand) {
        if command.arguments[4] as! String == "back" {
            isBack = true
            fontVC = FontCameraViewController()
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
            fontVC.tapShot()
            fontVC.segmentSelectionAtIndex2 = {[weak self] (image) in
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: image as Data);
                self!.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
        }else {
            backVC.tapShot()
            backVC.segmentSelectionAtIndex2 = {[weak self] (image) in
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: image as Data);
                self!.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
        }
    }


    @objc(stopCamera:)
    func stopCamera(command: CDVInvokedUrlCommand) {
        if isBack == true {
            fontVC.tapStop()
            self.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "stop Camera");
            self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
        }else {
            backVC.tapStop()
            self.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "stop Camera");
            self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
        }
    }

    @objc(takePicture:)
    func takePicture(command: CDVInvokedUrlCommand) {
        if isBack == true {
                fontVC.tapShot()
                fontVC.segmentSelectionAtIndex2 = {[weak self] (image) in
                    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: image as Data);
                    self!.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
                }
        }else {
                backVC.tapShot()
                backVC.segmentSelectionAtIndex2 = {[weak self] (image) in
                    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: image as Data);
                    self!.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
                }
            }
    }

    @objc(onBackButton:)
    func onBackButton(command: CDVInvokedUrlCommand) {}
}
