//
//  ChecklistViewController.swift
//  Checklists
//
//  Created by 근성가이 on 2018. 1. 3..
//  Copyright © 2018년 근성가이. All rights reserved.
//

//iPad의 경우 4가지 방향을 모두 지원해야 한다.
//메서드를 작성하면 Xcode 메뉴 method jump bar에서 쉽게 찾을 수 있다.
//Swift의 많은 부분은 Objective C 프레임워크에서 왔다.

//iOS의 기본적인 패턴 : Delegate, Target-Action, Model-View-Controller
//Model : 데이터의 처리
//View : 시각적인 부분
//Controller : 데이터 모델을 뷰에 연결 (iOS에서는 ViewController)

import UIKit //"UI"로 시작하는 모든 것은 UIKit의 일부

class ChecklistViewController: UITableViewController { //테이블 뷰 컨트롤러(기본적으로 뷰 컨트롤러)가 delegate가 된다.
    
    var checklist: Checklist!

    override func viewDidLoad() { //()는 반환형이 없음을 나타낸다. // -> () // -> Void와 같다.
        super.viewDidLoad()
        //init? (coder) 는 스토리보드에서 뷰 컨트롤러가 만들어질 때에 호출된다.
        //이와 달리 viewDidLoad는 코드로 인스턴스화되도 호출된다. - 생성 방법에 관계 없이 뷰 컨트롤러가 생성될 때 호출된다.
        //init? (nibName : bundle :) 또는 init? (style :)로 생성할 수도 있다.
        
//        navigationController?.navigationBar.prefersLargeTitles = true //Large Title //iOS 11에서 추가 //스토리보드에서 설정할 수도 있다. //메인 뷰 등에만 추천
        
        title = checklist.name //navigation bar에 타이틀 입력
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func configureCheckmark(for cell: UITableViewCell, with item: ChecklistItem) { //외부, 내부 레이블
        //Swift에서는 "at", "with"또는 "for"같은 전치사를 메서드 이름에 추가하는 것이 일반적.
        //메서드의 이름이 적절한 영어 구문과 같이 발음 되도록.
        let label = cell.viewWithTag(1001) as! UILabel
        label.textColor = view.tintColor //틴트 색 변경
        
        //로컬 변수로 중복을 줄일 수 있다. //0이면 false, 1이면 true
        if item.checked {
            label.text = "✔︎"
        } else {
            label.text = ""
        }
    }
    
    func configureText(for cell: UITableViewCell, with item: ChecklistItem) { //각각 위치에 짧게 쓸 수 있지만 조금이라도 중복되면 메서드를 만드는 것이 좋다.
        let label = cell.viewWithTag(1000) as! UILabel //스토리보드에서 태그 값을 설정해 줄 수 있다. 태그의 기본 값은 0이다.
        //태그는 @IBOutlet을 만들지 않고도 손쉽게 UI 요소에 대한 참조를 가져올 수 있다.
        //이 경우에는 @IBOutlet로 연결하면, 각 객체의 레이블이 아니라 프로토 타입의 하나의 객체만 가져오므로 적절치 않다.
//        label.text = item.text
        label.text = "\(item.text)"
    }
}

//MARK: - Navigation
extension ChecklistViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "AddItem" { //여러 개의 세그가 있을 수 있으므로 해당 세그를 찾는다.
            let controller = segue.destination as! ItemDetailViewController //새롭게 표시할 뷰 컨트롤러는 destination으로 가져올 수 있다.
            //일반적으로 UIViewController 이므로, 참조할 객체를 가져오기 위해 캐스팅이 필요하다.
            controller.delegate = self
        } else if segue.identifier == "EditItem" { //Accessory action으로 셀을 터치 하는 것이 아니라, 엑서서리를 터치해 이동하는 segue를 만들 수 있다.
            let controller = segue.destination as! ItemDetailViewController
            controller.delegate = self
            
            if let indexPath = tableView.indexPath(for: sender as! UITableViewCell) { //sender를 캐스팅 해서 indexPath를 가져올 수 있다.
                controller.itemToEdit = checklist.items[indexPath.row] //컨트롤러 간 데이터 보내기
            }
        }
    }
    //1. 보낸 후의 컨트롤러에 속성을 만들어 보내기 전의 컨트롤러에서 인스턴스 생성해 할당한다.
    //2. delegate 이용
}

//MARK: - UITableViewDataSource
extension ChecklistViewController { //프로토콜. 특정 메소드나 변수를 구현하지만, 모든 세부 사항을 알 필요는 없다.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { //각 섹션의 열 수를 반환 //tableView가 메서드 이름이 아니라 arguments까지 모두 메서드의 이름이다.
        return checklist.items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell { //해당 셀을 가져온다.
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChecklistItem", for: indexPath)
        //재사용 셀을 가져온다.
        //IndexPath는 테이블의 특정 행을 가리키는 객체
        
        //1. 프로토 타입 셀을 스토리 보드의 테이블 뷰에 추가한다.
        //2. 프로토 타입 셀에 재사용 식별자를 설정한다.
        //3. tableView.dequeueReusableCell (withIdentifier : for :)을 호출한다.
        //  필요한 경우 프로토 타입 셀의 복사본을 만들거나 더 이상 사용하지 않는 기존 셀을 재활용한다.
        
        let item = checklist.items[indexPath.row] //배열에서 해당하는 순서의 요소를 가져온다.
        
        configureText(for: cell, with: item)
        configureCheckmark(for: cell, with: item) //영어 문장 발음하듯이 메서드를 호출한다.
        //일반적인 언어에서 메서드 호출은 configureCheckmark(someCell, someIndexPath)
        //Objective C와의 호환을 위한 어쩔 수 없는 측면도 있다.
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) { //이 메서드가 있는 경우, 테이블 뷰는 자동으로 스와이프 할 수 있도록 설정된다.
        checklist.items.remove(at: indexPath.row) //1. 데이터 모델에서 삭제
        
        let indexPaths = [indexPath]
        tableView.deleteRows(at: indexPaths, with: .automatic) //2. 뷰에서 삭제
        //레퍼런스가 없어지면 삭제된다.(ARC : Automatic Reference Counting)
    }
}

