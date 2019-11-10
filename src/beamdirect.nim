import tables, hashes, sequtils, sets
from math import hypot
from algorithm import sort, sortedByIt
import arraymancer
import database, dof, basetypes

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

    doAssert nodeA.loc.y == nodeB.loc.y

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


func assemble*(db: InputDb, dofTab: DofTable): Tensor[float64] =
    let nDofs = dofTab.len

    result = zeros[float64](nDofs, nDofs)
    for e in db.elements.values:
        let
            ke = e.getStiffnessMatrix(db)
            elemDofs = e.getDofList
        for row, rowDof in elemDofs:
            for col, colDof in elemDofs:
                let rowDofGlobalId = dofTab[rowDof]
                let colDofGlobalId = dofTab[colDof]
                result[rowDofGlobalId, colDofGlobalId] += ke[row, col]

func partitionVector*[T: SomeNumber](v: Tensor[T], part2: HashSet[int]):
    (Tensor[T], Tensor[T]) =
    assert v.rank == 1

    let
        n = v.shape[0]
        npart2 = part2.len
        npart1 = n - npart2
    
    var
        v1 = newTensorUninit[T](npart1)
        v2 = newTensorUninit[T](npart2)
        i1 = 0
        i2 = 0

    for i in 0..<n:
        if i in part2:
            v2[i2] = v[i]
            inc i2
        else:
            v1[i1] = v[i]
            inc i1
    
    return (v1, v2)

func partitionMatrix*[T: SomeNumber](a: Tensor[T], part2: HashSet[int]): 
    (Tensor[T], Tensor[T], Tensor[T], Tensor[T]) =
    assert a.rank == 2
    assert a.shape[0] == a.shape[1]

    let
        n = a.shape[0]
        npart2 = part2.len
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
        if row in part2: inc row2 else: inc row1

        for col in 0..<n:
            if col in part2: inc col2 else: inc col1
            case getDest(row in part2, col in part2):
                of q11:
                    a11[row1, col1] = a[row, col]
                of q12:
                    a12[row1, col2] = a[row, col]
                of q21:
                    a21[row2, col1] = a[row, col]
                of q22:
                    a22[row2, col2] = a[row, col]
    
    return (a11, a12, a21, a22)

func getLoadVector*(db: InputDb, doftab: DofTable): Tensor[float] =
    result = zeros[float](doftab.len)
    for ld in db.loads.values:
        for comp, val in ld.comps:
            let idx = doftab[(ld.node, comp)]
            result[idx] = val

func unpackSpcs(spcs: seq[Spc], doftab: DofTable): (DofTable, Tensor[float]) =
    # Extract seq of (dof, y) pairs from the Spc objects
    type spcTuple = tuple[d: Dof, y: float]
    var spcTupleList = newSeqOfCap[spcTuple](doftab.len)
    for spc in spcs:
        for co, val in spc.comps:
            spcTupleList.add ((spc.node, co), val)

    # Sort in same order is input DOFs
    spcTupleList.sort do (a, b: spcTuple) -> int:
        let a_idx = doftab[a.d]
        let b_idx = doftab[b.d]
        cmp(a_idx, b_idx)
    
    # Build results
    var
        dofs = initDofTable(spcTupleList.len)
        ys = newTensorUninit[float](spcTupleList.len)
    for i, st in spcTupleList:
        dofs.add st.d
        ys[i] = st.y

    return (dofs, ys)

func buildPartSet(allDofs, dofs2: DofTable): HashSet[int] =
    result.init(sets.rightSize(dofs2.len))
    for df in dofs2:
        result.incl allDofs[df]

type SpcAppResult = tuple
    kff: Tensor[float]
    kfs: Tensor[float]
    pf: Tensor[float]
    fset: DofTable

func applySpcs*(knn, pn, ys: Tensor[float], nset, sset: DofTable): SpcAppResult =
    # Partition knn and pn in f and s sets
    let
        spartset = buildPartSet(nset, sset)
        (kff, kfs, ksf, kss) = partitionMatrix(knn, spartset)
        (pf_bar, ps) = partitionVector(pn, spartset)

    let fset = nset.difference(sset)

    result.kff = kff
    result.kfs = kfs
    result.pf = pf_bar - kfs * ys
    result.fset = fset

    doAssert result.kff.shape[0] == result.fset.len
    doAssert result.pf.shape[0] == result.fset.len

proc solveStatic*(db: InputDb): Tensor[float64] =
    let
        nset = db.buildDofTable
        knn = db.assemble(nset)
        pn = db.getLoadVector(nset)

        (sset, ys) = unpackSpcs(toSeq(db.spcs.values), nset)
        spcReduced = applySpcs(knn=knn, pn=pn, nset=nset, sset=sset, ys=ys)

    # let uf = solve(spcReduced.kff, spcReduced.pf)
    # let spcforce = spcReduced.kfs.T * uf

