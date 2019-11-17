import arraymancer
import dof

type ResultEntity* {.pure.} = enum
  Node
  Element

type ResultType* {.pure.} = enum
  Scalar
  Vector

type ResultRecord = tuple
  index: DofTable

type solveOutput = object
  displ: Tensor[float]
