+++
date = 2026-09-28T22:00:00+08:00
description = "用链式法则把梯度从输出层逐层传回输入层，一次前向加一次反向就拿到所有参数的梯度"
draft = false
title = "反向传播"

[extra]
keywords = "machine learning, backpropagation, chain rule, gradient"
series = "Machine Learning"
toc = true
display_published = true
katex = true

[taxonomies]
tags = [
    "Machine Learning",
    "AI",
    "Notes",
]
+++

# 反向传播：用链式法则高效求梯度

## 1. 有限差分太慢

上一篇结尾算过：有限差分求**一个**参数的梯度，要把整个训练集完整跑一遍。XOR 的十几个参数还能接受，但一个像样点的网络有二十多万个参数，每轮迭代就要跑二十多万次完整的前向传播，实际上不可行。

梯度还是那个梯度（每个参数"我动一下 cost 怎么变"），问题只在于**怎么更快地算出来**。

反向传播就是解决这个问题的。它的数学基础只有一个——链式法则。这篇把它从头推一遍：它没有引入新的思想，只是把上一篇的梯度概念，用链式法则换了一种高效的算法。

## 2. 链式法则：cost 是怎么"传"回来的

先回忆前向传播在做什么。对第 $l$ 层第 $j$ 个神经元：

{% <math> %}
z_j^{(l)} = \sum_k a_k^{(l-1)} \cdot w_{kj}^{(l)} + b_j^{(l)}, \qquad a_j^{(l)} = \sigma(z_j^{(l)})
{% </math> %}

上一层的输出乘权重、加偏置、过 sigmoid，得到这一层的输出，一层层接力到最终的 $a^{(L)}$，然后和期望输出 $y$ 比较得到 cost：

{% <math> %}
C = \sum_j \left( a_j^{(L)} - y_j \right)^2
{% </math> %}

现在问：某个权重 $w_{kj}$ 对 cost 的影响有多大（即 $\frac{\partial C}{\partial w_{kj}}$）？

注意 $w_{kj}$ 并不直接出现在 cost 的公式里，它是通过一条**依赖链**间接影响 cost 的：

{% <math> %}
w_{kj} \;\longrightarrow\; z_j \;\longrightarrow\; a_j \;\longrightarrow\; \cdots \;\longrightarrow\; a^{(L)} \;\longrightarrow\; C
{% </math> %}

链式法则说的就是：沿着这条链，把每一环的"变化率"挨个乘起来，就是总的变化率。反向传播就是把这条乘法链从 cost 那一端往回乘。

## 3. 输出层：链式法则的直接应用

先从最简单的输出层开始。依赖链很短：

{% <math> %}
w_{kj} \;\longrightarrow\; z_j \;\longrightarrow\; a_j \;\longrightarrow\; C
{% </math> %}

逐环求导再相乘：

{% <math> %}
\frac{\partial C}{\partial w_{kj}} \;=\; \frac{\partial C}{\partial a_j} \cdot \frac{\partial a_j}{\partial z_j} \cdot \frac{\partial z_j}{\partial w_{kj}}
{% </math> %}

三环分别算：

- $\frac{\partial C}{\partial a_j} = 2(a_j - y_j)$：cost 是误差平方，平方的导数带一个系数 2。请记住这个 2，它后面还会出场。
- $\frac{\partial a_j}{\partial z_j} = \sigma'(z_j)$：sigmoid 的导数有个特别好用的性质（下一节细说），可以用激活值自己表示。
- $\frac{\partial z_j}{\partial w_{kj}} = a_k^{(l-1)}$：$z_j$ 是上一层的加权和，对某个权重求导，剩下的就是和它配对那个输入。

把前两环合并，起个名字，叫**输出层的误差项**：

{% <math> %}
\delta_j^{(L)} = 2\,(a_j - y_j) \cdot a_j(1 - a_j)
{% </math> %}

