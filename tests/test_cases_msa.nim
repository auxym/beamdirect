import beamdirect, input
import arraymancer
import unittest, os

suite "Test cases MSA":
  test "Example 4.9":
    block:
      let
        dataFile = getAppDir() / "data" / "MSA_ex_4_9.json5"
        db = dataFile.readJsonInput
        res = solveStatic(db)

      echo res.reshape(res.shape[0], 1)

