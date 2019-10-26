


type
    Node = object
        id: int
    
    Elem = object
        node: ref Node

let n1 = Node(id: 1)
let e1 = Elem(node: n1.addr)