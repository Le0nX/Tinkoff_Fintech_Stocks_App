//
//  ViewController.swift
//  Stocks
//
//  Created by Denis Nefedov on 12/09/2018.
//  Copyright © 2018 Tinkoff. All rights reserved.
//

import UIKit
import Foundation           // check internet conn
import SystemConfiguration  // check internet conn

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    
    @IBOutlet weak var companyImage: UIImageView!
    @IBOutlet weak var companyNameLabel: UILabel!
    @IBOutlet weak var companySymbolLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var companyPickerView: UIPickerView!
    
    // MARK: dict with some companies for test case.
    private var companies = [String: String]()
    
    // MARK: UIPickerViewDataSource protocol. Get number of components.
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // MARK: UIPickerViewDataSource protocol. Get number of stocks in companies dict.
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.companies.keys.count
    }
    
    // MARK: requesting for update of our information about stock
    private func requestQuoteUpdate() {
        self.activityIndicator.startAnimating()
        self.companyNameLabel.text = "-"
        self.companySymbolLabel.text = "-"
        self.priceLabel.text = "-"
        self.priceChangeLabel.text = "-"
        
        // MARK: checking for internet connection
        self.showAlert(message: "No internet connection!")
        
        // MARK: if it is not our first atempt -> use stocks from dictionary
        if companies.count != 0 {
            let selectedRaw = self.companyPickerView.selectedRow(inComponent: 0)
            let selectedSymbol = Array(self.companies.values)[selectedRaw]
            self.requestImage(for: selectedSymbol)
            self.requestQuote(for: selectedSymbol)
            // oterwise use default stock... it's dirty hack, yeah :)
        } else {
            self.requestImage(for: "USO")
            self.requestQuote(for: "USO")
        }
    }
    
    // MARK: update stock info handler
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int){
        self.requestQuoteUpdate()
    }
    
    // MARK: UIPickerViewDelegate protocol. Get element header.
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return Array(self.companies.keys)[row]
    }
    
    // MARK: Display info about stock
    private func displayStockInfo(companyName: String, symbol: String, price: Double, priceChange: Double) {
        self.priceChangeLabel.textColor = UIColor.black
        self.activityIndicator.stopAnimating()
        self.companyNameLabel.text = companyName
        self.companySymbolLabel.text = symbol
        self.priceLabel.text = "\(price) $"
        self.priceChangeLabel.text = "\(priceChange) $"
        
        // MARK: checking for price change and coloring our text...
        if priceChange > 0 {
            self.priceChangeLabel.textColor = UIColor.green
        } else if priceChange < 0 {
            self.priceChangeLabel.textColor = UIColor.red
        }
    }
    
    // MARK: parse results of request
    private func parseQuote(data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard
                let json = jsonObject as? [String: Any],
                let companyName = json["companyName"] as? String,
                let companySymbol = json["symbol"] as? String,
                let price = json["latestPrice"] as? Double,
                let priceChange = json["change"] as? Double
            else {
                self.showAlert(message: "Something went wrong with JSON...")
                return
            }
            // starting another thread for rendering our updated info...
            DispatchQueue.main.async {
                self.displayStockInfo(companyName: companyName,
                                      symbol: companySymbol,
                                      price: price,
                                      priceChange: priceChange)
            }
        } catch {
            print("JSON parsing error: " + error.localizedDescription)
        }
    }
    
    // MARK: requesting for stock info
    private func requestQuote(for symbol: String) {
        let url = URL(string: "https://api.iextrading.com/1.0/stock/\(symbol)/quote")!
        
        let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
            else {
                print("Network error!")
                self.showAlert(message: "No internet connection!")
                return
            }
            self.parseQuote(data: data)
        }
        
        dataTask.resume()
    }
    
    // MARK: parse results of request for stocks list
    private func parseStocks(data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            guard let jsonArray = jsonObject as? [[String: Any]] else {
                    self.showAlert(message: "Something went wrong with JSON...")
                    return
            }
            // starting another thread to update our picker...
             DispatchQueue.main.async {
                for array in jsonArray {  // forming a dictionary with new stocks
                    guard let title = array["symbol"] as? String else { return }
                    guard let name = array["companyName"] as? String else { return }
                    self.companies[name] = title
                }
                // reloading our picker
                self.companyPickerView.reloadAllComponents();
            }
            
        } catch {
            print("JSON parsing error: " + error.localizedDescription)
        }
    }
    
    // MARK: loading our stock image in a separate thread
    private func loadImage(data: Data){
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard
                let json = jsonObject as? [String: Any],
                let stringURL = json["url"] as? String
                else {
                    self.showAlert(message: "Something went wrong with JSON...")
                    return
                }
            
            DispatchQueue.main.async {
                let url = URL(string: stringURL)
                let data = try? Data(contentsOf: url!)
                
                // Setting image
                if let imageData = data {
                    self.companyImage.image = UIImage(data: imageData)
                }
                
            }
        } catch {
            print("JSON parsing error: " + error.localizedDescription)
        }
    }
    
    // MARK: requesting for stock list
    private func requestStocks() {
        let url = URL(string: "https://api.iextrading.com/1.0/stock/market/list/infocus")!
        
        let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
                else {
                    print("Network error!")
                    self.showAlert(message: "No internet connection!")
                    return
            }
            self.parseStocks(data: data)
        }
        
        dataTask.resume()
    }
    
    // MARK: requesting for image
    private func requestImage(for symbol: String) {
        let url = URL(string: "https://api.iextrading.com/1.0/stock/\(symbol)/logo")!
        
        let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
                else {
                    print("Network error!")
                    self.showAlert(message: "No internet connection!")
                    return
            }
            self.loadImage(data: data)
        }
        
        dataTask.resume()
    }
    
    // MARK: checking for internet connection
    func isInternetAvailable() -> Bool
    {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        return (isReachable && !needsConnection)
    }
    
    // MARK: retries update of our stock info
    func retry(alertAction: UIAlertAction) {
        self.requestStocks()
        self.requestQuoteUpdate()
    }
    
    // Showing allert if there is no internet connection
    func showAlert(message: String) {
        if !isInternetAvailable() {
            let alert = UIAlertController(title: "Warning", message: message, preferredStyle: .alert)
            let action = UIAlertAction(title: "Try again", style: .default, handler: retry)
            alert.addAction(action)
            present(alert, animated: true, completion: nil)
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.requestStocks()
        
        self.companyPickerView.dataSource = self    // linking dataSource
        self.companyPickerView.delegate = self      // linking delegate
        
        self.activityIndicator.hidesWhenStopped = true
        
        self.requestQuoteUpdate()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}
