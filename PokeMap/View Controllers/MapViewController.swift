//
//  ViewController.swift
//  PokeMap
//
//  Created by Ivan Bruel on 20/07/16.
//  Copyright © 2016 Faber Ventures. All rights reserved.
//

import UIKit
import MapKit
import RxSwift
import NSObject_Rx
import Permission

class MapViewController: UIViewController {

  @IBOutlet private weak var mapView: MKMapView!

  private let viewModel = PokemonMapViewModel()
  private var centerLocation: Variable<CLLocationCoordinate2D>!
  private var userLocation: Variable<CLLocationCoordinate2D>!

  override func viewDidLoad() {
    super.viewDidLoad()
    centerLocation = Variable(mapView.centerCoordinate)
    userLocation = Variable(mapView.userLocation.coordinate)
    bindViewModel()
    Permission.LocationAlways.request { _ in
    }
  }

  private func bindViewModel() {
    viewModel.viewModels
      .subscribeNext { [weak self] viewModels in
        guard let `self` = self else { return }
        self.setupAnnotations(viewModels)
    }.addDisposableTo(rx_disposeBag)

    centerLocation.asObservable()
      .throttle(1, scheduler: MainScheduler.instance)
      .subscribeNext { [weak self] location in
        guard let `self` = self else { return }
        self.loadPokemons(location)
    }.addDisposableTo(rx_disposeBag)

    userLocation.asObservable()
      .throttle(1, scheduler: MainScheduler.instance)
      .subscribeNext { [weak self] location in
        guard let `self` = self else { return }
        self.loadPokemons(location)
      }.addDisposableTo(rx_disposeBag)
  }

  func loadPokemons(location: CLLocationCoordinate2D) {
    viewModel.loadPokemons(location.latitude, longitude: location.longitude)
      .subscribe()
      .addDisposableTo(rx_disposeBag)
  }

  private func setupAnnotations(viewModels: [PokemonMapItemViewModel]) {
    let annotations = mapView.annotations.flatMap { $0 as? PokemonAnnotation }
    let expiredAnnotations = annotations.filter { $0.expired }
    mapView.removeAnnotations(expiredAnnotations)
    let validAnnotations = mapView.annotations.flatMap { $0 as? PokemonAnnotation }
    let pokemonIds = validAnnotations.map { $0.identifier }
    let newViewModels = viewModels.filter { !pokemonIds.contains($0.identifier) }
    mapView.addAnnotations(newViewModels.map { $0.annotation })
  }
}

extension MapViewController: MKMapViewDelegate {
  func mapView(mapView: MKMapView, didUpdateUserLocation userLocation: MKUserLocation) {
   self.userLocation.value = userLocation.coordinate
  }

  func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation)
    -> MKAnnotationView? {
    guard let pokemonAnnotation = annotation as? PokemonAnnotation else {
      return nil
    }
    return pokemonAnnotation.annotationView
  }

  func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    centerLocation.value = mapView.centerCoordinate
  }
}
