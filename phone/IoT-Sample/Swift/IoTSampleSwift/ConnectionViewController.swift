/*
* Copyright 2010-2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License").
* You may not use this file except in compliance with the License.
* A copy of the License is located at
*
*  http://aws.amazon.com/apache2.0
*
* or in the "license" file accompanying this file. This file is distributed
* on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
* express or implied. See the License for the specific language governing
* permissions and limitations under the License.
*/

import UIKit
import AWSIoT
import AWSMobileClient

class ConnectionViewController: UIViewController, UITextViewDelegate {

    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var logTextView: UITextView!

    @objc var connected = false;
    @objc var publishViewController : UIViewController!;
    @objc var subscribeViewController : UIViewController!;
    @objc var configurationViewController : UIViewController!;
    @objc var ledViewController : UIViewController!;

    @objc var iotDataManager: AWSIoTDataManager!;
    @objc var iotManager: AWSIoTManager!;
    @objc var iot: AWSIoT!

    @IBAction func connectButtonPressed(_ sender: UIButton) {

        let tabBarViewController = tabBarController as! IoTSampleTabBarController

        sender.isEnabled = false

        func mqttEventCallback( _ status: AWSIoTMQTTStatus )
        {
            DispatchQueue.main.async {
                print("connection status = \(status.rawValue)")
                switch(status)
                {
                    case .connecting:
                        tabBarViewController.mqttStatus = "Connecting..."
                        print( tabBarViewController.mqttStatus )
                        self.logTextView.text = tabBarViewController.mqttStatus

                    case .connected:
                        tabBarViewController.mqttStatus = "Connected"
                        print( tabBarViewController.mqttStatus )
                        sender.setTitle( "Disconnect", for:UIControl.State())
                        self.activityIndicatorView.stopAnimating()
                        self.connected = true
                        sender.isEnabled = true
                        let uuid = UUID().uuidString;
                        let defaults = UserDefaults.standard
                        let certificateId = defaults.string( forKey: "certificateId")

                        self.logTextView.text = "Using certificate:\n\(certificateId!)\n\n\nClient ID:\n\(uuid)"

                        tabBarViewController.viewControllers = [ self, self.publishViewController, self.subscribeViewController, self.ledViewController ]

                    case .disconnected:
                        tabBarViewController.mqttStatus = "Disconnected"
                        print( tabBarViewController.mqttStatus )
                        self.activityIndicatorView.stopAnimating()
                        self.logTextView.text = nil

                    case .connectionRefused:
                        tabBarViewController.mqttStatus = "Connection Refused"
                        print( tabBarViewController.mqttStatus )
                        self.activityIndicatorView.stopAnimating()
                        self.logTextView.text = tabBarViewController.mqttStatus

                    case .connectionError:
                        tabBarViewController.mqttStatus = "Connection Error"
                        print( tabBarViewController.mqttStatus )
                        self.activityIndicatorView.stopAnimating()
                        self.logTextView.text = tabBarViewController.mqttStatus

                    case .protocolError:
                        tabBarViewController.mqttStatus = "Protocol Error"
                        print( tabBarViewController.mqttStatus )
                        self.activityIndicatorView.stopAnimating()
                        self.logTextView.text = tabBarViewController.mqttStatus

                    default:
                        tabBarViewController.mqttStatus = "Unknown State"
                        print("unknown state: \(status.rawValue)")
                        self.activityIndicatorView.stopAnimating()
                        self.logTextView.text = tabBarViewController.mqttStatus
                }
                
                NotificationCenter.default.post( name: Notification.Name(rawValue: "connectionStatusChanged"), object: self )
            }
        }

        if (connected == false)
        {
            activityIndicatorView.startAnimating()

            let defaults = UserDefaults.standard
            var certificateId = defaults.string( forKey: "certificateId")

            if (certificateId == nil)
            {
                DispatchQueue.main.async {
                    self.logTextView.text = "No identity available, searching bundle..."
                }
                
                // No certificate ID has been stored in the user defaults; check to see if any .p12 files
                // exist in the bundle.
                let myBundle = Bundle.main
                let myImages = myBundle.paths(forResourcesOfType: "p12" as String, inDirectory:nil)
                let uuid = UUID().uuidString;
                
                if (myImages.count > 0) {
                    // At least one PKCS12 file exists in the bundle.  Attempt to load the first one
                    // into the keychain (the others are ignored), and set the certificate ID in the
                    // user defaults as the filename.  If the PKCS12 file requires a passphrase,
                    // you'll need to provide that here; this code is written to expect that the
                    // PKCS12 file will not have a passphrase.
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: myImages[0])) {
                        DispatchQueue.main.async {
                            self.logTextView.text = "found identity \(myImages[0]), importing..."
                        }
                        if AWSIoTManager.importIdentity( fromPKCS12Data: data, passPhrase:"", certificateId:myImages[0]) {
                            // Set the certificate ID and ARN values to indicate that we have imported
                            // our identity from the PKCS12 file in the bundle.
                            defaults.set(myImages[0], forKey:"certificateId")
                            defaults.set("from-bundle", forKey:"certificateArn")
                            DispatchQueue.main.async {
                                self.logTextView.text = "Using certificate: \(myImages[0]))"
                                self.iotDataManager.connect( withClientId: uuid, cleanSession:true, certificateId:myImages[0], statusCallback: mqttEventCallback)
                            }
                        }
                    }
                }
                
                certificateId = defaults.string( forKey: "certificateId")
                if (certificateId == nil) {
                    DispatchQueue.main.async {
                        self.logTextView.text = "No identity found in bundle, creating one..."
                    }

                    // Now create and store the certificate ID in NSUserDefaults
                    let csrDictionary = [ "commonName":CertificateSigningRequestCommonName, "countryName":CertificateSigningRequestCountryName, "organizationName":CertificateSigningRequestOrganizationName, "organizationalUnitName":CertificateSigningRequestOrganizationalUnitName ]

                    self.iotManager.createKeysAndCertificate(fromCsr: csrDictionary, callback: {  (response ) -> Void in
                        if (response != nil)
                        {
                            defaults.set(response?.certificateId, forKey:"certificateId")
                            defaults.set(response?.certificateArn, forKey:"certificateArn")
                            certificateId = response?.certificateId
                            print("response: [\(String(describing: response))]")

                            let attachPrincipalPolicyRequest = AWSIoTAttachPrincipalPolicyRequest()
                            attachPrincipalPolicyRequest?.policyName = PolicyName
                            attachPrincipalPolicyRequest?.principal = response?.certificateArn
                            
                            // Attach the policy to the certificate
                            self.iot.attachPrincipalPolicy(attachPrincipalPolicyRequest!).continueWith (block: { (task) -> AnyObject? in
                                if let error = task.error {
                                    print("failed: [\(error)]")
                                }
                                print("result: [\(String(describing: task.result))]")
                                
                                // Connect to the AWS IoT platform
                                if (task.error == nil)
                                {
                                    DispatchQueue.main.asyncAfter(deadline: .now()+2, execute: {
                                        self.logTextView.text = "Using certificate: \(certificateId!)"
                                        self.iotDataManager.connect( withClientId: uuid, cleanSession:true, certificateId:certificateId!, statusCallback: mqttEventCallback)

                                    })
                                }
                                return nil
                            })
                        }
                        else
                        {
                            DispatchQueue.main.async {
                                sender.isEnabled = true
                                self.activityIndicatorView.stopAnimating()
                                self.logTextView.text = "Unable to create keys and/or certificate, check values in Constants.swift"
                            }
                        }
                    } )
                }
            }
            else
            {
                let uuid = UUID().uuidString;

                // Connect to the AWS IoT service
                iotDataManager.connect( withClientId: uuid, cleanSession:true, certificateId:certificateId!, statusCallback: mqttEventCallback)
            }
        }
        else
        {
            activityIndicatorView.startAnimating()
            logTextView.text = "Disconnecting..."

            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                self.iotDataManager.disconnect();
                DispatchQueue.main.async {
                    self.activityIndicatorView.stopAnimating()
                    self.connected = false
                    sender.setTitle( "Connect", for:UIControl.State())
                    sender.isEnabled = true
                    tabBarViewController.viewControllers = [ self, self.configurationViewController ]
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tabBarViewController = tabBarController as! IoTSampleTabBarController
        publishViewController = tabBarViewController.viewControllers![1]
        subscribeViewController = tabBarViewController.viewControllers![2]
        configurationViewController = tabBarViewController.viewControllers![3]
        ledViewController = tabBarViewController.viewControllers![4]

        tabBarViewController.viewControllers = [ self, configurationViewController ]
        logTextView.resignFirstResponder()

        // Initialize AWSMobileClient for authorization
        AWSMobileClient.sharedInstance().initialize { (userState, error) in
            guard error == nil else {
                print("Failed to initialize AWSMobileClient. Error: \(error!.localizedDescription)")
                return
            }
            print("AWSMobileClient initialized.")
        }
        
        // Init IOT
        let iotEndPoint = AWSEndpoint(urlString: IOT_ENDPOINT)
        
        // Configuration for AWSIoT control plane APIs
        let iotConfiguration = AWSServiceConfiguration(region: AWSRegion, credentialsProvider: AWSMobileClient.sharedInstance())
        
        // Configuration for AWSIoT data plane APIs
        let iotDataConfiguration = AWSServiceConfiguration(region: AWSRegion,
                                                           endpoint: iotEndPoint,
                                                           credentialsProvider: AWSMobileClient.sharedInstance())
        AWSServiceManager.default().defaultServiceConfiguration = iotConfiguration

        iotManager = AWSIoTManager.default()
        iot = AWSIoT.default()

        AWSIoTDataManager.register(with: iotDataConfiguration!, forKey: ASWIoTDataManager)
        iotDataManager = AWSIoTDataManager(forKey: ASWIoTDataManager)
    }
}

