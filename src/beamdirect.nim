import tables, hashes, math, sequtils, algorithm
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

    var kab = zeros[float64]([4, 4])
    kab[0, 0] = -A / L
    kab[1, 1] = -12 * Iz / L3
    kab[2, 2] = -J / (2 * (1+nu) * L)
    kab[3, 3] = 2 * Iz / L
    kab[1, 3] = 6 * Iz / L2
    kab[3, 1] = -6 * Iz / L2

    var kbb = zeros[float64]([4, 4])
    kbb[0, 0] = A / L
    kbb[1, 1] = 12 * Iz / L3
    kbb[2, 2] = J / (2 * (1+nu) * L)
    kbb[3, 3] = 4 * Iz / L
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

func buildDofTable(nodeTable: TableRef[EntityId, Node]) : DofTable =
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

func assemble(dofTable: DofTable, db: InputDb): Tensor[float64] =
    let nDofs = dofTable.dofs.len

    result = zeros[float64](nDofs, nDofs)
    for e in db.elements.values:
        let ke = e.getStiffnessMatrix(db)
        let elemDofs = e.getDofList
        for row, rowDof in elemDofs:
            for col, colDof in elemDofs:
                let rowDofGlobalId = dofTable.index[rowDof]
                let colDofGlobalId = dofTable.index[colDof]
                result[rowDofGlobalId, colDofGlobalId] += ke[row, col]

proc solve(db: InputDb): Tensor[float64] =
    let dofTable = buildDofTable(db.nodes)
    echo dofTable.dofs
    let kgg = assemble(dofTable, db)
    echo kgg

import os
let inputdef = commandLineParams()[0].readJsonInput
discard solve(inputdef)