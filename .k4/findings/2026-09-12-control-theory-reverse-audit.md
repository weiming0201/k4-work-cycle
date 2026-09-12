# resource-036 五 Skill 控制论反向审计

> 状态：Observe Finding；未选择修复，未修改 Skill、合同、Tool、测试或发布面。

## 1. 对象与边界

- 对象：`resource-036` 当前工作树声明的 `0.9.0` 五个 Skill。
- Git 基线：`main` / `74e8cec15a07b238f52a18f1c069f136045920e4`。
- Manifest SHA-256：`95f9633a85be90ebbc3c4cc2101d6663a7bc4f96c9401797a12cfb4a1dea445c`。
- Skill SHA-256：
  - Observe：`29d438b97d0318c05bb23553136905ec2d3753d96ea39a433caba020145b5b3b`；
  - Goal：`d671fe434cd476fa643559705a78c68230c4c538b8c6918c5f6d00e4340d1c75`；
  - Plan：`7bad57aad6786856dcef402453c5c356e98ea5e309dc2188be98a8c422f4ed16`；
  - Run：`524009a7c3a79181edddd3d497c08b7a32ee392cea68361421e306253677ef64`；
  - Finish：`a314955d2111e1494be9c669fdb16e373bc7886483f9896cdea924cb7bceeaf4`。
- 比较对象：`K4-FORMAL-AUDIT-THEORY-REVISION-R2` Candidate 的定义 26—28、62—74、79。
- 本报告只判断职责边界；不判断五个 Skill 的总体质量，不取得修改或发布权限。

## 2. 控制论校准来源

1. Åström 与 Murray，《Feedback Systems》：区分系统模型、动态行为、状态反馈、可达性、可观测性、状态估计、输出反馈和鲁棒性。  
   <https://authors.library.caltech.edu/records/yzs24-xsx88>
2. Luenberger，`Observers for multivariable systems`：observer 根据系统已有输入和输出重建不可直接测量的状态；observer 不是验收器，也不是被控对象。  
   <https://doi.org/10.1109/TAC.1966.1098323>
3. Kalman，`A New Approach to Linear Filtering and Prediction Problems`：估计值由实际可观察随机变量驱动；估计与真实状态必须区分。  
   <https://doi.org/10.1115/1.3662552>
4. Conant 与 Ashby，`Every Good Regulator of a System Must Be a Model of That System`：在论文明确假设内，最简单的最优调节器必须形成与受调节对象相应的模型；该结论不能无条件外推为模型等于对象。  
   <https://doi.org/10.1080/00207727008920220>
5. Mayne、Rawlings、Rao 与 Scokaert，`Constrained model predictive control: Stability and optimality`：当前状态、有限时域求解、硬约束、实际施加的控制量与后续重新求解彼此可区分。  
   <https://doi.org/10.1016/S0005-1098(99)00214-9>

## 3. 五 Skill 对读

| Skill | 控制论中的最近职责 | 当前判断 | Finding |
| --- | --- | --- | --- |
| Observe | 轮次间的监督级状态建模与证据融合 | 有界对齐 | 没有确认的 Skill 内冲突。它形成 Account 而不选择控制目标；但 Account 只能称有来源模型，不能称真实状态或已证明可观测状态。 |
| Goal | 参考目标、约束和一次控制授权 | 存在冲突 | `R36-F01`：无条件单一 `primary_facet` 超过理论中单面七位规则的适用范围。 |
| Plan | 有限时域的监督策略或工作策略 | 有界对齐 | 当前有限 DAG 可以作为一次有限策略，但不是一般连续控制器。新的状态模型或图外反馈只能停止并开启新轮，不能在 Run 内重规划。 |
| Run | 策略、受控 Resource、局部测量与实际反馈形成的轨迹账簿 | 存在冲突 | `R36-F02`：全局 emergency patch 允许冻结策略之外的动作。 |
| Finish | 终端比较、影响归因和静态状态结算 | 一项冲突、一项缺口 | `R36-F03`：静态更新的外部证据来源边界未机械闭合；`R36-F04`：带副作用 closure action 发生在 Run halt 后，却未进入 Run 历史。 |

这里的映射只是职责校准。受控对象是 Resource 或外部系统，不是 Run；Run 是实际交互与历史。Observe 也不是 Run 内部的传感器：Run 的局部判断和控制观测才承担内环反馈，Observe 负责轮次外的新证据和模型更新。

