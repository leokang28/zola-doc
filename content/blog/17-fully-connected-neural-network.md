+++
date = 2026-09-16T23:30:00+08:00
description = "把前几篇手写的神经元代码收拢成一个通用库，用一个数组描述网络结构"
draft = false
title = "全连接神经网络的通用实现"

[extra]
keywords = "machine learning, neural network, c"
series = "Machine Learning"
toc = true
display_published = true

[taxonomies]
tags = [
    "Machine Learning",
    "AI",
    "Notes",
]
+++

# 从专用代码到通用库：全连接神经网络的抽象

## 1. 手写代码的天花板

回顾一下前几篇走的路：

- 拟合直线时，模型只有两个参数 `w` 和 `b`，手写求梯度毫无压力。
- 训练逻辑门时，单个神经元有三个参数，也还好。
- 到了 XOR，网络有九个参数，`finite_diff` 里开始出现大量重复代码：每个参数都要写一遍"加上 eps、算 cost、恢复"。

上一篇我们又从数学上证明了：不管网络有多少层、每层有多少神经元，前向传播都是同一个公式：

```text
z^[l] = W^[l] * a^[l-1] + b^[l]
a^[l] = σ(z^[l])
```

数学上已经统一了，代码却还是专用的：`Xor` 结构体里写死了九个参数名，换一个网络结构就得重写一份。

这篇要做的事情，就是**让代码也追赶上数学**：写一份通用的网络实现，网络的形状不再写死在结构体里，而是用一个数组描述。比如 `{2, 4, 1}` 就表示"输入 2 个节点，隐藏层 4 个神经元，输出 1 个神经元"。想换结构？改数组就行，库代码一行不动。

## 2. 先抽象矩阵

上一篇说过，矩阵运算是神经网络的通用语言。所以第一步是给 C 语言补上一个矩阵结构：

```c
typedef struct {
    size_t rows;
    size_t cols;
    size_t stride;
    float* p;
} Matrix;

#define MATRIX_AT(m, i, j) (m).p[(i)*(m).stride + (j)]
```

矩阵的数据存在一块连续的一维数组 `p` 里，第 `i` 行第 `j` 列的元素通过 `p[i * stride + j]` 访问。

### stride 是干什么的？

`stride` 表示"每行在内存里占多少个位置"。大多数情况下 `stride == cols`，但它也可以比 `cols` 大。这个小小的设计带来一个很大的便利：**一个矩阵可以是另一块内存的"视图"，而不必复制数据**。

后面训练数据会用到这个技巧，先记住它。

基于这个结构，可以实现一组基础操作：

```c
void mat_dot(Matrix dst, Matrix a, Matrix b);  // 矩阵乘法
void mat_add(Matrix dst, Matrix a);            // 矩阵加法
void mat_sig(Matrix m);                        // 每个元素过一遍 sigmoid
void mat_copy(Matrix dst, Matrix src);         // 复制
Matrix mat_row(Matrix m, size_t row);          // 取出某一行，作为新矩阵
```

其中 `mat_row` 很有意思：它返回的矩阵不拥有自己的数据，只是指向原矩阵某一行的开头。相当于给原矩阵开了一扇"窗户"，通过窗户读写，动的还是原来的数据。

```c
Matrix mat_row(Matrix m, size_t row) {
    return (Matrix){
        .rows = 1,
        .cols = m.cols,
        .stride = m.cols,
        .p = &MATRIX_AT(m, row, 0),
    };
}
```

## 3. 网络结构体：三个数组

一个全连接网络需要存什么？对照上一篇的公式数一下：

- 每层一个权重矩阵 `W^[l]`
- 每层一个偏置向量 `b^[l]`
- 每层的输出 `a^[l]`（计算下一层时要用）

所以网络结构体就是三个数组：

```c
typedef struct {
    size_t count;        // 层数（不含输入层）
    Matrix* weights;     // 每层的权重矩阵
    Matrix* biases;      // 每层的偏置
    Matrix* activations; // 每层的输出，额外多存了最初的输入
} KNN;
```

注意 `activations` 比另外两个数组多一个元素：`activations[0]` 存的是网络最初的输入 `x`，`activations[count]` 就是最终输出。代码里用两个宏把这两头取出来：

```c
#define KNN_INPUT(n)  (n).activations[0]
#define KNN_OUTPUT(n) (n).activations[n.count]
```

### 按形状分配内存

网络有几层、每层几个神经元，全由一个数组决定：

