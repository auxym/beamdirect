import arraymancer

func triutosym*[T: SomeNumber](a: Tensor[T]) : Tensor[T] =
    ## Create symmetric matrix from upper triangular part
    result = zeros_like(a)
    let N = a.shape[0]
    for i in 0..<N:
        for j in i..<N:
            result[i, j] = a[i, j]
            if i != j:
                result[j, i] = a[i, j]

func isSymmetric*[T: SomeNumber](a: Tensor[T]): bool =
    let N = a.shape[0]
    for i in 0..<N:
        for j in 0..<N:
            if i == j:
                continue
            elif a[i, j] != a[j, i]:
                return false
    return true

func max_abs_error*[T: SomeFloat](y, y_true: Tensor[T]): T =
    absolute_error(y, y_true).max()

func max_rel_error*[T: SomeFloat](y, y_true: Tensor[T]): T =
    relative_error(y, y_true).max()