于是输出层的参数梯度非常简洁：

{% <math> %}
\frac{\partial C}{\partial w_{kj}^{(L)}} = \delta_j^{(L)} \cdot a_k^{(L-1)}, \qquad \frac{\partial C}{\partial b_j^{(L)}} = \delta_j^{(L)}
{% </math> %}

bias 那行更短，是因为 $z_j$ 对 $b_j$ 的导数是 1（$z_j = \cdots + b_j$），所以 bias 的梯度就是误差项本身。权重梯度则要多乘一个"和这个权重配对的输入"。直觉上也合理：输入越大，这条连接对结果的贡献越大，它的权重对误差的责任也越大。

## 4. 两个容易写错的细节

在往下推之前，先把两个最容易写错的细节说清楚——这个系列的实现在写反向传播时，先后踩中了这两个坑，症状都是梯度算出来和有限差分对不上。

**第一，sigmoid 的导数是 $a(1-a)$，不是 $a(a-1)$。**

推导一下（不复杂，值得看一眼）：

{% <math> %}
\sigma'(z) = \frac{d}{dz}\,\frac{1}{1+e^{-z}} = \frac{e^{-z}}{(1+e^{-z})^2} = \frac{1}{1+e^{-z}} \cdot \frac{e^{-z}}{1+e^{-z}} = \sigma(z)\,\bigl(1 - \sigma(z)\bigr)
{% </math> %}

$a(1-a)$ 永远非负，而 $a(a-1)$ 永远非正，两者差一个负号。写反之后梯度方向整个反过来：该增大的参数在减小，该减小的在增大。更麻烦的情况是 bias 那行写对、权重那行写反——同一个网络里两批参数朝相反方向更新，训练看起来既像收敛又像不收敛，很难排查。

**第二，系数 2 只属于输出层，出现且只出现一次。**

那个 2 来自 $(a-y)^2$ 对 $a$ 求导，发生在链式乘法的最末端（离 cost 最近的那一环）。一旦误差项 $\delta$ 定义好了，往后的回传只是"乘权重、求和、乘 sigmoid 导数"，每一步都不会再冒出新的 2。

如果把 2 写进了每层的递推公式里，每往上传一层，梯度就无故翻一倍——三层网络里输入层的梯度被放大 4 倍，层数越深放大越夸张。这就是第二个真实的坑。

## 5. 隐藏层：误差为什么要"求和"回传

输出层搞定了，往倒数第二层走。这里出现一个本质的新情况，值得停下来看清楚。

输出层的 $a_j$ 只影响 cost 一项。但隐藏层的激活值 $a_m^{(L-1)}$ **会同时喂给下一层的每一个神经元**——它通过所有下游路径共同影响 cost：

{% <math> %}
w_{km}^{(L-1)} \;\longrightarrow\; z_m^{(L-1)} \;\longrightarrow\; a_m^{(L-1)} \;\longrightarrow\; \bigl\{\, z_1^{(L)},\; z_2^{(L)},\; \ldots \,\bigr\} \;\longrightarrow\; C
{% </math> %}

多元函数的链式法则要求：**把所有路径的贡献加起来**。于是 $a_m$ 对 cost 的影响是：

{% <math> %}
\frac{\partial C}{\partial a_m^{(L-1)}} = \sum_j \frac{\partial C}{\partial z_j^{(L)}} \cdot \frac{\partial z_j^{(L)}}{\partial a_m^{(L-1)}} = \sum_j \delta_j^{(L)} \cdot w_{mj}^{(L)}
{% </math> %}

看右边这个求和：下一层每个神经元 $j$ 都贡献一份 $\delta_j \cdot w_{mj}$——误差项乘上连接两者的权重。权重大的连接，说明 $a_m$ 对那个下游神经元影响大，分摊到的责任也多。误差按权重比例分摊回上一层，这就是"传播"二字的具体含义。

