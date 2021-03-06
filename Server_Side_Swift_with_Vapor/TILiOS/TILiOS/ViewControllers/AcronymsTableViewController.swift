/// Copyright (c) 2018 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit

class AcronymsTableViewController: UITableViewController {

  // MARK: - Properties
  var acronyms: [Acronym] = []
  //테이블에 표시할 Acronym를 담아두는 배열
  let acronymsRequest = ResourceRequest<Acronym>(resourcePath: "acronyms")
  //Acronym에 대한 ResourceRequest 생성. API에서 Acronym 결과를 요청하고 가져온다.

  // MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.tableFooterView = UIView()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    refresh(nil)
  }

  func refresh() {
    if refreshControl != nil {
      refreshControl?.beginRefreshing()
    }
    refresh(refreshControl)
  }

  // MARK: - IBActions
  @IBAction func refresh(_ sender: UIRefreshControl?) {
    //뷰가 화면에 나타날 때 마다(viewWillAppear) 뷰를 새로 고침한다.
    //UIRefreshControl는 스크롤 뷰 내용의 새로고침을 할 수 있는 컨트롤이다. 사용자 제스처의 응답으로 작업을 처리한다.
    //컨트롤러는 새로고침을 자동으로 하지 않으므로, 직접 코드로 구현해 줘야 한다(valueChanged). Pull to Refresh 등에 쓰인다.
    //스토리 보드에는 UIView로 추가해서, class를 UIRefreshControl로 지정해 valueChanged를 IBAction으로 지정해 주면 된다.
    acronymsRequest.getAll { [weak self] acronymResult in
      //getAll을 호출해서, 모든 Acronym을 가져온다. 클로저 파라미터인 acronymResult에 반환된 모든 데이터가 있다.
      DispatchQueue.main.async {
        sender?.endRefreshing() //새로고침 완료
      }

      switch acronymResult {
      case .failure: //데이터 가져오기 실패 시
        ErrorPresenter.showError(message: "There was an error getting the acronyms", on: self)
      case .success(let acronyms): //데이터 가져오기 성공 시
        DispatchQueue.main.async { [weak self] in
          self?.acronyms = acronyms //데이터(모든 Acronym 배열)를 갱신하고
          self?.tableView.reloadData() //테이블 뷰 리로드
        }
      }
    }
  }

  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "AcronymsToAcronymDetail" { //상세 보기
      guard let destination = segue.destination as? AcronymDetailTableViewController,
        let indexPath = tableView.indexPathForSelectedRow else {
          //indexPathForSelectedRow로 바로 선택한 cell의 indexPath를 가져올 수 있다.
          return
      }

      destination.acronym = acronyms[indexPath.row] //상세 보기의 acronym 설정
    }
  }
}

// MARK: - UITableViewDataSource
extension AcronymsTableViewController {

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return acronyms.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let acronym = acronyms[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: "AcronymCell", for: indexPath)
    cell.textLabel?.text = acronym.short
    cell.detailTextLabel?.text = acronym.long
    return cell
  }

  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    //editing control 사용. Swipte-to-delete
    if let id = acronyms[indexPath.row].id { //유효한 id를 가지고 있으면
      let acronymDetailRequester = AcronymRequest(acronymID: id)
      //AcronymRequest 해당 Acronym 삭제
      acronymDetailRequester.delete()
    }

    acronyms.remove(at: indexPath.row) //local 배열의 해당 Acronym 삭제
    tableView.deleteRows(at: [indexPath], with: .automatic)
    //테이블 뷰에서 Acronym 행 삭제
  }
}