```c
KNN knn_alloc(size_t *arch, size_t total_count) {
    KNN n;
    n.count = total_count - 1;

    n.weights = _KNN_MALLOC_(sizeof(*n.weights) * n.count);
    n.biases = _KNN_MALLOC_(sizeof(*n.biases) * n.count);
    n.activations = _KNN_MALLOC_(sizeof(*n.activations) * (n.count + 1));

    KNN_INPUT(n) = malloc_matrix(1, arch[0]);
    for(size_t i = 1; i < total_count; i += 1) {
        n.weights[i - 1] = malloc_matrix(n.activations[i - 1].cols, arch[i]);
        n.biases[i - 1] = malloc_matrix(1, arch[i]);
        n.activations[i] = malloc_matrix(1, arch[i]);
    }

    return n;
}
```

对照上一篇"权重矩阵是 `n_out × n_in`"的结论，这里代码把矩阵写成了 `1 × n` 的行向量形式，所以权重矩阵的行数是上一层的宽度、列数是当前层的宽度。形状全由 `arch` 推导出来，写网络的人不用操心维度对不对——维度不对的话，矩阵运算里的断言会直接报错。

对比一下：之前训练 XOR 要专门定义一个九个字段的 `Xor` 结构体；现在 `knn_alloc` 加上 `{2, 2, 1}` 这个数组就够了，换成 `{2, 4, 1}`、`{784, 256, 128, 10}` 也同样是一行的事。

## 4. 前向传播：三行代码

上一篇推导的通用公式，翻译成代码就是三行：

```c
void knn_forward(KNN n) {
    for (size_t i = 0; i < n.count; i += 1) {
        mat_dot(n.activations[i + 1], n.activations[i], n.weights[i]);
        mat_add(n.activations[i + 1], n.biases[i]);
        mat_sig(n.activations[i + 1]);
    }
}
```

每一层做三件事：矩阵乘法、加偏置、过 sigmoid。结果直接写进 `activations[i + 1]`，作为下一层的输入。循环跑完，输出就躺在 `KNN_OUTPUT(n)` 里。

这几行代码完全不知道网络是两层还是二十层，这就是矩阵抽象换来的通用性。

## 5. 训练：cost、梯度、更新

训练的骨架和前面几篇一模一样，只是每个环节都从"手写"变成了"循环"。

### cost：遍历训练集

```c
float knn_cost(KNN n, Matrix ti, Matrix to) {
    float cost = 0.f;
    for(size_t i = 0; i < ti.rows; i += 1) {
        Matrix x = mat_row(ti, i);
        Matrix y = mat_row(to, i);
        mat_copy(KNN_INPUT(n), x);
        knn_forward(n);
        for(size_t j = 0; j < to.cols; j++) {
            float d = MATRIX_AT(KNN_OUTPUT(n), 0, j) - MATRIX_AT(y, 0, j);
            cost += d * d;
        }
    }
    return cost / ti.rows;
}
```

`ti` 是输入矩阵（每行一个样本），`to` 是期望输出矩阵。逐行取出样本喂给网络，把预测值和期望值的差平方累加起来，最后取平均——就是之前一直在用的均方误差。

这里用到了 `mat_row` 的"窗户"特性：样本是直接看进训练数据里的，没有复制。

### stride 的实际用处

XOR 的训练数据长这样，每一行是 `x1, x2, y` 三个数挤在一起：

```c
float data[] = {
    0, 0, 0,
    0, 1, 1,
    1, 0, 1,
    1, 1, 0
};
```

输入和输出混在同一块内存里，怎么分开？靠 `stride`：

```c
Matrix ti = {
    .rows = rows,
    .cols = 2,
    .stride = 3,     // 每行跨 3 个数，但只看前 2 个
    .p = data,
};
Matrix to = {
    .rows = rows,
    .cols = 1,
    .stride = 3,     // 每行跨 3 个数，只看第 3 个
    .p = data + 2,
};
```

`ti` 从 `data` 开头看，每行读 2 个数、跳过 3 个数；`to` 从 `data + 2` 开头看，每行读 1 个数。同一块内存，两扇不同的窗户，输入输出就分开了，一个拷贝都不需要。

### 梯度：通用的有限差分

之前给 XOR 求梯度，九个参数要手写九遍"加 eps、算 cost、恢复"。现在参数都在矩阵里，三层循环搞定：

