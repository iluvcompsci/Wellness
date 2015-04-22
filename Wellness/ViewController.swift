//
//  ViewController.swift
//  Wellness
//
//  Created by Bri Chapman on 4/3/15.
//  Copyright (c) 2015 com.bchapman. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    private var latitude : CLLocationDegrees!{
        get {
            return locationManager.location.coordinate.latitude
        }
    }
    private var longitude : CLLocationDegrees!{
        get {
            return locationManager.location.coordinate.longitude
        }
    }
    private var locationManagerStatus : CLAuthorizationStatus? {
        get{
            let key = NSString(string: "locationAuthorizationStatus")
            let authorizationHash: Int = NSUserDefaults.standardUserDefaults().valueForKey(key as String) as! Int
            return CLAuthorizationStatus(rawValue: Int32(authorizationHash))
        }
        set{
            if let newStatus = newValue {
                NSUserDefaults.standardUserDefaults().setObject(Int(newStatus.rawValue), forKey: "locationAuthorizationStatus")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        startLocationUpdates()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func startLocationUpdates(){
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers

        let authorizationStatus = CLLocationManager.authorizationStatus()
        
        switch (authorizationStatus){
        case .Denied:
            println("LocationManager status denied")
        case .AuthorizedAlways:
            println("LocationManager status authorized always")
            locationManager.startMonitoringSignificantLocationChanges()
        case .AuthorizedWhenInUse:
            println("LocationManager status authorized when in use")
            locationManager.startMonitoringSignificantLocationChanges()
        case .NotDetermined:
            println("LocationManager status not determined")
            locationManager.requestAlwaysAuthorization()
        case .Restricted:
            println("LocationManager status restricted")
        }

    }
    
    private func goOutside(){
        sendNotification("Get outside!", text: "Perfect weather to get out and move!")
    }
    
    private func sendNotification(title: String, text: String){
        
    }
    
    private func isAGoodTimeToBeOutside() -> Bool{
        let qos = Int(QOS_CLASS_BACKGROUND.value)
        var currentConditions : Bool = false
        dispatch_async(dispatch_get_global_queue(qos, 0), {
            if let latitude = self.latitude {
                if let longitude = self.longitude {
                    currentConditions = WeatherModel(latitude: self.latitude, longitude:self.longitude).isGoodTimeToGoOutside()
                }
            }
        })
        return currentConditions
    }
    // MARK: Location Manager Delegate
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        //stop from updating to save battery?
        //manager.stopUpdatingLocation()
        
        //check the location to see if it is a good time to go outside 
        if isAGoodTimeToBeOutside(){
            goOutside()
        }
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        println("LocationManager failed: \(error.description)")
    }
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        locationManagerStatus = status
        startLocationUpdates()
    }
}

