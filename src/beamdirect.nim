import tables, hashes, sequtils
from math import hypot
from algorithm import sort
import arraymancer
import input

const numDofsPerNode = 4
type DofDirection = enum tx, ty, rx, rz

type Dof = tuple
    node: EntityId
    direction: DofDirection

type DofTable = ref object
    dofs: seq[Dof]
    index: Table[Dof, int]

func hash(d: Dof): Hash = !$(d.node.hash !& d.direction.hash)

func dist(a, b: Node): float64 =
    let dx = b.loc.x - a.loc.x
    let dy = b.loc.y - a.loc.y
    return hypot(dx, dy)

func getStiffnessMatrix(elem: Element, db: InputDb): Tensor[float64] =
    result = zeros[float64]([8, 8])

    let nodeA = db.nodes[elem.nodes[0]]
    let nodeB = db.nodes[elem.nodes[1]]
    let mat = db.materials[elem.mat]
    let section = db.sections[elem.section]

    let L = dist(nodeA, nodeB)
    let L2 = L*L
    let L3 = L2*L

    let nu = mat.nu
    let E = mat.E
    let A = section.A
    let Iz = section.Iz
    let J = section.J

    var kaa = zeros[float64]([4, 4])
    kaa[0, 0] = A / L
    kaa[1, 1] = 12 * Iz / L3
    kaa[2, 2] = J / (2 * (1+nu) * L)
    kaa[3, 3] = 4 * Iz / L
    kaa[1, 3] = 6 * Iz / L2
    kaa[3, 1] = 6 * Iz / L2

    var kab = -kaa.clone()
    kab[3, 3] = 2 * Iz / L
    kab[1, 3] = 6 * Iz / L2
    kab[3, 1] = -6 * Iz / L2

    var kbb = kaa.clone()
    kbb[1, 3] = -6 * Iz / L2
    kbb[3, 1] = -6 * Iz / L2

    result[0..3, 0..3] = kaa
    result[0..3, 4..7] = kab
    result[4..7, 0..3] = kab.transpose
    result[4..7, 4..7] = kbb
    result = result * E

func getDofList(elem: Element): seq[Dof] =
    for nodeId in elem.nodes:
        for dir in DofDirection:
            result.add((nodeId, dir))
    assert result.len == 8

func buildDofTable*(nodeTable: TableRef[EntityId, Node]) : DofTable =
    var nodeIds = toSeq(nodeTable.keys)
    nodeIds.sort

    let numDofs = nodeTable.len * numDofsPerNode
    new(result)
    result.dofs = newSeqofCap[Dof](numDofs)
    result.index = initTable[Dof, int](rightSize(numDofs))

    var dofId = 0
    for nodeId in nodeIds:
        for dir in DofDirection:
            let dof: Dof = (nodeId, dir)
            result.dofs.add dof
            result.index[dof] = dofId
            inc dofId

    assert result.dofs.len == numDofs
    assert result.index.len == numDofs

func assemble*(db: InputDb, dofTab: DofTable): Tensor[float64] =
    let nDofs = dofTab.dofs.len

    result = zeros[float64](nDofs, nDofs)
    for e in db.elements.values:
        let
            ke = e.getStiffnessMatrix(db)
            elemDofs = e.getDofList
        for row, rowDof in elemDofs:
            for col, colDof in elemDofs:
                let rowDofGlobalId = dofTab.index[rowDof]
                let colDofGlobalId = dofTab.index[colDof]
                result[rowDofGlobalId, colDofGlobalId] += ke[row, col]

func partition*[T: SomeNumber](a: Tensor[T], cp: seq[bool]): 
    (Tensor[T], Tensor[T], Tensor[T], Tensor[T]) =
    assert a.rank == 2
    assert a.shape[0] == a.shape[1]
    assert cp.len == a.shape[0]

    let
        n = a.shape[0]
        npart2 = cp.count(true)
        npart1 = n - npart2

    var
        a11 = newTensorUninit[T](npart1, npart1)
        a12 = newTensorUninit[T](npart1, npart2)
        a21 = newTensorUninit[T](npart2, npart1)
        a22 = newTensorUninit[T](npart2, npart2)

    type Quadrant = enum q11, q12, q21, q22
    func getDest(srcRow, srcCol: bool): Quadrant =
        if not srcRow and not srcCol: return q11
        if srcRow and not srcCol: return q21
        if not srcRow and srcCol: return q12
        if srcRow and srcCol: return q22

    var row1, row2 = -1
    for row in 0..<n:
        var col1, col2 = -1
        if cp[row]: inc row2 else: inc row1

        for col in 0..<n:
            if cp[col]: inc col2 else: inc col1
            case getDest(cp[row], cp[col]):
                of q11:
                    a11[row1, col1] = a[row, col]
                of q12:
                    a12[row1, col2] = a[row, col]
                of q21:
                    a21[row2, col1] = a[row, col]
                of q22:
                    a22[row2, col2] = a[row, col]
    
    return (a11, a12, a21, a22)


proc solve*(db: InputDb): Tensor[float64] =
    let dofTable = buildDofTable(db.nodes)
    let kgg = assemble(db, dofTable)

when isMainModule:
    import os
    let inputdef = commandLineParams()[0].readJsonInput
    discard solve(inputdef)