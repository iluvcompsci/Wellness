//
//  WeatherModel.swift
//  Wellness
//
//  Created by Bri Chapman on 4/3/15.
//  Copyright (c) 2015 com.bchapman. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit
import CoreData

class WeatherModel: NSObject, CLLocationManagerDelegate, NSURLConnectionDelegate {
    private var resultsDictionary : NSDictionary?
    var currentWeather : NSDictionary?{
        get{
            return getCurrentForecast()
        }
    }
    var dailyWeather : NSDictionary {
        get{
            return getForecast(NSTimeInterval(12*60)).daily!
        }
    }
    var latitude : CLLocationDegrees
    var longitude : CLLocationDegrees
    
    init(latitude: CLLocationDegrees, longitude:CLLocationDegrees) {
        self.latitude = latitude
        self.longitude = longitude
        super.init()
    }
    
    func isGoodTimeToGoOutside() -> Bool {
        let timeNeededForWorkout = 30
        let maximumComfortableTemperature = 90
        let minimumComfortableTemperature = 15
        let minimumAcceptablePrecipitationProbability = 45
        let minimumAcceptableVisibility = 4
        if (mightRainSoon(timeNeededForWorkout) || mightBeTooHot(maximumComfortableTemperature) || mightBeTooCold(minimumComfortableTemperature) || mightBeRainy(Double(minimumAcceptablePrecipitationProbability)/100.0) || mightBeDark(timeNeededForWorkout) || mightBeHardToSee(minimumAcceptableVisibility)){
            return false
        } else {
            return true
        }
    }
    
    //MARK: Forecast
    private func findForecastForTime(time:NSDate) -> NSDictionary {
        // returns instantaneous forecast at the date specified
        // we want the forecast to expire earlier (be updated now) if it will be expired by the requested time
        let maxAcceptableAgeAtRequestTime = NSTimeInterval(12*60)
        let timeSinceRequestTime = NSDate().timeIntervalSinceDate(time)
        let maxAcceptableAge = maxAcceptableAgeAtRequestTime + timeSinceRequestTime
        let forecast = getForecast((maxAcceptableAge < maxAcceptableAgeAtRequestTime ? maxAcceptableAgeAtRequestTime : maxAcceptableAge))
        let dailyForecast = forecast.daily
        let currentForecast = forecast.current
        let lastUpdated = forecast.lastUpdated
        
        var closestIndex = -1
        var minDifference = Double(INT32_MAX)
        var dataArray = NSArray()
        if let todaysForecast = dailyForecast as NSDictionary? {
            if let dataDictionary: AnyObject = todaysForecast["data"] {
                println("Data dictionary worked")
                let numberOfMeasurements = dataDictionary.count
                dataArray = dataDictionary as! NSArray
                for dataSet in 0..<numberOfMeasurements{
                    if let dataPoint: AnyObject = dataDictionary[dataSet] {
                        let time = dataPoint["time"]! as! Double
                        let currentTime = NSDate().timeIntervalSince1970
                        let difference = abs(time - currentTime)
                        println(difference)
                        if (difference < minDifference){
                            println("updated closest index to \(dataSet)")
                            closestIndex = dataSet
                            minDifference = difference
                        }
                    }
                }
            }
        }
        if dataArray.count > closestIndex && closestIndex != -1{
            println(dataArray[closestIndex])
            return dataArray[closestIndex] as! NSDictionary
        }
        return NSDictionary()
    }
    
//    private func getForecastRange(endTime:NSDate) -> [NSDictionary]{
//        //returns all forecasts until the end time
//        
//    }
    
    private func getCurrentForecast() -> NSDictionary {
        return findForecastForTime(NSDate())
    }
    