拿到 $\frac{\partial C}{\partial a_m}$ 之后，剩下的步骤和输出层一模一样：乘 sigmoid 导数得到这一层的误差项：

{% <math> %}
\delta_m^{(L-1)} = \Bigl( \sum_j \delta_j^{(L)} \, w_{mj}^{(L)} \Bigr) \cdot a_m^{(L-1)}\bigl(1 - a_m^{(L-1)}\bigr)
{% </math> %}

对比输出层的 $\delta$ 定义，形式完全同构，唯一的区别是 $2(a-y)$ 换成了"从下一层汇总回来的误差"。

## 6. 通用递推式：整个算法就三条公式

把上面两节推广到任意层。定义每层的误差项 $\delta^{(l)} = \frac{\partial C}{\partial z^{(l)}}$，反向传播的全部内容就是：

{% <math> %}
\delta_j^{(L)} = 2\,(a_j - y_j) \cdot a_j(1-a_j) \qquad \text{① 输出层，播种}
{% </math> %}

{% <math> %}
\delta_k^{(l-1)} = \Bigl( \sum_j \delta_j^{(l)} \, w_{kj}^{(l)} \Bigr) \cdot a_k^{(l-1)}\bigl(1 - a_k^{(l-1)}\bigr) \qquad \text{② 逐层回传}
{% </math> %}

{% <math> %}
\frac{\partial C}{\partial w_{kj}^{(l)}} = \delta_j^{(l)} \, a_k^{(l-1)}, \qquad \frac{\partial C}{\partial b_j^{(l)}} = \delta_j^{(l)} \qquad \text{③ 换算成参数梯度}
{% </math> %}

①只做一次——这就是第 4 节强调的"系数 2 只出现一次"的位置。②是循环体：乘权重、按下游求和、乘 sigmoid 导数，注意这里面**没有 2**。③把误差项就地换成梯度。

为什么叫"反向"？看②的下标依赖：算 $\delta^{(l-1)}$ 需要 $\delta^{(l)}$ 先算好。离输出近的层先算，结果存下来给更靠前的层复用，一路退到输入层。这其实是一种动态规划：如果每个参数都像有限差分那样独立地从头算自己的链式乘法，大量中间结果会被重复计算；反向传播把公共部分缓存起来，整条网络一次前向、一次反向，所有参数的梯度全部到手。

上一篇说的"算两遍"，精确含义就在这里：**一遍前向算出所有 $a$，一遍反向算出所有 $\delta$ 和梯度**，计算量和两次前向传播相当，与参数个数无关。二十万参数也是两遍。

## 7. 一个具体数字走一遍

公式看懂了，再用数字验一遍手感。取一个最小的两层网络 $\{2, 2, 1\}$，输入 $x = (1, 0)$，期望输出 $y = 1$，参数随便定：

{% <math> %}
W^{(1)} = \begin{pmatrix} 0.1 & 0.2 \\ 0.3 & 0.4 \end{pmatrix}, \quad b^{(1)} = (0.05,\; -0.05), \quad W^{(2)} = \begin{pmatrix} 0.6 \\ -0.7 \end{pmatrix}, \quad b^{(2)} = 0.15
{% </math> %}

**前向**（逐层算 $z$ 和 $a$）：

{% <math> %}
z_1^{(1)} = 1{\times}0.1 + 0{\times}0.3 + 0.05 = 0.15 \;\Rightarrow\; a_1^{(1)} = \sigma(0.15) \approx 0.5374
{% </math> %}

{% <math> %}
z_2^{(1)} = 1{\times}0.2 + 0{\times}0.4 - 0.05 = 0.15 \;\Rightarrow\; a_2^{(1)} \approx 0.5374 \;\;(\text{恰好相同})
{% </math> %}

{% <math> %}
z^{(2)} \approx 0.5374{\times}0.6 + 0.5374{\times}(-0.7) + 0.15 \approx 0.0963 \;\Rightarrow\; a^{(2)} \approx 0.5240
{% </math> %}

