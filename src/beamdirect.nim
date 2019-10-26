import tables
import hashes
import arraymancer
import math

import inputData

const numDofsPerNode = 4
type DofDirection = enum tx, ty, rx, rz


type Dof = tuple
    node: uint
    direction: DofDirection

type DofTable = ref object
    dofs: seq[Dof]
    index: Table[Dof, int]

func hash(d: Dof): Hash = hash(d)

func dist(a, b: Node): float64 =
    let dx = b.loc.x - a.loc.x
    let dy = b.loc.y - a.loc.y
    return hypot(dx, dy)

func getStiffnessMatrix(elem: Element): Tensor[float64] =
    result = zeros[float64]([8, 8])

    let L = dist(elem.nodes[0], elem.nodes[1])
    let L2 = L*L
    let L3 = L2*L

    let nu = elem.mat.nu
    let A = elem.section.A
    let Iz = elem.section.Iz
    let J = elem.section.J

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

func getDofList(elem:Element): seq[Dof] =
    for n in elem.nodes:
        for dir in DofDirection:
            result.add((n.id, dir))

func buildDofTable(nodes:seq[Node]) : DofTable =
    result.dofs = newSeq[Dof](nodes.len * numDofsPerNode)
    result.index = initTable[Dof, int](rightSize(nodes.len * numDofsPerNode))
    for i, n in nodes:
        for k in DofDirection:
            let dof: Dof = (n.id, k)
            result.dofs.add dof
            result.index[dof] = i

func assemble(dofTable: DofTable, elems: seq[Element]): Tensor[float64] =
    let nDofs = dofTable.dofs.len
    result = zeros[float64](nDofs, nDofs)

    for e in elems:
        let ke = e.getStiffnessMatrix
        let elemDofs = e.getDofList
        for row, rowDof in elemDofs:
            for col, colDof in elemDofs:
                let rowDofGlobalId = dofTable.index[rowDof]
                let colDofGlobalId = dofTable.index[colDof]
                result[rowDofGlobalId, colDofGlobalId] += ke[row, col]

func solve(nodes: seq[Node], elems: seq[Element], spcs: seq[Spc], loads: seq[NodalLoad]): Tensor[float64] =
    let dofTable = buildDofTable(nodes)
    let kgg = assemble(dofTable, elems)
