//
//  ShareViewController.swift
//  Share Extension
//
//  Routes files/images/text shared into MedShelf back to the host app,
//  which then shows the "Save to…" destination sheet.
//
import UIKit
import Social

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Delegate to receive_sharing_intent plugin (loaded dynamically by main app).
        // This extension auto-redirects to the main app via custom URL scheme.
        redirectToApp()
    }

    private func redirectToApp() {
        if let extensionContext = extensionContext {
            extensionContext.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
