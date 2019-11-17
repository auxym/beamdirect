import arraymancer
import basetypes

type ElementVectorArray* = object
  headers*: seq[string]
  data*: Tensor[float]
  element_nodes*: Tensor[int]

type NodeVectorArray* = object
  headers*: seq[string]
  nodes*: Tensor[int]
  data*: Tensor[float]

type solveOutput* = object
  disp*: NodeVectorArray