输出 0.5240，离目标 1 还差得远。现在开始反向。

**第一步，输出层播种**（公式①）：

{% <math> %}
\delta^{(2)} = 2 \times (0.5240 - 1) \times 0.5240 \times (1 - 0.5240) \approx -0.9519 \times 0.2494 \approx -0.2374
{% </math> %}

**第二步，输出层的参数梯度**（公式③）：

{% <math> %}
\frac{\partial C}{\partial b^{(2)}} = \delta^{(2)} \approx -0.2374, \qquad \frac{\partial C}{\partial w_1^{(2)}} = \delta^{(2)} \cdot a_1^{(1)} \approx -0.2374 \times 0.5374 \approx -0.1276
{% </math> %}

顺手验证一下符号的合理性：输出 0.5240 偏小（目标是 1），而 $a_1^{(1)}$ 对输出是正贡献（权重 $0.6 > 0$），所以 $w_1^{(2)}$ 应该**调大**。梯度是 $-0.1276$，更新时是 $w \leftarrow w - \text{rate} \times \text{梯度}$，减负得正——确实在调大。✓

**第三步，误差回传到隐藏层**（公式②的求和部分）：

{% <math> %}
\frac{\partial C}{\partial a_1^{(1)}} = \delta^{(2)} \times 0.6 \approx -0.1424, \qquad \frac{\partial C}{\partial a_2^{(1)}} = \delta^{(2)} \times (-0.7) \approx +0.1662
{% </math> %}

**第四步，隐藏层的误差项和梯度**（乘 sigmoid 导数，再走公式③）：

{% <math> %}
\delta_1^{(1)} \approx -0.1424 \times 0.5374 \times 0.4626 \approx -0.0354, \qquad \delta_2^{(1)} \approx +0.1662 \times 0.2486 \approx +0.0413
{% </math> %}

{% <math> %}
\frac{\partial C}{\partial w_{11}^{(1)}} = \delta_1^{(1)} \cdot x_1 = -0.0354 \times 1 = -0.0354, \qquad \frac{\partial C}{\partial w_{21}^{(1)}} = \delta_1^{(1)} \cdot x_2 = 0
{% </math> %}

最后一行值得注意：输入 $x_2 = 0$，它参与的所有乘积都是 0，这条连接在本次前向中没有产生任何贡献，所以它的梯度是 0，本轮不会被更新。

## 8. 写成伪代码

把三条公式翻译成代码，结构就是"每个样本：播种 → 逐层回传"，外层再套一个遍历训练集的循环。沿用前几篇的约定：`n` 是参数网络，`g` 是形状相同、专门用来装梯度和误差的网络：

```text
function backprop(n, g, ti, to):
    zero(g)                                   # 梯度清零，准备跨样本累加
    for i in 0 .. sample_count:               # 遍历训练集
        x ← row(ti, i);  y ← row(to, i)
        copy(x → n.a[0]);  forward(n)         # 前向，填好所有 a^[l]

        zero(g.activations)                   # 误差是每样本独立的，先清掉上一样本

        # ① 播种：2(a - y) 写进输出层的误差槽
        for j in 0 .. output_width:
            g.a[L][j] ← 2 * (n.a[L][j] - y[j])

        # ②③ 逐层回传
        for l in L .. 1:                      # 从输出层退到第一层
            for j in 0 .. width(l):
                a  ← n.a[l][j]
                δ  ← g.a[l][j] * a * (1 - a)  # 补上 sigmoid 导数，得完整 δ_j^[l]

                g.b[l-1][j] += δ              # bias 梯度就是 δ 本身

                for k in 0 .. width(l-1):
                    g.w[l-1][k][j] += δ * n.a[l-1][k]   # 权重梯度 = δ × 配对输入
                    g.a[l-1][k]  += δ * n.w[l-1][k][j]  # 误差分摊回上一层

    # 所有样本累加完，取平均
    divide(g.weights, g.biases, by = sample_count)
```

