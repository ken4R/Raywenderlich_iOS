/*
 * Copyright (c) 2014-2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import RxSwift
import RxCocoa
import MapKit
import CoreLocation

fileprivate let maxAttempts = 4 //오류 발생 시 재 시도할 최대 횟수

typealias Weather = ApiController.Weather

class ViewController: UIViewController {
    
    @IBOutlet weak var keyButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var mapButton: UIButton!
    @IBOutlet weak var geoLocationButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var searchCityName: UITextField!
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var iconLabel: UILabel!
    @IBOutlet weak var cityNameLabel: UILabel!
    
    let bag = DisposeBag()
    let locationManager = CLLocationManager()
    
    var keyTextField: UITextField?
    var cache = [String: Weather]() //Weather데이터 캐시. //오류 발생 시 캐시된 데이터를 활용할 수 있다.

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    
    style()
    
    //각 observable의 선언 위치가 중요
    
    let searchInput = searchCityName.rx.controlEvent(.editingDidEndOnExit).asObservable()
        //end(검색) 버튼 눌렀을 경우 //controlEvent를 Onservable로 변환
        .map { self.searchCityName.text } //입력된 문자열 가져오기
        .filter { ($0 ?? "").count > 0 } //텍스트가 비어 있지 않아야 한다.
    
    let retryHandler: (Observable<Error>) -> Observable<Int> = { e in
        //retryWhen에 있던 코드와 인증 에러 통합
        return e.enumerated() //enumerated로 index와 Observable의 값을 가져올 수 있다.
            .flatMap { (attempt, error) -> Observable<Int> in //이 앱에선 오류가 도착했을 때, index도 수신되어야 한다(시간 차이).
                if attempt >= maxAttempts - 1 { //maxAttempts 수 만큼 반복 했는데도 오류가 나면
                    return Observable.error(error) //오류
                } else if let casted = error as? ApiController.ApiError, casted == .invalidKey { //인증 오류
                    //날씨 정보 요청 위한 인증 기능(로그인)을 추가한다고 하면, 로그인 여부를 확인할 세션이 생성되고,
                    //그 세션으로 인증을 처리하게 된다. 세션이 만료된 경우에는 에러나 빈 값을 반환할 수 있다.
                    //이 경우에 대한 완벽한 해결책은 없지만, 유용한 해결책이 있다.
                    return ApiController.shared.apiKey
                        .filter { $0 != "" }
                        .map { _ in return 1 }
                }
                
                print("== retrying after \(attempt + 1) seconds ==")
                
                return Observable<Int>.timer(Double(attempt + 1), scheduler: MainScheduler.instance)
                //스케줄러(MainScheduler.instance)를 사용하여,
                //지정된 지연 시간(attempt + 1)이 경과한 후
                //주기적으로 값을 생성한다. p.294
                    .take(1)
            }
    }
    
    let textSearch = searchInput
        .flatMap { text in
            //searchCityName.rx의 입력된 text로 currentWeather를 호출해 데이터를 가져온다.
            return ApiController.shared.currentWeather(city: text ?? "Error")
                //입력된 text로 currentWeather를 호출해 데이터를 가져온다.
                .do(onNext: { data in
                    //do 연산자는 Onservable의 각 이벤트에 대한 작업을 호출하고, 메시지를 결과 시퀀스로 전파한다.
                    //Observable에 영향을 주지 않고 별도의 작업을 수행할 수 있도록해 주는 연산자. (side effect)
                    //어떤 작업을 추가하더라도 emit하는 이벤트는 변화시키지 않는다.
                    //이벤트를 다음 연산자로 통과시키지만, do(onNext: )등으로 해당 이벤트 시 핸들러를 추가해 줄 수도 있다.
                    //ex. never 연산자를 사용 하는 경우 구독을 해도, onNext나 onCompleted의 핸들러가 작동되지 않는다.
                    //하지만, do(onNext: )연산자를 사용하면, 구독을 해 onNext 이벤트가 발생하면
                    //do(onNext: )의 핸들러의 내용을 실행한다. never 연산자를 사용한 Observable에는 영향을 끼치지 않으므로
                    //원본 시퀀스는 그대로 아무 이벤트를 발생 시키지 않고 종료된다.
                    if let text = text {
                        self.cache[text] = data //캐싱 //do(onNext: )를 체인에 추가해 캐시에 데이터를 추가한다.
                    }
                }, onError: { [weak self] e in //오류 이벤트 시
                    //보통 오류는 retry나 catch로 처리된다. 하지만 side effect를 발생시키거나 UI 변경(메시지) 등의 작업을 한다면 do 연산자 사용.
                    //마찬가지로 retryWhen를 사용할 때도 do를 사용할 수 있다.
                    guard let strongSelf = self else { return }
                    
                    DispatchQueue.main.async { //시퀀스가 백그라운드에서 진행되므로 필요하다.
                        strongSelf.showError(error: e) //오류 메시지 출력
                    }
                })
//                .retry() //오류 발생 시, 다시 성공할 때까지 무제한 반복한다.
//                .retry(3) //오류 발생 시, 3번 까지 반복한다.
//                .retryWhen { e in //특정 조건을 만들어 반복한다.
//                    //여기서는 오류가 발생하면 각각 다른 일정시간(1초, 2초, 3초...) 후에 시도해, 총 4번 재시도를 한다.
//                    //따라서 오류가 도착했을 때, index도 수신되어야 한다(그래야 시간 차이를 줄 수 있으므로).
//                    e.enumerated() //enumerated로 index와 Observable의 값을 가져올 수 있다.
//                        .flatMap { (attempt, error) -> Observable<Int> in
//                            if attempt >= maxAttempts - 1 { //maxAttempts 수 만큼 반복 했는데도 오류가 나면
//                                return Observable.error(error) //최종적으로 오류 반환
//                            }
//
//                            print("== retrying after \(attempt + 1) seconds ==")
//
//                            return Observable<Int>.timer(Double(attempt + 1), scheduler: MainScheduler.instance)
//                            //스케줄러(MainScheduler.instance)를 사용하여,
//                            //지정된 지연 시간(attempt + 1)이 경과한 후
//                            //주기적으로 값을 생성한다. p.294
//                                .take(1)
//                        }
//                }
                
                .retryWhen(retryHandler) //특정 조건을 만들어 반복한다.
                //여기서는 오류가 발생하면 각각 다른 일정시간(1초, 2초, 3초...) 후에 시도해, 총 4번 재시도를 한다.
                //인증 오류 시에는 바로 인증 오류를 반환한다.
                
                //일반 Swift 코드로 이 구현하려 했다면, GCD를 사용하여 래퍼를 만들고 추상화 하는 등 매우 복잡하다.
                //내부의 Observable이 어떤 값을 반환해야 하고, 트리거가 어떤 유형이 될 지 미리 고려해야 한다.
                
                .catchError { error in
                    //오류 발생 시 3번 재시도 하고, 그래도 오류가 발생한 경우 catchError에서 처리한다.
                    //catchErrorJustReturn를 catchError로 대체 한다.
                    if let text = text, let cachedData = self.cache[text] { //캐싱된 데이터가 있다면
                        return Observable.just(cachedData) //캐시해둔 데이터를 표시
                    } else { //캐싱된 데이터가 없다면
                        return Observable.just(ApiController.Weather.empty) //더미 데이터 반환
                    }
                }
            
                //RxSwift에서 오류 처리는 Catch, Retry 두 가지 방법이 있다. p.286
                //• Catch : defaultValue로 error 복구
                //  Catch는 Swift의 do-try-catch와 유사하며 RxSwift의 Catch에는 두 가지의 주요 연산자가 있다.
                //  1. func catchError(_ handler:) -> RxSwift.Observable<Self.E> p.287
                //  이 연산자는 클로저를 파라미터로 해서, Observable을 반환한다.
                //  이전의 오류 없던 더 이상 사용할 수 없는 값을 반환.
                //  2. func catchErrorJustReturn(_ element:) -> RxSwift.Observable<Self.E> p.289
                //  이 연산자는 오류를 무시하고 미리 정의해 둔 default 값을 반환한다.
                //  오류가 무엇이든 동일한 값이 반환하므로 이전 연산자보다 제한적이다.
                //• Retry : 제한적으로(혹은 무제한적으로) 반복 시도 하기. p.290
                //  Retry에는 3가지 유형의 연산자가 있다.
                //  1. func retry() -> RxSwift.Observable<Self.E>
                //  이 연산자는 반환이 성공할 때까지 무제한 반복 시도한다. 리소스 소모가 심하므로 횟수에 제한을 두는 것이 좋다.
                //  2. func retry(_ maxAttemptCount:) -> Observable<E>
                //  이 연산자는 지정된 횟수만큼 반복 시도한다.
                //  3. func retryWhen(_ notificationHandler:) -> Observable<E>
                //  notificationHandler는 Observable이거나 Subject이 될 수 있므며, 임의의 시간에 재시도 하는 트리거이다.
                //  이 연산자는 특정 조건을 만들어 반복 시도한다.
                //지금까지는 catchErrorJustReturn으로 간단히 처리했었다. 하지만 앱이 더 복잡해지면 에러 관리가 꼭 필요.
                //Catch와 Retry를 혼합해 오류 처리를 해 줄 수도 있다.
            
                //오류도 Observable chain에서 전파되므로 따로 처리해 주지 않으면,
                //시작 부분에서 오류가 발생해도 그것이 최종 구독으로 전달된다.
                //Observable이 오류를 발생 시키면, Observable이 종료되고, 다음 이벤트는 모두 무시된다. p.288
            
//                .catchErrorJustReturn(ApiController.Weather.dummy)
//                //catchErrorJustReturn : 에러가 발생 했을 때 설정해둔 단일 이벤트를 전달한다.
//                //subscribe에서 에러를 감지하는 것이 아닌, Observable에서 에러에 대한 기본 이벤트를 설정하는 연산자.
//                //오류가 발생하면, Observable이 종료 된다. 하지만, 그러면 앱이 더 이상 진행이 안 되기 때문에,
//                //오류가 나더라도 빈 Observable을 반환해 앱이 계속 작동하도록 한다.
        }
    
    let mapInput = mapView.rx.regionDidChangeAnimated //지도에서 이벤트 발생한 경우
        .skip(1) //한 번은 스킵. 앱이 시작된 직후에 검색되지 않도록.
        .map { _ in self.mapView.centerCoordinate } //중심 좌표로 가져온다.
    
    let mapSearch = mapInput.flatMap { coordinate in
        return ApiController.shared.currentWeather(lat: coordinate.latitude, lon: coordinate.longitude) //현재 좌표로 날씨 검색
            .catchErrorJustReturn(ApiController.Weather.dummy)
            //오류 시 더미
    }
    
    let currentLocation = locationManager.rx.didUpdateLocations
        .map { locations in //배열을 반환하지만, 작업할 위치는 가장 처음에 있다.
            return locations[0] //첫 번째 위치만 얻는다.
        }
        .filter { location in //map으로 첫 번째 위치만 얻은 후 필터링
            return location.horizontalAccuracy < kCLLocationAccuracyHundredMeters
            //정확도로 100미터 이내 있을 때만 유효
            //horizontalAccuracy은 해당 위도, 경도 중심의 반지름. 음수라면 위도와 경도가 유효하지 않다.
    }
    
    let geoInput = geoLocationButton.rx.tap.asObservable() //geoLocationButton 탭했을 경우
        //버튼을 클릭하면, 유저의 위치로 API를 호출하고 바인딩해 업데이트 한다. p.270
        //사용자의 위치를 반환하는 Observable이 필요하므로 asObservable()
        .do(onNext: {
            //do 연산자는 Onservable의 각 이벤트에 대한 작업을 호출하고, 메시지를 결과 시퀀스로 전파한다.
            //Observable에 영향을 주지 않고 별도의 작업을 수행할 수 있도록해 주는 연산자.
            //어떤 작업을 추가하더라도 emit하는 이벤트는 변화시키지 않는다.
            //이벤트를 다음 연산자로 통과시키지만, do(onNext: )등으로 해당 이벤트 시 핸들러를 추가해 줄 수도 있다.
            self.locationManager.requestWhenInUseAuthorization() //권한요청
            self.locationManager.startUpdatingLocation() //위치 업데이트
            //do(onNext: )를 체인에 추가해 권한을 받고 위치를 업데이트 한다.
        })
    
    let geoLocation = geoInput.flatMap {
        return currentLocation.take(1) //하나만 가져온다.
        //새 값이 locationManager로부터 도착할 때마다 업데이트 되는 것을 막는다.
    }
    
    let geoSearch = geoLocation.flatMap { location in //받아온 geo 값으로 날씨 검색
        //geoSearch를 Weather 유형으로 관측할 수 있다(입력한 도시 명).
        return ApiController.shared.currentWeather(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            .catchErrorJustReturn(ApiController.Weather.dummy)
            //catchErrorJustReturn : 에러가 발생 했을 때 설정해둔 단일 이벤트를 전달한다.
    }
    
    let search = Observable.from([geoSearch, textSearch, mapSearch])
        //이전에는 텍스트 검색만 있었으므로 textSearch의 내용이 유일한 검색이었다.
        //하지만, 위치 검색, 지도 검색의 로직도 동일하기 때문에, observable을 합칠 수 있다.
        .merge() //observable 병합
        .asDriver(onErrorJustReturn: ApiController.Weather.empty) //Driver trait로 전환
        //onErrorJustReturn로 오류 발생 시 사용할 기본 값 지정.
        //• asDriver (onErrorDriveWith :) : 오류를 수동으로 처리한다.
        //• asDriver (onErrorRecover :) : 오류 복구를 위드 메서드
    
    let running = Observable.from([
            searchInput.map { _ in return true }, //키보드로 친 내용으로 실행
            //키보드로 입력한 내용를 map으로 합친다(text string이 온다).
            geoInput.map { _ in return true }, //위치 검색 버튼으로 실행
            mapInput.map { _ in return true }, //지도 위치로 검색 실행
            search.map { _ in return false }.asObservable() //검색을 수행하는 시퀀스
            //검색 수행의 결과를 map으로 합친다(Weather 데이터가 온다).
            //indicator를 숨겨야 하므로 search에선 false를 반환 (밑에 drive()로 연결된 부분이 레이블의 isHidden)
            //위의 searchInput, geoInput, mapInput에서는 검색 중이므로 indicator를 숨겨야 되기 때문에 true
            //asObservable로 시퀀스를 만든다. //모델 로직은 p.271
        
            //키보드 검색이든, 위치 검색이든, 지도 검색이든 관계없이 같은 로직을 통해 UI에 Weather객체를 전달할 수 있다.
        ])
        .merge()
        .startWith(true) //startWith()를 true로 하면, 시퀀스의 앞에 일련의 값을 붙여 줄 수 있다.
        //이를 통해, 프로그램 시작 시 모든 레이블을 수동으로 숨기지 않아도 된다.
        .asDriver(onErrorJustReturn: false)
    
    //앱이 검색을 실행하는 동안 Activity indicator를 표시하는 것이 좋다. p.261
    //시퀀스를 두 개로 분리한다. searchInput으로 키보드로 친 검색 내용을 검사하고, search로 API와 통신한다.
    //running에서는 from으로 Array를 Observable로 변경한다.
    //UIActivityIndicatorView의 isAnimating에 Observable을 바인딩하고, isHidden로 제어해 주면 되지만,
    //Rx에서는 더 쉽게 구현할 수 있다. searchInput, search는 이벤트 수신 여부에 따라 T/F를 반환하도록 한다.
    //이를 통해 최종 결과는 현재 서버에서 데이터 요청 중인지 아닌지 여부를 담고 있는 Observable이 된다.
    //즉, 이벤트 시퀀스를 작은 시퀀스로 분리해 사용자가 버튼을 누를 때 알림을 받고, 서버에서 데이터가 도착했는지 확인한다.
    
    //UI요소 바인딩 //running이라면, 아래와 같은 상황이 된다.
    //running 상태가 아니라면 자동으로 반대 상태가 되는 듯??
    running
        .skip(1) //첫 번째 값은 건너 뛴다(수동으로 입력해 줄 것이다).
        //건너 뛰지 않으면 앱이 시작됐을 때 indicator가 돌아간다.
        .drive(activityIndicator.rx.isAnimating) //indicator 애니메이션
        .disposed(by: bag)
    
    running
        .drive(tempLabel.rx.isHidden) //레이블을 숨긴다
        .disposed(by: bag)
    
    running
        .drive(iconLabel.rx.isHidden) //레이블을 숨긴다
        .disposed(by: bag)
    
    running
        .drive(humidityLabel.rx.isHidden) //레이블을 숨긴다
        .disposed(by: bag)
    
    running
        .drive(cityNameLabel.rx.isHidden) //레이블을 숨긴다
        .disposed(by: bag)
    
    locationManager.rx.didUpdateLocations //Observable로 설정한 delegate
        .subscribe(onNext: { locations in //delegate로 설정한 이벤트가 일어나면 실행된다.
            print(locations)
        })
        .disposed(by: bag)
    
    //geoInput으로 대체됨
//    geoLocationButton.rx.tap
//        .subscribe(onNext: { _ in
//            self.locationManager.requestWhenInUseAuthorization()
//            self.locationManager.startUpdatingLocation()
//        })
//        .disposed(by: bag)
    
    mapButton.rx.tap
        .subscribe(onNext: { //구독 //버튼이 탭 됐을 때
            self.mapView.isHidden = !self.mapView.isHidden
            //맵 뷰 보이거나 숨김
        })
        .disposed(by: bag)
    
    mapView.rx.setDelegate(self) //RxProxy에서 호출되지 않은 기본 delegate를 받을 대리자 설정
        .disposed(by: bag)
    
    keyButton.rx.tap
        .subscribe(onNext: {
            self.requestKey()
        })
        .disposed(by:bag)
    
    search.map { [$0.overlay()] } //Weather를 오버레이로 변환.
        .drive(mapView.rx.overlays)
        .disposed(by: bag)
    
    search.map { "\($0.temperature)° C" }
      .drive(tempLabel.rx.text) //bind를 drive로 바꿔 준다. 메인 스레드에서만 호출할 수 있다.
        //드라이버의 기능을 활용하면서 올바른 UI 업데이트가 보장된다. bind(to: )와 매우 비슷하다.
      .disposed(by:bag)

    search.map { $0.icon }
      .drive(iconLabel.rx.text)
      .disposed(by:bag)

    search.map { "\($0.humidity)%" }
      .drive(humidityLabel.rx.text)
      .disposed(by:bag)

    search.map { $0.cityName }
      .drive(cityNameLabel.rx.text)
      .disposed(by:bag)

    
    
    
    
    
    
    
    
    
    //************************************ ch.12 ************************************
    
    //더미 //테스트용
//    ApiController.shared.currentWeather(city: "RxSwift")
//        .observeOn(MainScheduler.instance)
//        //observeOn : 지정된 스케줄러에서 옵저버 콜백을 실행하기 위해 소스 시퀀스를 래핑
//        //특정 작업의 스케줄러를 변경할 수 있다.
//        .subscribe(onNext: { data in
//            self.tempLabel.text = "\(data.temperature)° C"
//            self.iconLabel.text = data.icon
//            self.humidityLabel.text = "\(data.humidity)%"
//            self.cityNameLabel.text = data.cityName
//        })
//        .disposed(by: bag) //추가해 줘야 한다.
//        //구독은 필요할 때 취소하는 일회용 개체를 반환환다. 이것을 컨트롤러가 닫힐 때 취소해 줘야 한다.
//        //.disposed(by: )를 추가해 주면, 컨트롤러가 해제될 때마다 구독이 취소되고 처리가 된다.
//        //리소스의낭비를 막을 수 있을 뿐만 아니라 예기치 않은 에러 등에도 대응할 수 있다.
    
    
    
    
    //Basic
//    searchCityName.rx.text //ControlProperty는 ObservableType과 ObserverType을 모두 준수한다.
//        //따라서 객체를 구독하고 새 값을 emit 할 수 있다.
//        .filter { ($0 ?? "").characters.count > 0 }
//        //currentWeather는 파라미터로 nil이나 빈 값을 허용하지 않는다. 필터링
//        .flatMap { text in
//            //searchCityName.rx의 입력된 text로 currentWeather를 호출해 데이터를 가져온다.
//            return ApiController.shared.currentWeather(city: text ?? "Error")
//                .catchErrorJustReturn(ApiController.Weather.empty)
//            //catchErrorJustReturn : 에러가 발생 했을 때 설정해둔 단일 이벤트를 전달한다.
//            //subscribe에서 에러를 감지하는 것이 아닌, Observable에서 에러에 대한 기본 이벤트를 설정하는 연산자.
//            //오류가 발생하면, Observable이 종료 된다. 하지만, 그러면 앱이 더 이상 진행이 안 되기 때문에,
//            //오류가 나더라도 빈 Observable을 반환해 앱이 계속 작동하도록 한다.
//            //catchErrorJustReturn를 주석 처리하면, 처음 한 글자를 치자 마자
//            //404 에러가 나면서 종료된서 서버와 더 이상 통신하지 않는다.
//        }
//        .observeOn(MainScheduler.instance)
//        //지정된 스케줄러에서 옵저버 콜백을 실행하기 위한 소스 시퀀스를 래핑한다.
//        //동작하는 스케줄러를 MainScheduler로 전환해 준다. //UI 업데이트 위한 메인 스레드와 MainScheduler로 전환
//        .subscribe(onNext: { data in //필터링과 flatMap에서 에러가 안 난 경우에만 observeOn를 거쳐 구독된다.
//            self.tempLabel.text = "\(data.temperature)° C"
//            self.iconLabel.text = data.icon
//            self.humidityLabel.text = "\(data.humidity)%"
//            self.cityNameLabel.text = data.cityName
//        })
//        .disposed(by:bag)
//    //구독은 필요할 때 취소하는 일회용 개체를 반환환다. 이것을 컨트롤러가 닫힐 때 취소해 줘야 한다.
//    //.disposed(by: )를 추가해 주면, 컨트롤러가 해제될 때마다 구독이 취소되고 처리가 된다.
//    //리소스의낭비를 막을 수 있을 뿐만 아니라 예기치 않은 에러 등에도 대응할 수 있다.
    
    
    
    
    //Binding
//    let search = searchCityName.rx.text
//        //ControlProperty는 ObservableType과 ObserverType을 모두 준수한다.
//        //따라서 객체를 구독하고 새 값을 emit 할 수 있다.
//        .filter { ($0 ?? "").characters.count > 0 }
//        //currentWeather는 파라미터로 nil이나 빈 값을 허용하지 않는다. 필터링
//        .flatMapLatest { text in
//            //searchCityName.rx의 입력된 text로 currentWeather를 호출해 데이터를 가져온다.
//            //flatMapLatest은 flatMap의 최신 요소를 emit 한다.
//            //flatMapLatest는 결과를 재사용 가능하게 만들고 일회용 데이터 소스를 다중 사용 가능한 Observable로 변환
//            //Observable은 Rx의 재사용 가능한 엔티티가 될 수 있다.
//            return ApiController.shared.currentWeather(city: text ?? "Error")
//                .catchErrorJustReturn(ApiController.Weather.empty)
//            //catchErrorJustReturn : 에러가 발생 했을 때 설정해둔 단일 이벤트를 전달한다.
//            //subscribe에서 에러를 감지하는 것이 아닌, Observable에서 에러에 대한 기본 이벤트를 설정하는 연산자.
//            //오류가 발생하면, Observable이 종료 된다. 하지만, 그러면 앱이 더 이상 진행이 안 되기 때문에,
//            //오류가 나더라도 빈 Observable을 반환해 앱이 계속 작동하도록 한다.
//            //catchErrorJustReturn를 주석 처리하면, 처음 한 글자를 치자 마자
//            //404 에러가 나면서 종료된서 서버와 더 이상 통신하지 않는다.
//        }
//        .shareReplay(1)
//        //기본 시퀀스에 대해 단일 구독을 공유하는 Observable을 반환하고 구독 즉시 버퍼의 최대 요소 수까지 재생
//        .observeOn(MainScheduler.instance)
//        //지정된 스케줄러에서 옵저버 콜백을 실행하기 위한 소스 시퀀스를 래핑한다.
//        //동작하는 스케줄러를 MainScheduler로 전환해 준다. //UI 업데이트 위한 메인 스레드와 MainScheduler로 전환
//
//    //위의 결과로 search에는 문자열을 반환하는 observable이 생성 된다. 각각의 필요한 정보를 바인딩 한다.
//    search.map { "\($0.temperature)° C" }
//          .bind(to:tempLabel.rx.text) //바인딩
//        //RxCocoa의 바인딩은 단방향 데이터 스트림이다. 앱의 데이터 흐름을 크데 단순화 시킬 수 있다.
//        //단방향 바인딩에서 Receiver는 값을 반환할 수 있다. 양방향에서는 가능하지만 코드가 매우 복잡해진다.
//        //기본적으로 bind(to: )로 바인딩 할 수 있으며, Receiver가 ObserverType이어야 한다.
//        //Subject는 UILabel, UITexField, UIImageView 등의 요소의
//        //변경 가능한 데이터를 get, set할 수 있어 매우 중요하다.
//        //바인딩은 그 목적 외에도 백그라운드 작업 트리거로 사용할 수 있다.
//        //요약하자만 bind 연산자는 subscribe()의 특별한 버전이다.
//          .disposed(by:bag)
//        //구독은 필요할 때 취소하는 일회용 개체를 반환환다. 이것을 컨트롤러가 닫힐 때 취소해 줘야 한다.
//        //.disposed(by: )를 추가해 주면, 컨트롤러가 해제될 때마다 구독이 취소되고 처리가 된다.
//        //리소스의낭비를 막을 수 있을 뿐만 아니라 예기치 않은 에러 등에도 대응할 수 있다.
//
//    //이전에는 전체 UI를 업데이트 하는 하나의 Observable을 가져왔지만, 바인딩 된 블록 별로 업데이트 한다.
//    //코드 재사용이 쉬워지고, 가독성이 좋아진다.
//    search.map { $0.icon }
//      .bind(to:iconLabel.rx.text)
//      .disposed(by:bag)
//
//    search.map { "\($0.humidity)%" }
//      .bind(to:humidityLabel.rx.text)
//      .disposed(by:bag)
//
//    search.map { $0.cityName }
//      .bind(to:cityNameLabel.rx.text)
//      .disposed(by:bag)
    
    
    
    
    //Traits
//    //RxCocoa를 이용하여, bind 외에도 UI와 함께 사용되는 특수한 Observables(Traits)을 구현해 줄 수 있다.
//    //Trait는 다음과 같은 특성이 있다.
//    //• Trait는 오류를 일으킬 수 없다.
//    //• 메인 스케줄러(main scheduler)에서 observed 된다.
//    //• 메인 스케줄러(main scheduler)를 subscribe 한다.
//    //• side effects를 공유한다.
//    //따라서 사용자 인터페이스에서 항상 표시되는 항목과 사용자 인터페이스에서 항상 처리할 수 있는 항목을 보장한다.
//    //Trait는 ControlProperty, ControlEvent, Driver로 구성된다.
//    //• ControlProperty는 ObservableType과 ObserverType을 모두 준수한다. rx를 extention해
//    //  인터페이스 구성 요소에 데이터를 바인딩하기 위해 사용한다.
//    //• ControlEvent는 UI 구성 요소의 특정 이벤트를 수신하는 데 사용된다. (ex. 키보드의 Return 키 입력)
//    //• Driver는 특별한 observable로, 오류가 발생하지 않는다. 모든 프로세스가 메인 스레드에서 실행되어
//    //  백 그라운드 스레드에서 UI를 변경하는 것을 피할 수 있다.
//    //Traits은 선택적인 부분으로 사용하지 않아도 무방하다. UI업데이트에 규칙을 추가하는 데 유용하게 사용할 수 있다.
//    let search = searchCityName.rx.text
//        //ControlProperty는 ObservableType과 ObserverType을 모두 준수한다.
//        //따라서 객체를 구독하고 새 값을 emit 할 수 있다.
//        .filter { ($0 ?? "").characters.count > 0 }
//        //currentWeather는 파라미터로 nil이나 빈 값을 허용하지 않는다. 필터링
//        .flatMapLatest { text in
//            //searchCityName.rx의 입력된 text로 currentWeather를 호출해 데이터를 가져온다.
//            //flatMapLatest은 flatMap의 최신 요소를 emit 한다.
//            //flatMapLatest는 결과를 재사용 가능하게 만들고 일회용 데이터 소스를 다중 사용 가능한 Observable로 변환
//            //Observable은 Rx의 재사용 가능한 엔티티가 될 수 있다.
//            return ApiController.shared.currentWeather(city: text ?? "Error")
//                .catchErrorJustReturn(ApiController.Weather.empty)
//            //catchErrorJustReturn : 에러가 발생 했을 때 설정해둔 단일 이벤트를 전달한다.
//            //subscribe에서 에러를 감지하는 것이 아닌, Observable에서 에러에 대한 기본 이벤트를 설정하는 연산자.
//            //오류가 발생하면, Observable이 종료 된다. 하지만, 그러면 앱이 더 이상 진행이 안 되기 때문에,
//            //오류가 나더라도 빈 Observable을 반환해 앱이 계속 작동하도록 한다.
//            //catchErrorJustReturn를 주석 처리하면, 처음 한 글자를 치자 마자
//            //404 에러가 나면서 종료된서 서버와 더 이상 통신하지 않는다.
//        }
//        .asDriver(onErrorJustReturn: ApiController.Weather.empty) //Driver trait로 전환
//        //onErrorJustReturn로 오류 발생 시 사용할 기본 값 지정.
//        //• asDriver (onErrorDriveWith :) : 오류를 수동으로 처리한다.
//        //• asDriver (onErrorRecover :) : 오류 복구를 위드 메서드
//
//    search.map { "\($0.temperature)° C" }
//      .drive(tempLabel.rx.text) //bind를 drive로 바꿔 준다. 메인 스레드에서만 호출할 수 있다.
//        //드라이버의 기능을 활용하면서 올바른 UI 업데이트가 보장된다. bind(to: )와 매우 비슷하다.
//      .disposed(by:bag)
//
//    search.map { $0.icon }
//      .drive(iconLabel.rx.text)
//      .disposed(by:bag)
//
//    search.map { "\($0.humidity)%" }
//      .drive(humidityLabel.rx.text)
//      .disposed(by:bag)
//
//    search.map { $0.cityName }
//      .drive(cityNameLabel.rx.text)
//      .disposed(by:bag)

    
    
    
    //Ch.12 Final
//    let search = searchCityName.rx.controlEvent(.editingDidEndOnExit)
//        //이전 버전들은 너무 많은 리소스를 사용하고, 문자를 입력할 때마다 request를 발생시켜 API를 요청하므로
//        //이벤트가 있을 때에만 실행 시켜 주는 것이 좋다.
//        //코드는 Trait에 의해 컴파일 타임에 제어된다.
//        .asObservable() //Observable 전환
//        .map { self.searchCityName.text } //텍스트로 변환
//        .flatMap { text in
//            //searchCityName.rx의 입력된 text로 currentWeather를 호출해 데이터를 가져온다.
//            //flatMapLatest은 flatMap의 최신 요소를 emit 한다.
//            //flatMapLatest는 결과를 재사용 가능하게 만들고 일회용 데이터 소스를 다중 사용 가능한 Observable로 변환
//            //Observable은 Rx의 재사용 가능한 엔티티가 될 수 있다.
//            return ApiController.shared.currentWeather(city: text ?? "Error")
//            //버튼을 누를 때만 검색하므로 .catchErrorJustReturn(ApiController.Weather.empty)를
//            //제거해 주고, 구독(여기서는 asDriver)에서 관리해 주면 된다.
//        }
//        .asDriver(onErrorJustReturn: ApiController.Weather.empty) //Driver trait로 전환
//        //onErrorJustReturn로 오류 발생 시 사용할 기본 값 지정.
//        //• asDriver (onErrorDriveWith :) : 오류를 수동으로 처리한다.
//        //• asDriver (onErrorRecover :) : 오류 복구를 위드 메서드
//
//    search.map { "\($0.temperature)° C" }
//        .drive(tempLabel.rx.text) //bind를 drive로 바꿔 준다. 메인 스레드에서만 호출할 수 있다.
//        //드라이버의 기능을 활용하면서 올바른 UI 업데이트가 보장된다. bind(to: )와 매우 비슷하다.
//        .disposed(by:bag)
//
//    search.map { $0.icon }
//        .drive(iconLabel.rx.text)
//        .disposed(by:bag)
//
//    search.map { "\($0.humidity)%" }
//        .drive(humidityLabel.rx.text)
//        .disposed(by:bag)
//
//    search.map { $0.cityName }
//        .drive(cityNameLabel.rx.text)
//        .disposed(by:bag)
//
  }

 override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    Appearance.applyBottomLine(to: searchCityName)
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: - Style

  private func style() {
    view.backgroundColor = UIColor.aztec
    searchCityName.textColor = UIColor.ufoGreen
    tempLabel.textColor = UIColor.cream
    humidityLabel.textColor = UIColor.cream
    iconLabel.textColor = UIColor.cream
    cityNameLabel.textColor = UIColor.cream
  }
    
    func requestKey() {
        func configurationTextField(textField: UITextField!) {
            self.keyTextField = textField
        }
        
        let alert = UIAlertController(title: "Api Key",
                                      message: "Add the api key:",
                                      preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addTextField(configurationHandler: configurationTextField)
        
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler:{ (UIAlertAction) in
            ApiController.shared.apiKey.onNext(self.keyTextField?.text ?? "")
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.destructive))
        
        self.present(alert, animated: true)
    }
    
    func showError(error e: Error) { //오류 별로 다른 메시지 출력
        if let e = e as? ApiController.ApiError {
            switch e {
            case .cityNotFound:
                InfoView.showIn(viewController: self, message: "City Name is invalid")
            case .serverFailure:
                InfoView.showIn(viewController: self, message: "Server error")
            case .invalidKey:
                InfoView.showIn(viewController: self, message: "Key is invalid")
            }
        } else {
            InfoView.showIn(viewController: self, message: "An error occurred")
        }
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        //오버레이 렌더링
        //Rx 타입을 반환하는 delegate를 래핑하는 것은 어려운 작업이다.
        //• 반환타입이 관찰이 아닌 사용자 정의를 위한 것이기 때문에
        //• 자동 기본 값을 설정하는 것이 사소한 일이 아니다.
        //Subject로 값을 관찰할 수 있지만, 이 경우에는 값이 거의 줄 수 없다.
        //이런 경우에는 기존의 delegate에서 구현하는 것이 좋은 방법일 수 있다. p.275
        //이렇게 구현하면 UIKit에서 처럼 반환 값으로 delegate 메서드를 준수하면서, observable을 사용할 수도 있다.
        //일부분은 CLLocationManaer+Rx처럼 래핑해 구현하고, 일부분은 기존 delegate를 사용
        if let overlay = overlay as? ApiController.Weather.Overlay {
            //MapView 위의 오버레이 //정보를 가져올 수 있다면 오버레이 뷰를 생성한다.
            let overlayView = ApiController.Weather.OverlayView(overlay:
                overlay, overlayIcon: overlay.icon)
            return overlayView
        }
        
        return MKOverlayRenderer() //기본 렌더러
    }
}

//ApiController에서 ViewController로 Data를 보내는 구조 (단일 방향 데이터 흐름)

//ViewController가 해제될 때, 구독을 처리하는 DisposeBag.
//코드를 보면 각 클로저 내부에 weak이나 unowned를 쓰지 않았다. 이 앱은 ViewController가 하나이므로 생명주기가 같다.
//하지만, 다중의 ViewController를 사용하는 앱이라면, weak 또는 unowned로 강한 참조를 막아야 한다.
//Rx에서 이를 사용하는 지침은
//• nothing : 싱글톤이거나 절대로 메모리 해제 되지 않는 뷰 컨트롤러 내부에서 사용(ex. rootViewController)
//• unowned : 클로저 작업 수행 후, 메모리가 해제되는 뷰 컨트롤러 내부에서 사용
//• weak : 이 외의 모든 경우
//EXC_BAD_ACCESS 오류를 방지한다.

//p.258

//RxSwift 4.0에서는 새로운 Signal이라는 trait이 생겼다.
//• It can't fail 실패할 수 없다.
//• Events are sharing only when connected 이벤트는 연결되었을 때만 공유된다.
//• All events are delivered in the main scheduler 모든 이벤트는 메인 스케줄러로 보내진다.
//Driver와 비슷하지만, 구독 후, 마지막 이벤트는 replay 하지 않는 특성이 다르다.
//Driver와 Signal의 차이는 BehaviorSubject와 PublishSubject의 차이와 비슷하다.
//리소스에 연결 했을 때 마지막 이벤트에 대한 replay가 필요한가를 생각해서 필요없다면 Signal,
//필요하다면 Driver를 사용한다.

//RxCocoa가 필수적이지는 않지만 매우 유용하게 사용할 수 있다. 주요 장점으로는
//• 많이 사용되는 구성 요소들에 대해 많은 extension을 통합해 놨다.
//• 기본적인 UI 요소들보다 낫다.
//• Trait로 코드를 안전하게 보호할 수 있다.
//• Bind와 Drive를 함께 쉽게 사용할 수 있다.
//• Custom extension의 모든 메커니즘을 제공한다.

//때로는 오류 처리 시에, 오류가 난 시퀀스를 디버깅해야 할 수도 있다.
//혹은 서드파티 프레임워크를 사용할 때처럼 시퀀스 제어가 제한되거나 불가능해 오류가 발생할 수도 있다.
//RxSwift는 이런 경우, materialize와 dematerialize를 사용해 해결할 수 있다.
//• materialize는 어떤 시퀀스든 Event<T> eunm sequence로 변환한다. p.301
//(Rx의 Event<T> enum에는 next, completed, error의 세 가지 이벤트가 있다.)
//• demeterialize는 notification sequence를 일반 Observable로 변환한다. p.301
//이 두 연산자를 결합 해 사용자 지정 이벤트 로그를 만들 수 있다.
//observableToLog.materialize()
//    .do(onNext: { (event) in
//        myAdvancedLogEvent(event)
//    })
//    .dematerialize()

//materialize와 dematerialize는 보통 함께 쓰인다. 이 둘을 써서 원본 observable을 완전히 분해할 수 있다.
//다만, 특정 상황을 처리할 수 있는 다른 옵션이 없을 때만 신중하게 사용해야 한다.




