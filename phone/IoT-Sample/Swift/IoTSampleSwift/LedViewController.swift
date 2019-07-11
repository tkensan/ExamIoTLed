//
//  LedViewController.swift
//  IoTSampleSwift
//
//  Created by tken on 2019/07/04.
//  Copyright © 2019 Amazon. All rights reserved.
//

import UIKit
import AWSIoT

class LedViewController: UIViewController {

    @IBOutlet weak var switchLed: UISwitch!
    @IBOutlet weak var switchPower: UISwitch!
    @IBOutlet weak var switchConnection: UISwitch!
    @IBOutlet weak var switchHeartbeat: UISwitch!
    @IBOutlet weak var switchTurnLed: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        print("Led viewDidLoad")
        self.switchLed.isEnabled = false
        self.switchPower.isEnabled = false
        self.switchConnection.isEnabled = false
        self.switchHeartbeat.isEnabled = false
        self.switchTurnLed.isEnabled = true
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    struct LedShadowMetadataValue: Codable {
        let timestamp: Int
    }
    struct LedShadowMetadataItem: Codable {
        let connected: LedShadowMetadataValue?
        let heartbeat: LedShadowMetadataValue?
        let power: LedShadowMetadataValue?
        let light: LedShadowMetadataValue?
    }
    struct LedShadowStateItem: Codable {
        let connected: Int?
        let heartbeat: Int?
        let power: Int?
        let light: Int?

    }
    struct LedShadowMetadata: Codable {
        let desired: LedShadowMetadataItem?
        let reported: LedShadowMetadataItem
    }
    struct LedShadowState: Codable {
        let desired: LedShadowStateItem?
        let reported: LedShadowStateItem?
    }
    struct LedShadowData: Codable {
        let metadata: LedShadowMetadata
        let state: LedShadowState
        let version: Int
        let timestamp: Int?
    }
    struct LedShadowDocument: Codable {
        let current: LedShadowData
        let previous: LedShadowData
        let timestamp: Int
    }
    struct LedShadowUpdate: Codable {
        let state: LedShadowState
    }

    func updateSwitches(withReport report: LedShadowStateItem) -> Void {
        DispatchQueue.main.async {
            self.switchLed.setOn((report.light! != 0), animated: true)
            self.switchPower.setOn((report.power! != 0), animated: true)
            self.switchConnection.setOn((report.connected! != 0), animated: true)
            self.switchHeartbeat.setOn(report.heartbeat! != 0, animated: true)
        }
    }

    @IBAction func changedTurnLed(_ sender: UISwitch) {
        let iotDataManager = AWSIoTDataManager(forKey: ASWIoTDataManager)
        let on = sender.isOn ? 1 : 0
        let update = LedShadowUpdate(
            state: LedShadowState(
                desired: LedShadowStateItem(connected: nil, heartbeat: nil, power: nil, light: on),
                reported: nil))
        let data = try! JSONEncoder().encode(update)
        let str = String(data: data, encoding: .utf8)
        iotDataManager.updateShadow("ExamIoTLED", jsonString: str!)
    }

    override func viewWillAppear(_ animated: Bool) {
        let iotDataManager = AWSIoTDataManager(forKey: ASWIoTDataManager)
        iotDataManager.register(
            withShadow: "ExamIoTLED",
            options: nil,
            eventCallback: { (name, operation, status, clientToken, payload) -> Void in
            switch status {
            case .documents:
                print("Shadow document")
                let doc = try! JSONDecoder().decode(LedShadowDocument.self, from: payload)
                let report = doc.current.state.reported!
                self.updateSwitches(withReport: report)
            case .accepted:
                print("Shadow accepted")
                if operation == .get {
                    print("Shadow accepted by get")
                    let data = try! JSONDecoder().decode(LedShadowData.self, from: payload)
                    let report = data.state.reported!
                    self.updateSwitches(withReport: report)
                }
            case .rejected:
                print("Shadow rejected")
            case .delta:
                print("Shadow delta")
            case .count:
                print("Shadow count")
            case .foreignUpdate:
                print("Shadow foreignUpdate")
            case .timeout:
                print("Shadow timeout")
            @unknown default:
                print("Shadow unknown")
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: { () -> Void in
            iotDataManager.getShadow("ExamIoTLED") })

    }

    override func viewWillDisappear(_ animated: Bool) {
        let iotDataManager = AWSIoTDataManager(forKey: ASWIoTDataManager)
        iotDataManager.unregister(fromShadow: "ExamIoTLED")
    }

}