```c
void knn_finite_diff(KNN n, KNN g, float eps, Matrix ti, Matrix to) {
    float saved;
    for (size_t i = 0; i < n.count; i += 1) {
        float c = knn_cost(n, ti, to);
        for (size_t j = 0; j < n.weights[i].rows; j += 1) {
            for(size_t k = 0; k < n.weights[i].cols; k += 1) {
                saved = MATRIX_AT(n.weights[i], j, k);
                MATRIX_AT(n.weights[i], j, k) += eps;
                MATRIX_AT(g.weights[i], j, k) = (knn_cost(n, ti, to) - c) / eps;
                MATRIX_AT(n.weights[i], j, k) = saved;
            }
        }
        // 偏置同理，循环一遍 n.biases[i]
        // ...
    }
}
```

`g` 是一个和 `n` 形状相同的网络，但不拿来预测，只用来装梯度——每个参数的梯度存在 `g` 对应的位置上。思路没变：把某个参数稍微抬一下，看 cost 涨了多少，涨得越快说明这个参数越"敏感"。

### 更新：沿着梯度反方向走一步

```c
void knn_learn(KNN n, KNN g, float rate) {
    for(size_t i = 0; i < n.count; i += 1) {
        // 权重和偏置都做同一件事：
        MATRIX_AT(n.weights[i], j, k) -= rate * MATRIX_AT(g.weights[i], j, k);
        // ...
    }
}
```

还是那句老话：梯度指向 cost 增长最快的方向，所以反着走。

## 6. 单头文件：一个小约定

这份库只有一个 `knn.h`，实现也写在同一个文件里，用宏开关隔开：

```c
#ifdef __KNN_IMPLEMENTATION__
// 所有函数的实现
#endif
```

使用的时候，在**一个** `.c` 文件里先定义宏再包含：

```c
#define __KNN_IMPLEMENTATION__
#include "knn.h"
```

其他地方正常 `#include "knn.h"` 就只拿到声明。这样在 C 这种没有包管理器的语言里，库就是一个文件，拷走即用。

文件开头还有两个可以覆盖的宏：`_KNN_MALLOC_` 和 `_KNN_ASSERT_`。默认分别是 `malloc` 和 `assert`，但使用方可以在包含之前定义成自己的版本，比如换成自己的内存分配器。不改库代码，就能改库的行为。

## 7. 跑起来：还是那个 XOR

把上面所有零件拼起来，训练 XOR 的完整程序短得出乎意料：

```c
int main(){
    srand(time(0));

    size_t arch[] = {2, 4, 1};          // 网络形状：2 输入，4 隐藏，1 输出
    KNN n = knn_alloc(arch, ARR_LEN(arch));
    KNN g = knn_alloc(arch, ARR_LEN(arch));
    knn_rand(n);

    // ti、to 用 stride 从 data 里开窗，见上文
    // ...

    float eps = 1e-1;
    float rate = 1e-1;
    for(size_t i = 0; i < 100*1000; i += 1) {
        knn_finite_diff(n, g, eps, ti, to);
        knn_learn(n, g, rate);
    }

    verify(n);
    return 0;
}
```

注意这里隐藏层用了 4 个神经元，比之前手写的 2 个还多——但代码反而更短了。这就是通用抽象的意义：**网络变复杂，代码不变复杂**。

训练结果：

```text
0 ^ 0 = 0.018523
0 ^ 1 = 0.982424
1 ^ 0 = 0.982253
1 ^ 1 = 0.016884
```

XOR 再次被学会，这次用的是一份和具体问题完全无关的通用代码。

## 8. 总结

这篇做了一次"代码追赶数学"的重构：

1. **矩阵结构体**：一块连续内存加上 `rows`、`cols`、`stride`，配上 `mat_row` 这种"开窗户"的视图操作，零拷贝地切分训练数据。
2. **网络结构体**：权重、偏置、激活值各一个数组，网络形状由 `arch` 数组描述，改结构不用改代码。
3. **通用训练循环**：前向传播、cost、有限差分求梯度、梯度下降，全部对任意层数、任意宽度成立。

训练的核心思想从第一篇到现在一个字都没变过：

> **定义模型，计算误差，求梯度，沿着梯度反方向调整参数。**

变化的只是我们表达模型的方式：从两个浮点数，到九个字段的结构体，再到三个数组加一个形状描述。

还有一个明显的遗留问题：有限差分求梯度，每算一个参数的梯度都要完整跑一遍 cost。XOR 只有十几个参数，跑得动；上一篇算过，一个像样点的网络有二十多万个参数，这个方法就完全不可行了。下一篇该轮到反向传播登场——用链式法则一次前向、一次反向就拿到所有参数的梯度，这也是上一篇结尾提到的矩阵形式反向传播该落地的时候了。