    private func updateForecast(){
        let darkSkyAPIURL = "https://api.forecast.io/forecast/43e13a756562cd2adb37800c6bc9b58d/\(latitude),\(longitude)"
        let request = NSMutableURLRequest(URL: NSURL(string: darkSkyAPIURL)!, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20.0)
        request.HTTPMethod = "GET"
        var error : NSError?
        var response : NSURLResponse?
        
        let data = NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error: &error)
        if let dataReturned = data {
            var inError : NSError?
            self.resultsDictionary = NSJSONSerialization.JSONObjectWithData(dataReturned, options: .allZeros, error: &inError) as! NSDictionary!
            storeCurrentForecast(resultsDictionary!)
        }
    }
    
    private func storeCurrentForecast(results: NSDictionary){
        let current:NSDictionary = results["currently"] as! NSDictionary!
        let daily:NSDictionary = results["daily"] as! NSDictionary!

        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let context : NSManagedObjectContext = appDelegate.managedObjectContext!
        let entity : NSEntityDescription = NSEntityDescription.entityForName("Forecast", inManagedObjectContext: context)!
        let frequency = NSFetchRequest(entityName: "Forecast")
        
        var forecast : Forecast = Forecast(entity:entity, insertIntoManagedObjectContext:context)
        var dailyForecastData = NSMutableData()
        var dailyForecastArchiver = NSKeyedArchiver(forWritingWithMutableData: dailyForecastData)
        dailyForecastArchiver.encodeObject(daily)
        dailyForecastArchiver.finishEncoding()
        
        var currentForecastData = NSMutableData()
        var currentForecastArchiver = NSKeyedArchiver(forWritingWithMutableData: currentForecastData)
        currentForecastArchiver.encodeObject(current)
        currentForecastArchiver.finishEncoding()

        forecast.dailyForecast = dailyForecastData
        forecast.currentForecast = currentForecastData
        forecast.lastUpdated = NSDate()
        var err: NSError?
        
        context.save(&err)
        
        if err != nil {
            println(err?.description)
        }
    }
    
    private func getForecast(maxAcceptableAge: NSTimeInterval) -> (current: NSDictionary?, daily: NSDictionary?, lastUpdated:NSDate){
        
        let appDelegate : AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let context : NSManagedObjectContext = appDelegate.managedObjectContext!
        let forecastFrequency = NSFetchRequest(entityName: "Forecast")
        var err: NSError?
        var forecasts = context.executeFetchRequest(forecastFrequency, error: &err)!
        println(forecasts)
        if err != nil {
            println(err?.description)
        }
        if forecasts.count == 0 {
            updateForecast()
            forecasts = context.executeFetchRequest(forecastFrequency, error: &err)!
        }
        if let extractedForecast = forecasts[0] as? Forecast {
            let age = NSDate().timeIntervalSince1970 - extractedForecast.lastUpdated.timeIntervalSince1970
            if age > maxAcceptableAge {
                // update the forecast if it is too old
                updateForecast()
            }
            let currentForecastData = extractedForecast.currentForecast
            var currentUnarchiver = NSKeyedUnarchiver(forReadingWithData: currentForecastData)
            var currentDictionary: NSDictionary? = currentUnarchiver.decodeObject() as? NSDictionary
            currentUnarchiver.finishDecoding()
            
            let dailyForecastData = extractedForecast.dailyForecast
            var dailyUnarchiver = NSKeyedUnarchiver(forReadingWithData: dailyForecastData)
            var dailyDictionary: NSDictionary? = dailyUnarchiver.decodeObject() as? NSDictionary
            dailyUnarchiver.finishDecoding()
            
            return (current: currentDictionary, daily:dailyDictionary, lastUpdated:extractedForecast.lastUpdated)
        }
        return (current: nil, daily: nil, lastUpdated:NSDate())
    }
    
    //MARK: Conditions
    private func mightBeRainy(minAcceptablePrecipProbaility: Double) -> Bool{
        if let current = currentWeather{
            let precipProbability = current["precipProbability"] as! Double
            let precipIntensity = current["precipIntensity"] as! Double
            if ((precipProbability) < minAcceptablePrecipProbaility) && ((precipIntensity) < Double(0.25)){
                return false
            } else {
                println("Might be rainy")
                return true
            }
        } else {
            return true
        }
    }
    
    private func mightBeTooHot(maxApparentTemp: Int) -> Bool{
        if let current = currentWeather {
            let apparentTemperature = current["apparentTemperature"] as! Int
            if (apparentTemperature) < maxApparentTemp{
                return false
            } else {
                println("Might be too hot")
                return true
            }
        }
        return true
    }
    
    private func mightBeTooCold(minApparentTemp:Int) -> Bool {
        if let current = currentWeather {
            let apparentTemperature = current["apparentTemperature"] as! Int
            if (apparentTemperature) > minApparentTemp {
                return false
            } else {
                println("Might be too cold")
                return true
            }
        }
        return true
    }
    
    private func mightRainSoon(maxTimeUntilRain: Int) -> Bool{
        //look at all future forecasts until the max time and decide whether there is a chance of rain
        
        return false
    }

    private func mightBeDark(timeNeededBeforeDark: Int) -> Bool {
        if let current = currentWeather {
            var mightBeDark : Bool = false
            let sunriseTime = current["sunriseTime"] as! Double
            let sunsetTime = current["sunsetTime"] as! Double
            let currentTime = NSDate().timeIntervalSince1970 as Double
            //look at the current time and if it is before sunrise, then return true
            if (currentTime < sunriseTime){
                println("It's before sunrise, it might be dark")
                return true
            }
            //look at the sunset time and decide whether we have enough time for the workout before the sun goes down.
            let timeUntilSunset = sunsetTime - currentTime
            println(timeUntilSunset)
            if timeUntilSunset < Double(timeNeededBeforeDark) {
                println("There is not enough time before sunset")
                return true
            }
            return false
        }
        return true
    }
    
    private func mightBeHardToSee(minVisibility: Int) -> Bool {
        return false
    }
    
}