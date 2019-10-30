import beamdirect, input, utils_test
import arraymancer, unittest, os

suite "assemble":
    test "check global stiffness matrix":
        let
            dataFile = getAppDir() / "data/MSA_ex_4_8.json5"
            db = readJsonInput dataFile
            allDofs = buildDofTable(db.nodes)
            kgg = assemble(db, allDofs)

        var sol = zeros[float](12, 12)
        sol[0, 0..4] = [[0.75, 0, 0, 0, -0.75]]
        sol[1, 1..7] = [[0.00469, 0, 18.75, 0, -0.00469, 0, 18.75]]
        sol[2, 2..7] = [[14.423, 0, 0, 0, -14.423, 0]]
        sol[3, 3..7] = [[1E5, 0, -18.75, 0, 0.5E5]]
        sol[4, 4..8] = [[1.55, 0, 0, 0, -0.8]]
        sol[5, 5..11] = [[0.00949, 0, -6.75, 0, -0.0048, 0, 12.0]]
        sol[6, 6..11] = [[22.115, 0, 0, 0, -7.692, 0]]
        sol[7, 7..11] = [[1.4E5, 0, -12.0, 0, 0.2E5]]
        sol[8, 8] = 0.8
        sol[9, 9..11] = [[0.0048, 0, -12.0]]
        sol[10, 10] = 7.692
        sol[11, 11] = 0.4E5

        sol = triutosym(sol) * 2E5
        check mean_relative_error(kgg, sol) < 1E-4