Ch1. What is TDD?

TDD (Test-driven development)는 작은 단위의 테스트를 반복적으로 수행하여 소프트웨어를 개발하는 방법이다. TDD에는 4가지 단계가 있다. p.23
 1. Write a failing test(실패하는 테스트 작성)
 2. Make the test pass(테스트 통과)
 3. Refactor(리팩터)
 4. Repeat(반복)
이를 TDD Cycle이라 한다. 테스트가 개발을 주도하므로, 코드를 철저하고 정확하게 테스트 할 수 있다.
테스트 다음에 실제 production code를 작성하면, production code를 테스트할 수 있고, 개발 중 모든 요구 사항을 충족하는 지 확인할 수 있다.
추가적으로 테스트는 production code의 문서 역할을 하며, 작동 방식을 설명한다.




Why should you use TDD?
TDD는 소프트웨어가 작동하고, 장래에도 계속 잘 작동함을 보장할 수 있는 가장 좋은 방법이다. 코드 테스트가 꼭 TDD를 따를 필요는 없다. 
예를 들어, 모든 production code를 작성한 다음 모든 test code를 작성할 수도 있다. 
또는, 테스트 작성을 생략하고 대신 코드를 수동으로 테스트할 수도 있다. 
좋은 테스트는 앱이 예상대로 작동함을 보장한다. 모든 테스트가 "좋은" 테스트는 아니다. 테스트를 위해 테스트를 작성하는 것은 의미가 없다. 
좋은 테스트는 실패(failable), 반복(repeatable), 빠른 실행(quick to run) 및 유지 관리(maintainable)가 가능해야 한다.
TDD에서 다음의 방법으로 해당 테스트가 좋은 테스트인지 확인한다.
    • 첫 번째 단계는 실패하는 테스트(failing test)를 작성하는 것이다. 실패할 수 없는 테스트는 유용하지 않다. 오히려 귀중한 CPU time을 낭비한다.
    • 새 테스트를 작성하기 전에, 이전의 모든 테스트를 통과해야 한다. 이렇게 해서 테스트가 반복가능(repeatable)한지 확인한다. 
        작업 중인 단일 테스트를 실행하는 것이 아니라 지속적으로 모든 테스트를 실행해야 한다.
    • 모든 테스트를 자주 실행해, 테스트가 빠르게(quick) 실행되도록 해야 한다. 모든 테스트를 실행하는 데에는 1초 이하의 시간이 소요되는 것이 바람직하다.
        단일 테스트가 수 100ms 시간이 걸린다면 너무 느린 것이다. 이는 10회 테스트를 진행하는데 1초, 50회 테스트에는 5초가 걸린다.
        이렇게 누적되는 시간이 길어지면, 모든 테스트를 실행하는 게 부담스러워진다.
    • 리팩토링(refactor)시에, production code와 test code를 모두 업데이트 한다. 이를 통해 테스트 유지를 보장하고(maintained), 지속적으로 최신 상태를 유지한다.
    • production code와 테스트를 병렬로 반복 작성해, 코드의 테스트 가능성(testable)이 보장되는지 확인한다. 
        코드를 작성 후에 테스트를 작성한다면, production code는 완전한 단위 테스트를 위한 리팩토링이 필요할 수 있다.
TDD를 사용하지 않고도 좋은 테스트를 작성할 수 있지만, 장기적으로는 매우 어려워 진다.




What should you test?
테스트의 적용 범위가 넓어진다고 해서, 앱 테스트가 더 나아지는 것은 아니다. 테스트 해야할 사항과 하지 말아야 할 사항은 다음과 같다.
    • 자동화된 방식으로 포착할 수 없는 코드에 대한 테스트를 작성한다. 여기에는 class의 method, getter, setter 및 대부분의 직접 작성한 class 코드가 포함된다.
    • 생성된 코드에 대한 테스트를 작성해선 안 된다. 
        예를 들어, 생성된 getter, setter에 대한 테스트를 작성하는 것은 의미가 없다. Swift에서 작성한 이런 코드들은 제대로 작동한다고 믿을 수 있다.
    • 컴파일러가 탐지할 수 있는 오류에 대한 테스트를 작성해선 안 된다. error나 warning을 발생시키는 테스트는 Xcode에서 감지할 수 있다.
    • 앱에서 사용되는 프레임워크(first-party, third-party 모두)에 대한 dependency code 테스트를 작성해선 안 된다. 
        이런 테스트는 프레임워크 개발자가 작성해야 한다. 
        예를 들어, UIKit 개발자가 이에 대한 테스트를 작성해야지, 우리가 할 필요 없다. 
        하지만, 사용자 정의 하위 클래스(Custom subclass)에 대한 테스트는 우리가 담당자이므로 이에 대한 테스트는 작성해야 한다.
