import beamdirect, input, utils_test, database, sets, basetypes, indextable
import arraymancer
import unittest, os, sequtils, tables
from math import sqrt

suite "assemble":
    test "check global stiffness matrix":
        let
            dataFile = getAppDir() / "data/MSA_ex_4_8.json5"
            db = readJsonInput dataFile
            allDofs = db.buildDofTable
            knn = assemble(db, allDofs)

        check knn.isSymmetric()

        var sol = zeros[float](12, 12)
        sol[0, 0..4] = [[0.75, 0, 0, 0, -0.75]]
        sol[1, 1..7] = [[0.0046875, 0, 18.75, 0, -0.0046875, 0, 18.75]]
        sol[2, 2..7] = [[14.423, 0, 0, 0, -14.423, 0]]
        sol[3, 3..7] = [[1E5, 0, -18.75, 0, 0.5E5]]
        sol[4, 4..8] = [[1.55, 0, 0, 0, -0.8]]
        sol[5, 5..11] = [[(0.0046875 + 0.0048), 0, -6.75, 0, -0.0048, 0, 12.0]]
        sol[6, 6..11] = [[22.115, 0, 0, 0, -7.692, 0]]
        sol[7, 7..11] = [[1.4E5, 0, -12.0, 0, 0.2E5]]
        sol[8, 8] = 0.8
        sol[9, 9..11] = [[0.0048, 0, -12.0]]
        sol[10, 10] = 7.692
        sol[11, 11] = 0.4E5

        sol = triutosym(sol) * 2E5
        check max_rel_error(knn, sol) < 1E-4

    test "check load vector":
        let
            dataFile = getAppDir() / "data/MSA_ex_4_9.json5"
            db = readJsonInput dataFile
            allDofs = db.buildDofTable
            loadvec = getLoadVector(db, allDofs)

        var loadvec_true = zeros[float](12)
        loadvec_true[allDofs[(3, tx)]] = 5000 / sqrt(2.0)
        loadvec_true[allDofs[(3, ty)]] = -5000 / sqrt(2.0)

        check loadvec.shape[0] == allDofs.len
        check max_rel_error(loadvec, loadvec_true) < 1E-6

    test "apply zero SPCs":
        let
            dataFile = getAppDir() / "data/MSA_ex_4_9.json5"
            db = readJsonInput dataFile
            nset = db.buildDofTable
            knn = assemble(db, nset)
            pn = db.getLoadVector(nset)
            spcReduced = applySpcs(knn=knn, pn=pn, nset=nset,
                                   spcs=toSeq(db.spcs.values))

            kff_true = [
                [1.55, 0, 0, -0.8, 0, 0, 0],
                [0.0, 22.115, 0, 0, 0, -7.6923, 0],
                [0.0, 0.0, 1.4E5, 0, -12, 0, 2E4],
                [0.0, 0.0, 0.0, 0.8, 0, 0, 0],
                [0.0, 0.0, 0.0, 0.0, 0.0048, 0, -12],
                [0.0, 0.0, 0.0, 0.0, 0.0, 7.6923, 0],
                [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4E4],
            ].toTensor.triutosym * 2E5

            pf_true = [0.0, 0, 0, 5.0/sqrt(2.0), -5.0/sqrt(2.0), 0, 0].toTensor * 1E3

        check spcReduced.kff.shape == [7, 7]
        check spcReduced.fset.len == 7
        check spcReduced.pf.shape == [7,]

        check max_rel_error(spcReduced.kff, kff_true) < 1E-4
        check max_rel_error(spcReduced.pf, pf_true) < 1E-8


suite "partition":
    test "partition 3x3 matrix":
        let a = [[1, 2, 3],
                 [4, 5, 6],
                 [7, 8, 9]].toTensor()

        let (a11, a12, a21, a22) = partitionMatrix(a, [1].toHashSet)

        let
            a11_true = [[1, 3], [7, 9]].toTensor()
            a12_true = [[2], [8]].toTensor()
            a21_true = [[4, 6]].toTensor()
            a22_true = [[5]].toTensor()

        check a11 == a11_true
        check a12 == a12_true
        check a21 == a21_true
        check a22 == a22_true

    test "partition all false":
        let
            a = ones[float](10, 10)
            empty = initHashSet[int]()
            (a11, a12, a21, a22) = a.partitionMatrix(empty)

        check a11 == ones[float](10, 10)
        check a12.shape == [10, 0]
        check a21.shape == [0, 10]
        check a22.shape == [0, 0]

    test "partition all true":
        let
            a = ones[float](10, 10)
            (a11, a12, a21, a22) = a.partitionMatrix(toSeq(0..<10).toHashSet)
            
        check a22 == ones[float](10, 10)
        check a12.shape == [0, 10]
        check a21.shape == [10, 0]
        check a11.shape == [0, 0]

    test "partition vector":
        let
            x = toSeq(0..6).toTensor()
            (x1, x2) = x.partitionVector([2, 6].toHashSet)
            x1_true = [0, 1, 3, 4, 5].toTensor()
            x2_true = [2, 6].toTensor()

        check x1 == x1_true
        check x2 == x2_true