几个和公式对应的点：

- `g.a[l][j]` 里存的是误差的"半成品" $\frac{\partial C}{\partial a_j}$，乘上 $a(1-a)$ 才是完整的 $\delta_j^{(l)}$。sigmoid 导数被推迟到使用处才乘，只是写法上的安排，数学上完全一样。
- 内层对 `k` 的循环用 `+=`，就是第 5 节那个"对所有下游路径求和"的代码形态——每条连接往 `g.a[l-1][k]` 里累加自己分摊到的那一份。
- `zero(g.activations)` 清零的是**误差槽**（每个样本都要重算），而 `g.weights`、`g.biases` 里的**梯度**只在最开头清一次，跨样本累加，最后除以样本数——这就是上一篇说的"所有参数在同一个位置量梯度"的批量版本。
- 逐层循环 `for l in L .. 1` 能保证：处理第 $l$ 层时，`g.a[l]` 一定已经被填好了——要么是播种填的（输出层），要么是上一层循环刚算出来的。误差总是在被用到的前一刻就位。

## 9. 和有限差分对答案

反向传播的公式是推出来的，怎么确定推得对、代码没写错？有一个现成的参照：**有限差分**。它慢，但逻辑简单到几乎不会错。

方法是对同一组参数、同一份数据，分别用两种方式算梯度，逐个参数比对。拿第 7 节那个 $\{2, 2, 1\}$ 网络试验：

| 参数 | 手工推导 | 反向传播 | 有限差分 |
|---|---|---|---|
| $\partial C \,/\, \partial b^{(2)}$ | −0.2374 | −0.2374 | −0.2373 |
| $\partial C \,/\, \partial w_1^{(2)}$ | −0.1276 | −0.1276 | −0.1276 |
| $\partial C \,/\, \partial b_1^{(1)}$ | −0.0354 | −0.0354 | −0.0354 |
| $\partial C \,/\, \partial b_2^{(1)}$ | +0.0413 | +0.0413 | +0.0413 |

三方一致（有限差分末位的微小出入是浮点精度问题，属正常现象）。第 4 节提到的那两个坑，当初就是这样定位的：符号写反时，输出层权重梯度和有限差分正好差一个负号；系数 2 多乘时，每往上一层结果就差 2 倍——对照表一摆，错误的位置和性质一目了然。

这也说明一件事：**验证数学代码，最有效的办法往往不是重读公式，而是用一个更慢但更简单的实现做参照**。

## 10. 总结

这篇把反向传播从头到尾推了一遍：

1. **动机**是效率：有限差分每个参数要跑一遍完整前向，反向传播利用链式法则，一次前向加一次反向拿到所有梯度，计算量与参数个数无关。
2. **核心机制**是误差项 $\delta$ 的逐层递推：输出层用 $2(a-y) \cdot a(1-a)$ 播种；往上传时，先按权重把下游误差求和分摊，再乘本层的 sigmoid 导数。
3. **参数梯度**从 $\delta$ 直接读出：bias 的梯度就是 $\delta$，权重的梯度是 $\delta$ 乘上配对的上层激活值。
4. **两个易错点**：sigmoid 导数是 $a(1-a)$ 而非 $a(a-1)$（符号）；系数 2 来自误差平方的求导，只在输出层播种时出现一次（递推里多乘会逐层翻倍）。
5. **验证方法**：用更慢但更简单的有限差分做参照，逐参数对照。

至此，求梯度从"每个参数各跑一遍前向"变成"整个网络跑两遍"，成本不再随参数个数增长。网络再宽、层数再多，这个方法都成立。

一句话概括：

> **梯度下降决定每个参数该怎么动，反向传播负责用链式法则把所有参数的梯度一次算出来。**
