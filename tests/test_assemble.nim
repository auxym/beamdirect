import beamdirect, input, utils_test
import arraymancer, unittest, os, sequtils

suite "assemble":
    test "check global stiffness matrix":
        let
            dataFile = getAppDir() / "data/MSA_ex_4_8.json5"
            db = readJsonInput dataFile
            allDofs = buildDofTable(db.nodes)
            kgg = assemble(db, allDofs)

        check kgg.isSymmetric()

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
        check max_rel_error(kgg, sol) < 1E-4

suite "partition":
    test "partition 3x3 matrix":
        let a = [[1, 2, 3],
                 [4, 5, 6],
                 [7, 8, 9]].toTensor()

        let (a11, a12, a21, a22) = partition(a, @[false, true, false])

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
            cp = repeat(false, 10)
            (a11, a12, a21, a22) = a.partition(cp)

        check a11 == ones[float](10, 10)
        check a12.shape == [10, 0]
        check a21.shape == [0, 10]
        check a22.shape == [0, 0]

    test "partition all true":
        let
            a = ones[float](10, 10)
            cp = repeat(true, 10)
            (a11, a12, a21, a22) = a.partition(cp)
            
        check a22 == ones[float](10, 10)
        check a12.shape == [0, 10]
        check a21.shape == [10, 0]
        check a11.shape == [0, 0]