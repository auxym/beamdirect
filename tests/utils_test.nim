import arraymancer

func triutosym*[T: SomeNumber](a: Tensor[T]) : Tensor[T] =
    ## Createe symmetric matrix from upper triangular part
    result = zeros_like(a)
    let N = a.shape[0]

    for i in countup(0, N-1):
        for j in countup(i, N-1):
            result[i, j] = a[i, j]
            if i != j:
                result[j, i] = a[i, j]