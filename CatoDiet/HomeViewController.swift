//
//  HomeViewController.swift
//  CatoDiet
//
//  Created by Roland Tolnay on 30/11/2019.
//  Copyright © 2019 Roland Tolnay. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController {

  @IBOutlet private weak var foodTextField: UITextField!
  @IBOutlet private weak var amountTextField: UITextField!
  @IBOutlet private weak var feedButton: RoundButton!
  @IBOutlet private weak var tableView: UITableView!

  private lazy var loadingScreen = LoadingScreen(in: view)
  private var user: User?
  private var meals = [Meal]()

  override func viewDidLoad() {
    super.viewDidLoad()

    tableView.dataSource = self
    tableView.delegate = self
    tableView.tableFooterView = UIView()
    FirebaseService.shared.delegate = self
    foodTextField.addTarget(self,
                            action: #selector(updateFeedEnabled),
                            for: .editingChanged)
    amountTextField.addTarget(self,
                              action: #selector(updateFeedEnabled),
                              for: .editingChanged)
    updateFeedEnabled()

    foodTextField.addBottomBorder()
    amountTextField.addBottomBorder()
    hideKeyboardWhenTappedAround()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    loadingScreen.toggle(isLoading: true)
    FirebaseService.shared.authenticate { user in

      guard user != nil else {
        DispatchQueue.main.async {
          self.loadingScreen.toggle(isLoading: false)
          self.showAlert(withMessage: "Unable to fetch your user.")
        }
        return
      }
      self.user = user

      FirebaseService.shared.meals { meals in

        self.meals = meals.sorted { $0.date > $1.date }
        DispatchQueue.main.async {
          self.loadingScreen.toggle(isLoading: false)
          self.tableView.reloadData()
        }
      }
    }
  }

  @IBAction func onFeedTapped(_ sender: Any) {

    let meal = Meal(food: foodTextField.text ?? "",
                    amount: Int(amountTextField.text ?? "") ?? 0,
                    date: Date(),
                    addedBy: user!)
    loadingScreen.toggle(isLoading: true)
    FirebaseService.shared.addMeal(meal) { errorDescription in

      DispatchQueue.main.async {
        self.loadingScreen.toggle(isLoading: false)
        errorDescription.map { self.showAlert(withMessage: $0) }
        if errorDescription == nil {
          self.meals.insert(meal, at: 0)
          self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
        }
      }
    }
  }

  private var isFeedEnabled: Bool {
    user != nil
      && !(foodTextField.text ?? "").isEmpty
      && !(amountTextField.text ?? "").isEmpty
  }

  @objc private func updateFeedEnabled() {
    feedButton.isEnabled = isFeedEnabled
  }
}

extension HomeViewController: UITableViewDataSource {

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

    return meals.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    guard let cell = tableView.dequeueReusableCell(withIdentifier: "MealCell", for: indexPath) as? MealCell else { return UITableViewCell() }

    cell.setup(meal: meals[indexPath.row])
    return cell
  }
}

extension HomeViewController: UITableViewDelegate {

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

    tableView.deselectRow(at: indexPath, animated: true)
    foodTextField.text = meals[indexPath.row].food
    amountTextField.text = "\(meals[indexPath.row].amount)"
    updateFeedEnabled()
  }

  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return meals[indexPath.row].addedBy == user
  }

  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {

    if (editingStyle == .delete) {

      loadingScreen.toggle(isLoading: true)
      let meal = meals[indexPath.row]
      FirebaseService.shared.deleteMeal(meal) { errorDescription in

        DispatchQueue.main.async {
          self.loadingScreen.toggle(isLoading: false)
          errorDescription.map { self.showAlert(withMessage: $0) }
          if errorDescription == nil,
            let index = self.meals.firstIndex(of: meal) {

            self.meals.remove(at: index)
            self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)],
                                      with: .automatic)
          }
        }
      }
    }
  }
}

extension HomeViewController: AuthenticationDelegate {

  func provideUsername(completion: @escaping (String) -> Void) {

    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    if let registrationVC = storyboard.instantiateViewController(withIdentifier: "\(RegisterViewController.self)") as? RegisterViewController {

      registrationVC.onUsernameProvided = { [weak self] username in

        self?.dismiss(animated: true, completion: nil)
        completion(username)
      }
      present(registrationVC, animated: true, completion: nil)
    }
  }
}