//MARK: - UITableViewDelegate
extension ChecklistViewController { //행이 선택된 이후 불리는 메서드
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) { //indexPath에 맞춰 cell 반환 //없으면 nil
            //위의 tableView.cellForRow(at :) 메서드와 혼동 주의
            
            let item = checklist.items[indexPath.row]
            item.toggleChecked()
            configureCheckmark(for: cell, with: item)
        }
        
        tableView.deselectRow(at: indexPath, animated: true) //해당 셀 선택 해제
    }
}


//MARK: - ItemDetailViewControllerDelegate
extension ChecklistViewController: ItemDetailViewControllerDelegate { //AddItemViewControllerDelegate를 추가하고 Xcode의 fix를 통해 구현되지 않은 메서드나 파라미터 코드를 손쉽게 추가할 수 있다.
    func itemDetailViewControllerDidCancel(_ controller: ItemDetailViewController) {
        navigationController?.popViewController(animated: true) //pop. 빼낸다.
    }
    
    func itemDetailViewController(_ controller: ItemDetailViewController, didFinishAdding item: ChecklistItem) { //1. 오브젝트 생성(이전 뷰 컨트롤러에서 생성해서 delegate로 넘어온다.)
        let newRowIndex = checklist.items.count
        checklist.items.append(item) //2. 데이터 모델에 추가
        
        let indexPath = IndexPath(row: newRowIndex, section: 0) //해당 세션의 newRowIndex에 row를 생성
        let indexPaths = [indexPath] //insertRows 메서드를 위해 배열로 만들어야 한다.
        tableView.insertRows(at: indexPaths, with: .automatic) //3. 뷰 업데이트
        //하나 밖에 없더라도 배열로만 넣어 줘야 한다. //with: .automatic로 애니메이션
        //tableView.insertRows (at : with :)를 호출하여 새 행을 삽입하면, OS가 tableView (_ : cellForRowAt :)를 호출하여 새 셀을 만든다.
        //단, 새로운 행이 실제 테이블 뷰에 보이는 부분에 있어야만 된다.
        //항상 데이터 모델과 뷰에 모두 추가해야 한다.
        
        navigationController?.popViewController(animated: true) //pop. 빼낸다.
    }
    
    func itemDetailViewController(_ controller: ItemDetailViewController, didFinishEditing item: ChecklistItem) {
        if let index = checklist.items.index(of: item) { //객체로 배열의 해당 인덱스를 가져올 수 있다. //없을 경우 nil
            //index(of :)를 사용하려면 equatable 프로토콜을 구현해야 한다. (비교 연산을 해야 되기 때문에)
            let indexPath = IndexPath(row: index, section: 0)
            if let cell = tableView.cellForRow(at: indexPath) {
                configureText(for: cell, with: item)
            }
        }
        
        navigationController?.popViewController(animated: true)
    }
}

//Delegate를 통해 코드 수행의 일부를 위임한다. 여기서 테이블 뷰는 실제 데이터의 종류나 처리를 신경쓰지 않아도 된다.
//이런 식으로 구현하면, 테이블 뷰의 구성이 단순하게 유지되고, 코드를 효율적으로 관리할 수 있다.

//Delegate 설정
//1 - 객체 B에 대한 delegate Protocol 정의
//2 - 객체 B에 delegate 변수를 weak, optional로 지정
//3 - 필요할 때 객체 B를 업데이트하여 delegate에 메시지를 전송. delegate?.methodName(self, ...)
//4 - 객체 A가 delegate protocol을 선언하고 구현
//5 - 객체 B에게 객체 A가 delegate 임을 전달 (prepare(for: sender))

//적절한 데이터 모델을 사용하지 않으면, 재사용 셀을 사용하면서 이전 셀의 내용과 새로운 셀의 내용이 겹쳐지거나 제대로 안 보여질 때가 있다.

//세그 종류
//1. Show : 스택의 맨 위에 오도록 푸시. (메일에서 폴더 탐색)
//2. Show Detail : Split View에서 주로 사용. (메시지에서 대화 탭)
//3. Present Modally : 새로운 뷰 컨트롤러를 위에 띄운다. 가장 일반적. (설정에서 비밀번호)
//4. Present as Popover : 팝 오버 된 이외의 부분을 두드리면 사라진다(iPad). iPhone에서는 Modal로 표시 된다.
//5. Custom : 사용자 지정

//바 버튼 아이템을 시스템으로 해 두면, OS 설정 언어에 따라 표시되는 언어가 자동으로 바뀐다.
