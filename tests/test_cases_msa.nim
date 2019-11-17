import beamdirect, input
import utils_test
import arraymancer
import unittest, os

suite "Test cases MSA":
  test "Example 4.9":
    block:
      let
        dataFile = getAppDir() / "data" / "MSA_ex_4_9.json5"
        db = dataFile.readJsonInput
        res = solveStatic(db)

        exp_disp = [[0.0, 0.0, 0.0, 0.0],
                    [0.02357, 0.0, 0.0, -8.84E-4],
                    [0.0457, -19.15, 0.0, -5.30E-3]].toTensor

      check max_rel_error(res.disp.data, exp_disp) < 1E-3