## 4. Findings

### R36-F01：Goal 把条件性单主面扩大成无条件单主面

- 状态：`conflict`。
- 位置：`skills/k4-goal/SKILL.md`、`assets/protocol.cue` 的 `change_surface.primary_facet`。
- 观察：Goal v7 要求每个 Goal 恰有一个 `primary_facet`。
- Baseline：理论定义 65 只在五项条件同时成立时，才把一个静态面当作唯一直接控制变量；一般 Goal 允许多位置共同变化或整体替换。
- 反例：一个确实需要两个静态面共同改变、且不能诚实拆成一主一副的 Goal，必须虚构一个主面才能通过 Goal v7。
- 最大结论：当前 Goal 合同不能无损表达理论允许的全部一般 Goal；不证明单主面设计对当前产品无用。

### R36-F02：Run 的 emergency patch 位于 Plan 的冻结控制策略之外

- 状态：`conflict`。
- 位置：`skills/k4-run/SKILL.md`、`assets/protocol.cue` 的 emergency patch。
- 观察：Run v7 可以在一个正常操作前执行一次未列入 Plan DAG 的 patch，再回到原操作。
- Baseline：理论定义 68 要求所有可执行路线属于冻结 Plan；图中没有的事实只能停止、失败或保留未知，新增节点或边形成另一 Plan。
- 反例：Plan 没有写入一个修补动作，Run 却实际执行该动作并继续同一冻结 Plan。
- 最大结论：Plan 不是完整的实际控制策略。若保留 patch，至少需要由 Plan 预先冻结 patch 类、触发条件和返回接缝；本报告不选择修法。

### R36-F03：Finish 的 Account 写入尚未机械排除无关外部新证据

- 状态：`gap / unknown`。
- 位置：`skills/k4-finish/assets/protocol.cue` 的 Account updates、additions 与 evidence refs。
- 观察：合同会机械闭合 Account sources，但调用者仍可为新增或更新条目提供任意字符串 evidence ref。
- Baseline：Finish 只能结算 opening Account、本轮 Run 与获准收束所产生的内生证据；Run 之后新出现且与本轮效果无关的外部证据应由后来 Observe 接收。
- 可证伪条件：若现有 Tool 能证明每个 changed Account item 的证据均来自 opening Account、Run 或本轮授权 closure evidence，本 Finding 关闭。
- 最大结论：目前只确认负向来源约束没有在已读合同中显式闭合，不宣称已经发生错误写入。

### R36-F04：带副作用的 Finish closure action 使 Run 不再是完整实际轨迹

- 状态：`conflict`。
- 位置：`WORKFLOW.md` 与 `skills/k4-finish/SKILL.md` 的 cleanup、release、rollback、compensation、packaging。
- 观察：Run 已经 halt 后，Finish 仍可执行可能改变 Resource 或环境状态的 closure action；这些效果进入 completion report，但不追加到 Run ledger。
- Baseline：实际控制轨迹必须包含所有改变受控对象状态的控制输入和副作用；终端比较器不能同时静默充当执行器。
- 反例：Finish 执行 rollback 改变 Resource，closing Account 记录回滚后状态，但 Run 历史止于回滚前。
- 最大结论：必须二选一：把所有有副作用 closure action 作为 Run 的冻结终止路线记录，或者把 Run 的“唯一完整过程历史”主张收窄并另设收束动作历史。本报告不选择修法。

## 5. 非 Finding 的边界说明

1. Observe 与 Finish 都写 Account 并不自动重复：Observe 接收轮次外证据，Finish 只结算本轮内生效果时，两者职责可分。
2. Plan 的有限 DAG 不需要冒充连续控制器。它可以明确限定为一次有界工作的监督策略。
3. Account 的 16 位静态结构不自动证明控制论的 observability；动态四基覆盖也不自动证明某个 Goal 从当前 Account 可达。
4. 五阶段完整走完不证明闭环稳定、收敛或鲁棒；这些结论需要另行定义误差、扰动、时域和稳定性判准。

## 6. 处置

- `R36-F01`—`R36-F04` 全部保留在本 Resource 的 `.k4/findings`，不进入当前理论修订 Goal。
- 本轮不修改任何 Skill、CUE、Tool、测试、Manifest、README、WORKFLOW、DESIGN 或 MIGRATION。
- 后续只有新的 Goal 明确选择某一 Finding 时，才能形成对应 Candidate。
