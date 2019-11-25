import tables, sequtils, sets
from algorithm import sort, sortedByIt
import arraymancer
import database, basetypes, indextable, solveroutput, element

func assemble*(db: InputDb, dofTab: DofTable): Tensor[float64] =
    let nDofs = dofTab.len

    result = zeros[float64](nDofs, nDofs)
    for eid in db.elements.keys:
        let
            elem = db.getElemDenorm(eid) 
            ke = elem.getStiffnessMatrix
            elemDofs = elem.getDofList
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
    # Create hashset of indices used for partioning tensors
    result.init(sets.rightSize(dofs2.len))
    for df in dofs2:
        result.incl allDofs[df]

type SpcAppResult* = tuple
    kff: Tensor[float]
    kfs: Tensor[float]
    pf: Tensor[float]
    ys: Tensor[float]
    fset: DofTable
    sset: DofTable

func applySpcs*(knn, pn: Tensor[float], nset: DofTable, spcs: seq[Spc]): SpcAppResult =
    # Partition knn and pn in f and s sets
    let
        (sset, ys) = unpackSpcs(spcs, nset)
        spartset = buildPartSet(nset, sset)
        (kff, kfs, ksf, kss) = partitionMatrix(knn, spartset)
        (pf_bar, ps) = partitionVector(pn, spartset)

    let fset = nset.difference(sset)

    result.kff = kff
    result.kfs = kfs
    result.pf = pf_bar - kfs * ys
    result.fset = fset
    result.sset = sset
    result.ys = ys

    doAssert result.kff.shape[0] == result.fset.len
    doAssert result.pf.shape[0] == result.fset.len

func buildNodeIndex(dt: openArray[DofTable]): IndexTable[EntityId] =
    let size_est = dt.mapIt(it.len).foldl(a+b) div 4
    result = initIndexTable[EntityId](tables.rightSize(size_est))

    for tab in dt:
        for d in tab:
            if d.node notin result:
                result.add d.node

func buildNodeVectorArray(source: varargs[
    tuple[idx: DofTable, data: Tensor[float]]]): NodeVectorArray =

    var allTabs = newSeq[DofTable](source.len)
    for (tab, data) in source:
        allTabs.add tab

    func dir2int(d: DofDirection): int =
        case d:
            of tx: result = 0
            of ty: result = 1
            of rx: result = 2
            of rz: result = 3

    let idx = buildNodeIndex(allTabs).sorted
    result.nodes = idx.allItems.toTensor
    result.data = zeros[float](idx.len, numDofsPerNode)

    for (tab, data) in source:
        for row in 0..<data.shape[0]:
            let
                rdof = tab[row]
                resultrow = idx.getIndex(rdof.node)
                resultcol = dir2int(rdof.direction)
            result.data[resultrow, resultcol] = data[row]

func solveStatic*(db: InputDb): solveOutput =
    let
        nset = db.buildDofTable
        knn = db.assemble(nset)
        pn = db.getLoadVector(nset)

        spcReduced = applySpcs(knn=knn, pn=pn, nset=nset, spcs=toSeq(db.spcs.values))

    # Solve for f-set displacements
    let uf = solve(spcReduced.kff, spcReduced.pf)

    result.disp = buildNodeVectorArray((spcReduced.fset, uf),
        (spcReduced.sset, spcReduced.ys))
    result.disp.headers = @["tx", "ty", "rx", "rz"]

    # Reaction loads
    block:
        let reacts = spcReduced.kfs.transpose * uf
        result.reacts = buildNodeVectorArray((spcReduced.sset, reacts))
