import UIKit
import WebKit
import JavaScriptCore

class ViewController: UIViewController {
    
    var webView: WKWebView?
    var webConfig:WKWebViewConfiguration {
        get {
            let webCfg:WKWebViewConfiguration = WKWebViewConfiguration()
            let userController:WKUserContentController = WKUserContentController()
                webCfg.userContentController = userController
            return webCfg
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.webView = WKWebView (frame: self.view.frame, configuration: self.webConfig)
        self.webView!.uiDelegate = self
        // Handle exceptions
        let context = JSContext()
        context?.exceptionHandler = self.jsExceptionHandler
        view.addSubview(self.webView!)
        
        // auto resize and prevent some unneeded gestures
        self.webView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.webView!.scrollView.isScrollEnabled = false
        self.webView!.scrollView.panGestureRecognizer.isEnabled = false
        self.webView!.scrollView.bounces = false
        
        // load files
        let assetFilesToLoad = [
            "style": "css",
            "babylon.2.2": "js",
            "app": "js"
        ]
        for (fileName, fileExt) in assetFilesToLoad {
            if let filePath = Bundle.main.path(forResource: fileName, ofType: fileExt) {
                _ = self.copyFileToTmpForServingAsStaticAsset(filePath: URL(fileURLWithPath: filePath))
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.loadHtml()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // TODO: fix this hack to load the index.html file
        let fileName = String("\(ProcessInfo.processInfo.globallyUniqueString)_index.html")
        
        let tmpPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: tmpPath)
        } catch {
            
        }

        self.webView = nil

    }

}

extension ViewController {
    
    // TODO: hack for serving the assets form the /tmp/assets/ path, ios9 will solve this
    //       meanwhile its a todo to refactor this in a better way
    func copyFileToTmpForServingAsStaticAsset(filePath: URL) -> String? {
        let fileMgr = FileManager.default
        let tmpPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("assets")
        
        do {
            try fileMgr.createDirectory(at: tmpPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Couldn't create assets subdirectory. \(error)")
            return nil
        }
        
        let dstPath = tmpPath.appendingPathComponent(filePath.lastPathComponent)
        if fileMgr.fileExists(atPath: dstPath.absoluteString) == false {
            do {
                try fileMgr.copyItem(at: filePath, to: dstPath)
            } catch {
                print("Couldn't copy file to /tmp/assets. \(error)")
                return nil
            }
        }
        return dstPath.absoluteString
    }
    
    func jsExceptionHandler(ctx: JSContext!, val: JSValue!) {
        print("%@", val)
    }
    
    func getFileContentsAsString(filePath: String) -> String? {
        do {
            let script = try String(contentsOfFile: filePath, encoding: .utf8)
            return script
        } catch {
            return nil
        }
    }
    
    // File Loading
    func loadHtml() {
        // NOTE: Due to a bug in webKit as of iOS 8.1.1 we CANNOT load a local resource when running on device. Once that is fixed, we can get rid of the temp copy
        let mainBundle = Bundle(for: ViewController.self)
        
        let fileName = String("\(ProcessInfo.processInfo.globallyUniqueString)_index.html")
        
        let tmpPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        guard let htmlPath = mainBundle.path(forResource: "index", ofType: "html") else {
            self.showAlert(message: "Could not load Html file")
            return
        }
        
        do {
            try FileManager.default.copyItem(at: URL(fileURLWithPath: htmlPath), to: tmpPath)
            let requestUrl = URLRequest(url: tmpPath)
            self.webView?.load(requestUrl)
        } catch {
            
        }
        
    }
    
    func showAlert(message:String) {
        let alertAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.dismiss(animated: true, completion: nil)
        }
        
        let alertView = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertView.addAction(alertAction)
        
        self.present(alertView, animated: true, completion: nil)
    }
    
}

extension ViewController: WKUIDelegate {
    
    func webView(webView: WKWebView, exceptionWasRaised navigation: WKNavigation!, withError error: NSError) {
        print("%s. With Error %@", #function, error)
        self.showAlert(message: "Failed to load file with error \(error.localizedDescription)!")
    }

    func webView(webView: WKWebView, failedToParseSource navigation: WKNavigation!, withError error: NSError) {
        print("%s. With Error %@", #function, error)
        showAlert(message: "Failed to load file with error \(error.localizedDescription)!")
    }

    // WKUIDelegate
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        print("%s", #function)
    }

    func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
        print("%s. With Error %@", #function, error)
        self.showAlert(message: "Failed to load file with error \(error.localizedDescription)!")
    }

}