예외적으로 프레임워크 작동 순서를 결정하는 테스트를 작성할 수 있다. 이것은 유용하지만, 장기간 해당 테스트를 유지할 필요 없다. 오히려 나중에는 삭제해야 한다.
또 다른 예외는 third-party code가 예상대로 작동하는 것을 증명하는 "sanity tests" 이다. 
이러한 두 가지 예외적인 테스트는 library가 안정적이지 않거나 신뢰할 수 없는 경우에 유용하다.




But TDD takes too long!
TDD에 대한 단점으로 가장 많이 지적되는 것은 너무 오래 걸린다는 것이다. 
TDD는 익숙해질수록 더 빨라지지만, 테스트 코드를 추가하면 더 많은 코드를 작성해야 하므로 궁극적으로 개발 초기에는 더 많은 시간이 필요하다. 
하지만 초기 버전 production code 작성에 걸리는 시간만으로 개발에 들어가는 총 시간 비용을 측정해선 안 된다. 
시간이 지남에 따라 기능 추가, 기존 코드 수정, 버그 수정 등의 추가 구현이 필요하므로, 장기적으로는 TDD를 따르는 것이 
버그를 줄이고 유지 관리가 더 쉬운 코드를 생성해 오히려 시간을 더 절약할 수 있다. 
고려해야할 또다른 비용은 앱의 버그가 사용자에게 영향을 끼친다는 것이다. 이런 버그가 오래 지속될 수록, 부정적인 리뷰, 신뢰도 감소, 이익 감소 등을 초래할 수 있다.
개발 과정에서 문제가 발생하면 보다 쉽게 디버깅하고 해결할 수 있다. 시간이 지나 몇 주 후에 이런 문제를 발견한다면, 원인을 찾고 수정하는데 더 많은 시간이 소요된다.
TDD를 따르면 버그로부터 안전한 앱을 작성하는 데 큰 도움이 된다.




When should you use TDD?
TDD는 life cycle에서 new development과 legacy apps 사이의 모든 시점에서 사용할 수 있다. 하지만 TDD를 시작하는 방법과 시기는 프로젝트에 따라 달라진다.
앱이 수 개월 동안 여러 번 출시되거나 복잡한 로직이 필요한 경우 TDD를 사용하는 것이 좋다. 하지만, 해커톤, 테스트 프로젝트와 같이 TDD를 사용하지 않는 것이 나은 경우도 있다.
TDD는 하나의 도구이므로, 이를 사용하는 시기를 결정하는 것은 프로그래머의 몫이다.




Key points
TDD가 무엇인지, TDD를 사용해야 하는 이유, 테스트 대상과 사용 시기 등에 대해 알아봤다.
    • TDD는 우수한 테스트를 작성하는 일관된 방법을 제공한다.
    • 좋은 테스트는 실패할 수 있고(failable), 반복 가능하며(repeatable), 빠르게(quick) 실행(run) 및 유지 보수(maintainable) 할 수 있어야 한다.
    • 유지 관리해야하는 코드에 대한 테스트를 작성한다. 자동 생성되거나 종속성 코드에 대한 테스트를 작성하지 않는다.
    • 실제 개발 비용에는 초기 코드 작성, 새로운 기능 추가, 코드 수정, 버그 수정 등이 포함된다. TDD는 유지 보수 비용과 버그를 줄이는 가장 효율적인 접근 방식이다.
    • TDD는 수 개월 이상 지속되거나, 여러 번 출시되는 장기 프로젝트에 가장 유용하다.