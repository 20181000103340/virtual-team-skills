# Virtual Team Skill 设计文档

日期：2026-03-15
状态：Final（合并 review 意见后终版）

---

## 1. 概述

`/virtual-team` 是一个多 agent 协作 skill，模拟完整的软件开发团队。输入一份结构化需求文档，自动完成从架构设计到测试交付的全流程。

### 1.1 核心特性

- **8 个角色**：项目管理员（PM/Orchestrator）+ 7 个子 agent（总架构师、前端架构师、后端架构师、前端开发、后端开发、前端测试、后端测试）
- **B+C 混合架构**：阶段间串行（流水线）、阶段内并行（多 agent 并发）
- **3 个正式会议**：项目启动会、架构评审会、项目评审会
- **Gate 门禁机制**：每个阶段有明确的入口/出口条件，PM 逐项检查，关键 Gate 含执行验证
- **定向修复**：Gate 不通过时只重跑出问题的角色，不全部重来
- **跨平台**：同时支持 Claude Code 和 OpenAI Codex CLI
- **可交互模式**：`--interactive` 在关键节点暂停等待用户确认
- **幂等/可恢复**：支持 `--resume` 断点续跑，已通过的 Gate 默认跳过
- **安全边界**：命令 allowlist、超时限制、文件 ownership、默认不 commit/push

### 1.2 PM 角色定位

PM 不作为子 agent 运行。在两端都是 **orchestrator 本身**：
- **Claude Code**：PM 就是 `SKILL.md` 的执行逻辑
- **Codex CLI**：PM 就是外层 `codex` 调用

PM 负责：阶段调度、Gate 检查、子 agent prompt 构造与启动、产物汇总、修复循环管理。

### 1.3 默认自动化边界

以下操作**默认禁止**，除非需求文档明确授权或 `--interactive` 下用户确认：

- `git commit` / `git push`
- 修改 CI/CD 配置
- 修改 package-lock.json / yarn.lock / pnpm-lock.yaml
- 删除文件
- 发布/部署
- 执行需求文档未列出的命令

### 1.4 调用方式

```bash
# Claude Code
/virtual-team path/to/requirement.md

# Claude Code（交互模式，关键节点暂停）
/virtual-team path/to/requirement.md --interactive

# Claude Code（从上次中断处继续）
/virtual-team path/to/requirement.md --resume

# Claude Code（强制从头重跑，忽略已通过的 Gate）
/virtual-team path/to/requirement.md --force

# Codex CLI
codex "按照 .codex/skills/virtual-team/SKILL.md 执行，需求文档: path/to/requirement.md"
```

### 1.5 跨平台能力降级

| 能力 | Claude Code | Codex CLI | 降级行为 |
|------|------------|-----------|---------|
| 交互暂停 | AskUserQuestion | 无等价物 | 写 `.team/pause-required.md` 后正常退出，用户确认后 `--resume` 继续 |
| 进度追踪 | TodoWrite + status.json | status.json only | Codex 仅依赖 status.json |
| Agent 启动 | Agent tool with prompt | 自动调度 `[agents.*]` | 各自平台原生机制 |

---

## 2. 目录结构

```
virtual-team/
├── README.md                             # 安装/运行/安全限制说明
├── SKILL.md                              # Claude Code 入口（PM orchestrator）
├── codex/
│   ├── config.toml                       # Codex 角色配置（7 个子角色，PM 由外层调用承担）
│   └── agents/                           # Codex 角色 config 层
│       ├── chief-architect.toml
│       ├── frontend-architect.toml
│       ├── backend-architect.toml
│       ├── frontend-developer.toml
│       ├── backend-developer.toml
│       ├── frontend-tester.toml
│       └── backend-tester.toml
├── roles/                                # 角色 system prompt（两端共用）
│   ├── _common.md                        # 所有角色共享的行为规范 + 安全规则
│   ├── project-manager.md
│   ├── chief-architect.md
│   ├── frontend-architect.md
│   ├── backend-architect.md
│   ├── frontend-developer.md
│   ├── backend-developer.md
│   ├── frontend-tester.md
│   └── backend-tester.md
├── protocols/                            # 阶段协议与产物模板
│   ├── requirement-template.md
│   ├── kickoff-protocol.md
│   ├── architecture-protocol.md
│   ├── architecture-review-protocol.md
│   ├── task-breakdown-protocol.md
│   ├── implementation-protocol.md
│   ├── testing-protocol.md
│   ├── project-review-protocol.md
│   └── delivery-protocol.md
└── templates/                            # 产出物格式模板
    ├── project-brief.md
    ├── assignment.md
    ├── gates.md
    ├── role-brief.md
    ├── architecture.md
    ├── review-report.md
    ├── task-list.md
    ├── interface-contract.md
    ├── implementation-report.md
    ├── test-report.md
    ├── defect-list.md
    ├── blocked-report.md
    └── final-report.md
```

---

## 3. 运行时工作目录

skill 执行期间在项目根目录创建 `.team/`，使用 `.team/.gitignore` 自我忽略（内容为 `*`），**不修改仓库根 `.gitignore`**。

```
.team/
├── .gitignore                            # 内容: *（自我忽略）
├── project-brief.md                      # Phase 0 产出
├── kickoff/                              # Phase 1 项目启动会产出
│   ├── assignment.md                     # 任务分派表
│   ├── gates.md                          # Gate 门禁定义
│   ├── brief-chief-architect.md
│   ├── brief-frontend-architect.md
│   ├── brief-backend-architect.md
│   ├── brief-frontend-developer.md
│   ├── brief-backend-developer.md
│   ├── brief-frontend-tester.md
│   └── brief-backend-tester.md
├── arch/                                 # Phase 2
│   ├── chief.md
│   ├── frontend.md
│   └── backend.md
├── review/                               # 评审产出
│   ├── arch-review-by-chief.md
│   ├── arch-review-by-frontend.md
│   ├── arch-review-by-backend.md
│   ├── arch-review-summary.md
│   ├── project-review-by-chief.md
│   ├── project-review-by-frontend-tester.md
│   ├── project-review-by-backend-tester.md
│   └── project-review-summary.md
├── tasks/                                # Phase 4
│   ├── frontend.md
│   ├── backend.md
│   └── interface-contract.md
├── impl/                                 # Phase 5
│   ├── frontend.md
│   └── backend.md
├── test/                                 # Phase 6
│   ├── frontend.md
│   └── backend.md
├── status.json                           # PM 进度追踪
├── pause-required.md                     # Codex 降级暂停文件（按需生成）
├── blocked-report.md                     # 最大重试超限时的阻塞报告（按需生成）
└── final-report.md                       # Phase 8 交付报告
```

### 3.1 写入策略

- **覆盖写**：每个阶段的产出物是全量替换（重跑时覆盖上一轮）
- **冻结点**：`interface-contract.md` 在 Phase 4 生成后冻结，Phase 5/6 只读
- **幂等保证**：`status.json` 记录 `inputsHash`，需求未变时已通过的 Gate 默认跳过

---

## 4. 需求文档模板

```markdown
# 项目需求

## 基本信息
- 项目名称: {name}
- 项目路径: {path}                        # 支持相对路径，Phase 0 规范化
- 语言/框架: {e.g. TypeScript / React / Vite}
- 测试框架: {e.g. vitest / playwright}
- 构建命令: {e.g. npm run build}          # 必须是包管理器脚本调用
- 测试命令: {e.g. npm run test}
- Lint 命令: {e.g. npm run lint}

## 需求描述
{自然语言描述要做什么，越详细越好}

## 涉及模块
- 前端: {src/components/..., src/pages/...}
- 后端: {server/..., proto/...}
- 共享: {shared/...}

## 验收标准
- [ ] {具体的可测试条件 1}
- [ ] {具体的可测试条件 2}
- [ ] ...

## 约束与注意事项
- {不要改动的文件/模块}
- {必须兼容的现有功能}
- {性能/安全要求}

## 禁止操作（可选）
- {e.g. 禁止修改 package-lock.json}
- {e.g. 禁止删除任何现有文件}
- {e.g. 禁止引入新的运行时依赖}

## 覆盖率要求（可选）
- 单元测试覆盖率: {e.g. 60%}
- 关键路径测试: {e.g. 必须覆盖}

## 参考资料（可选）
- {设计文档链接或路径}
- {相关 issue/PR}
```

---

## 5. 安全策略

### 5.1 命令执行安全

**命令来源约束**：PM 只执行需求文档中用户显式填写的命令（构建/测试/lint），不自行构造任意 shell。

**执行约束**：
- 每个命令最大超时：**300 秒**（5 分钟）
- 工作目录限定为项目路径
- 命令执行前 PM 检查是否为包管理器脚本调用格式（`npm run X` / `make X` / `pnpm X` / `yarn X`）

**Phase 0 验证**：
- 检查命令格式是否符合 allowlist
- dry run 验证命令可执行（例如检查 `package.json` 中 scripts 字段是否包含对应脚本名）
- 验证不通过则 Gate 0 阻塞，提示用户修正

### 5.2 文件 Ownership 与并发安全

**原则**：任何文件在任何时刻只有一个 writer。

| 文件类型 | Owner | 并发阶段行为 |
|---------|-------|-------------|
| `.team/` 下的产出物 | 各角色按任务书指定路径写入，路径不重叠 | 天然隔离 |
| 接口契约 `interface-contract.md` | PM（Phase 4 生成） | Phase 5/6 冻结，只读 |
| 项目源码文件 | PM 在任务拆分时确保前后端任务清单中的文件路径不重叠 | 并行安全 |
| 共享类型文件（极少见） | 总架构师在架构方案中指定单一 owner | PM 串行调度该任务，不并行 |

**PM 任务拆分时的检查**：如果前后端任务清单中存在相同文件路径，PM 必须将其分配给单一角色，或将该任务从并行改为串行。

---

## 6. Gate ↔ Phase 映射表

| Gate | Phase | 名称 | 验证级别 |
|------|-------|------|---------|
| Gate 0 | Phase 0 | 立项准备完成 | 执行验证（命令 dry run） |
| Gate 1 | Phase 1 | 项目启动会完成 | 文件检查 |
| Gate 2 | Phase 2 | 架构设计完成 | 结构验证（接口名称交叉比对） |
| Gate 3 | Phase 3 | 架构评审通过 | 文件检查 + blocker 计数 |
| Gate 4 | Phase 4 | 任务拆分完成 | 覆盖验证（任务条目数 >= 验收标准条目数） |
| Gate 5 | Phase 5 | 编码完成 | 执行验证（构建 + lint exit code） |
| Gate 6 | Phase 6 | 测试通过 | 执行验证（测试 exit code + 覆盖率） |
| Gate 7 | Phase 7 | 项目评审通过 | 文件检查 + blocker 计数 |

---

## 7. 完整流程定义

### 7.0 Phase 0: 立项准备

**执行者**：PM

**流程**：
1. 读取并校验需求文档（必填字段、路径规范化）
2. 安全校验（命令 allowlist、禁止操作合并）
3. 探索项目目录结构（验证路径、框架）
4. 初始化 `.team/` 目录（含 `.team/.gitignore`）
5. 检查是否存在 `status.json`（支持 `--resume`）
6. 生成 `.team/project-brief.md`

**Gate 0 出口条件**：
- [ ] 需求文档必填字段完整
- [ ] 项目路径存在（相对路径已规范化为绝对路径）
- [ ] 构建/测试/lint 命令通过 allowlist 校验
- [ ] 命令对应脚本存在（package.json scripts / Makefile target）
- [ ] `.team/` 目录已创建

---

### 7.1 Phase 1: 项目启动会

**执行者**：PM

**流程**：

```
PM 读取 project-brief.md + 需求文档
    │
    ▼
分析涉及模块、技术栈、风险点
    │
    ▼
生成三份核心文件：
    │
    ├── .team/kickoff/assignment.md     ← 任务分派表
    │     谁做什么、交什么、依赖谁
    │
    ├── .team/kickoff/gates.md          ← Gate 门禁定义
    │     每个 Gate 的入口/出口条件
    │
    └── .team/kickoff/brief-{role}.md   ← 7 份角色任务书
          每个角色的详细指令
```

**角色任务书格式**（以后端开发为例）：

```markdown
# 后端开发工程师 - 任务书

## 你的身份
你是后端开发工程师。你的职责是根据架构方案和任务清单实现所有后端代码。

## 行为规范
1. 先读取所有输入文件再动手写代码
2. 严格按照任务清单逐项实现，不做额外的事
3. 遵循项目现有代码风格
4. 实现完成后必须自测（构建 + lint）
5. 自测失败时自行修复，最多尝试 2 轮
6. 最终写实现报告到指定路径

## 输入文件
- 需求文档: {requirement_path}
- 后端架构方案: .team/arch/backend.md
- 接口契约: .team/tasks/interface-contract.md（只读，不可修改）
- 任务清单: .team/tasks/backend.md

## 交付物
- 实际代码文件（路径在任务清单中指定）
- 实现报告: .team/impl/backend.md

## 验收标准
- [ ] 任务清单中每一项标记完成
- [ ] 构建命令 `{build_cmd}` exit code = 0
- [ ] Lint 命令 `{lint_cmd}` exit code = 0
- [ ] 未修改约束中列出的禁止修改文件
- [ ] 未修改接口契约文件

## 约束
- 不要修改: {constraint_files}
- 必须兼容: {compatibility_requirements}
- 复用项目现有模式: {patterns_to_follow}
- 命令超时: 300 秒
```

**`--interactive` 模式**：Phase 1 完成后暂停，向用户展示分派表和 Gate 定义，等待确认。

**Codex 降级**：Phase 1 完成后写 `.team/pause-required.md`（内容："项目启动会已完成，请审阅 .team/kickoff/ 下的文件后运行 --resume 继续"），然后正常退出。

**Gate 1 出口条件**：
- [ ] `.team/kickoff/assignment.md` 存在
- [ ] `.team/kickoff/gates.md` 存在
- [ ] 7 份角色任务书全部存在

---

### 7.2 Phase 2: 架构设计

**分两步执行**（总架构先行，前后端并行跟进）：

#### Step 2a: 总架构师（单独）

**子 agent 内部流程**：

```
1. 读取上下文
   ├── 需求文档
   ├── .team/kickoff/brief-chief-architect.md（任务书）
   └── 项目现有代码（Glob/Grep/Read 探索目录结构和现有模式）

2. 执行工作
   ├── 分析业务目标，拆解为技术模块
   ├── 定义模块划分（新增模块、修改模块、依赖关系）
   ├── 技术选型（如需新依赖，说明理由和替代方案）
   ├── 接口边界定义（前后端通信点、数据格式、错误码）
   ├── 数据模型变更（新增/修改的结构）
   └── 风险识别（技术风险、兼容性风险、成本风险）

3. 自检
   ├── [ ] 覆盖需求文档所有功能点？
   ├── [ ] 接口定义完整（输入/输出/错误码）？
   ├── [ ] 与项目现有架构风格一致？
   └── [ ] 关键风险已识别？

4. 交付
   └── 写 .team/arch/chief.md（含自检结果）
```

#### Step 2b: 前端架构师 + 后端架构师（并行，并发数 = 2）

**前端架构师子 agent 内部流程**：

```
1. 读取上下文
   ├── 需求文档
   ├── .team/kickoff/brief-frontend-architect.md
   ├── .team/arch/chief.md（总架构，上游依赖）
   └── 项目前端代码（src/ 目录探索现有模式）

2. 执行工作
   ├── 新增/修改的页面和路由
   ├── 组件树设计（组件名、父子关系、props 接口）
   ├── 状态管理方案（store/context 变更）
   ├── 与后端 API 对接方式（调用点、错误处理、loading 状态）
   └── 样式/交互方案

3. 自检
   ├── [ ] 组件设计覆盖所有前端功能点？
   ├── [ ] 与总架构的接口边界对齐？
   ├── [ ] 复用了现有组件/模式？
   └── [ ] 考虑了响应式/多语言/主题等现有能力？

4. 交付
   └── 写 .team/arch/frontend.md
```

**后端架构师子 agent 内部流程**：

```
1. 读取上下文
   ├── 需求文档
   ├── .team/kickoff/brief-backend-architect.md
   ├── .team/arch/chief.md
   └── 项目后端代码（server/ proto/ 目录探索现有模式）

2. 执行工作
   ├── 新增/修改的 RPC/API 定义（proto 级别）
   ├── Handler 实现方案（数据来源、处理逻辑）
   ├── 数据存储方案（缓存策略、TTL、key 设计）
   ├── 外部依赖调用（第三方 API、LLM、搜索 provider）
   └── 错误处理与降级策略

3. 自检
   ├── [ ] RPC 定义覆盖总架构的接口边界？
   ├── [ ] 缓存/限流策略与现有模式一致？
   ├── [ ] 复用了现有 shared 工具？
   └── [ ] 成本估算（LLM/外部 API 调用次数）？

4. 交付
   └── 写 .team/arch/backend.md
```

**PM Gate 2 检查**：
- [ ] `.team/arch/chief.md` 存在且非空
- [ ] `.team/arch/frontend.md` 存在且非空
- [ ] `.team/arch/backend.md` 存在且非空
- [ ] 三份文档中的接口名称交叉比对无遗漏（PM 提取接口名列表做集合比较）

---

### 7.3 Phase 3: 架构评审会

**执行方式**：并行启动 3 个评审 agent（并发数 = 3）。

**每个评审 agent 的内部流程**：

```
1. 读取上下文
   ├── .team/arch/chief.md（总架构）
   ├── .team/arch/frontend.md（前端架构）
   ├── .team/arch/backend.md（后端架构）
   └── 自己的角色 prompt（决定评审视角）

2. 执行评审
   ├── 逐项检查被评审方案
   ├── 对每个问题标注严重级别：
   │   ├── blocker: 不修复则无法继续
   │   ├── major: 应该修复但不阻塞
   │   └── minor: 建议改进
   └── 给出通过/不通过建议

3. 交付
   └── 写 .team/review/arch-review-by-{role}.md
```

**各评审 agent 的视角**：

| 评审者 | 视角 | 重点检查 |
|--------|------|---------|
| 前端架构师 | 评审后端方案 | 后端 API 是否满足前端调用需求、字段/格式/错误码是否对齐 |
| 后端架构师 | 评审前端方案 | 前端数据流是否合理、是否有过多 API 调用、是否缺少接口 |
| 总架构师 | 评审整体 | 前后端一致性、模块边界清晰度、风险是否被充分处理 |

**PM 汇总与裁决**：

```
收集 3 份评审报告
    │
    ▼
统计 blocker 数量 → 写 .team/review/arch-review-summary.md
    │
    ├── blocker = 0 → Gate 3 通过
    │
    └── blocker > 0 → 不通过
         │
         ▼
    定向修复：
    ├── 识别 blocker 涉及的角色
    ├── 只重跑该角色的 Phase 2 agent
    │   （prompt 中注入评审问题清单）
    └── 重新收集架构文档 → 重新评审
         （最多 2 轮）
```

**`--interactive` / Codex 降级**：评审汇总后暂停/写 pause 文件。

**定向修复 prompt 示例**：

```
你是后端架构师。上一轮架构评审发现以下 blocker 问题需要修改：

## Blocker 问题
1. [来自前端架构师评审] 后端 RPC 缺少分页参数，前端列表页无法实现
2. [来自总架构师评审] 缓存 key 设计与现有项目模式不一致

## 你的任务
1. 读取 .team/arch/backend.md（你上一轮的架构方案）
2. 针对上述问题逐项修改
3. 重新生成 .team/arch/backend.md
4. 在文档末尾增加"修订记录"章节，说明改了什么

## 约束
- 只修改 blocker 涉及的部分
- 不要推翻整个架构重来
```

**Gate 3 出口条件**：
- [ ] 3 份评审报告存在
- [ ] blocker 级问题数 = 0

---

### 7.4 Phase 4: 任务拆分

**执行者**：PM

**流程**：

```
PM 读取通过的架构方案（3 份）
    │
    ▼
拆分为具体编码任务：
    │
    ├── .team/tasks/frontend.md（前端任务清单）
    ├── .team/tasks/backend.md（后端任务清单）
    └── .team/tasks/interface-contract.md（接口契约，生成后冻结）
```

**PM 在拆分时执行的检查**：
1. 前端和后端任务清单中的文件路径不得重叠
2. 如有共享文件需要修改，指定单一 owner 并标注串行
3. 任务条目数 >= 需求文档验收标准条目数（确保覆盖）

**Gate 4 出口条件**：
- [ ] `.team/tasks/frontend.md` 非空
- [ ] `.team/tasks/backend.md` 非空
- [ ] `.team/tasks/interface-contract.md` 非空
- [ ] 前后端文件路径无重叠
- [ ] 任务条目覆盖所有验收标准

---

### 7.5 Phase 5: 编码实现

**执行方式**：前端开发 + 后端开发并行（并发数 = 2）。

**子 agent 内部流程（两端一致）**：

```
1. 读取上下文
   ├── 需求文档
   ├── .team/kickoff/brief-{role}.md（任务书）
   ├── .team/arch/{frontend|backend}.md（架构方案）
   ├── .team/tasks/{frontend|backend}.md（任务清单）
   ├── .team/tasks/interface-contract.md（接口契约，只读）
   └── .team/review/arch-review-summary.md（评审修改要求）

2. 逐项实现
   for each task in 任务清单:
     a. 读取相关现有代码（理解上下文）
     b. 写代码（新增 → Write tool，修改 → Edit tool）
     c. 确认与接口契约一致
     d. 在任务清单中标记完成

3. 自测
   a. 执行构建命令（超时 300s）→ 检查 exit code
   b. 执行 lint 命令（超时 300s）→ 检查 exit code
   c. 如果失败：
      ├── 阅读错误信息
      ├── 定位并修复
      └── 重新执行（最多 2 轮）

4. 交付
   └── 写 .team/impl/{role}.md
```

**PM Gate 5 检查**：
- [ ] `.team/impl/frontend.md` 中所有任务标记 `[x]`
- [ ] `.team/impl/backend.md` 中所有任务标记 `[x]`
- [ ] 执行构建命令（超时 300s）→ exit code = 0
- [ ] 执行 lint 命令（超时 300s）→ exit code = 0

---

### 7.6 Phase 6: 测试验证

**执行方式**：前端测试 + 后端测试并行（并发数 = 2）。

**子 agent 内部流程**：

```
1. 读取上下文
   ├── 需求文档（验收标准）
   ├── .team/kickoff/brief-{role}.md
   ├── .team/tasks/interface-contract.md
   ├── .team/impl/{frontend|backend}.md（知道改了什么）
   └── .team/arch/{frontend|backend}.md（理解设计意图）

2. 编写测试用例
   ├── 从需求验收标准拆解为可测试用例
   ├── 从实现报告确认测试范围
   ├── 编写单元测试
   └── 编写集成测试（如有 e2e 框架）

3. 执行测试（真实运行，超时 300s）
   a. 运行测试命令（Bash tool）
   b. 收集结果：通过/失败/跳过数量
   c. 收集覆盖率（如测试框架支持）
   d. 对失败用例：
      ├── 分析是测试写错还是代码 bug
      ├── 测试写错 → 自行修复（仅技术性错误：语法、import、mock）
      │   NOTE: 不得修改断言逻辑以降低验收标准
      └── 代码 bug → 记录到缺陷清单

4. 交付
   └── 写 .team/test/{role}.md
```

**PM Gate 6 检查**：
- [ ] 测试命令（超时 300s）exit code = 0
- [ ] 失败用例数 = 0
- [ ] 覆盖率 >= 需求文档要求（或默认 60%）

**Gate 6 不通过时的定向修复循环**：

```
PM 汇总缺陷清单
    │
    ▼
生成修复 prompt（注入缺陷清单 + lastErrorSummary）
    │
    ▼
只重跑出问题的开发工程师 agent
    │
    ▼
开发修复完成 → 只重跑对应的测试工程师 agent
    │
    ▼
重新检查 Gate 6
    （最多 3 轮）
    │
    超限 → 生成 .team/blocked-report.md → 终止
```

---

### 7.7 Phase 7: 项目评审会

**执行方式**：并行启动 3 个评审 agent（并发数 = 3）。

| 评审者 | 视角 | 重点检查 |
|--------|------|---------|
| 总架构师 | 代码质量 + 架构一致性 | 代码是否按架构实现、模块边界是否清晰、安全/性能隐患 |
| 前端测试 | 前端质量 | 前端测试充分性、边界用例覆盖、用户体验合理性 |
| 后端测试 | 后端质量 | 后端测试充分性、性能/安全检查、错误处理完整性 |

**子 agent 内部流程（以总架构师为例）**：

```
1. 读取上下文
   ├── .team/arch/chief.md（架构方案）
   ├── .team/impl/frontend.md + .team/impl/backend.md（实现报告）
   ├── .team/test/frontend.md + .team/test/backend.md（测试报告）
   └── 实际代码文件（Read 查看关键实现文件）

2. 执行评审
   ├── 代码与架构一致性
   ├── 代码质量（安全、性能、风格）
   └── 测试充分性

3. 标注严重级别 + 通过/不通过

4. 交付
   └── 写 .team/review/project-review-by-chief.md
```

**PM 汇总与裁决**：
- blocker = 0 → Gate 7 通过
- blocker > 0 → 定向修复 → 重新测试 → 重新评审（最多 2 轮）
- 超限 → `.team/blocked-report.md`

**Gate 7 出口条件**：
- [ ] 3 份项目评审报告存在
- [ ] blocker 级问题数 = 0

---

### 7.8 Phase 8: 交付

**执行者**：PM

**流程**：
1. 汇总所有产出物
2. 生成 `.team/final-report.md`
3. 如需求文档明确授权且 `--interactive` 下用户确认 → 执行 commit

**最终报告格式**：

```markdown
# 项目交付报告

## 项目概要
- 需求: {title}
- 总耗时: {elapsed}
- 经历阶段: 8/8
- 修订轮次: 架构评审 {N} 轮，项目评审 {N} 轮

## 变更文件清单
| 文件 | 操作 | 说明 |
|------|------|------|

## 测试结果汇总
- 前端: {pass}/{total}，覆盖率 {X}%
- 后端: {pass}/{total}，覆盖率 {X}%

## 评审结论
- 架构评审: 通过（第 {N} 轮），遗留 minor {count} 条
- 项目评审: 通过（第 {N} 轮），遗留 minor {count} 条

## 遗留问题
| # | 描述 | 级别 | 建议 |
|---|------|------|------|

## 后续建议
- ...
```

---

## 8. Gate 门禁完整定义

```markdown
### Gate 0: 立项准备完成
入口: 用户提供需求文档
出口:
  - [ ] 需求文档必填字段完整
  - [ ] 项目路径存在
  - [ ] 命令通过 allowlist 校验
  - [ ] 命令对应脚本存在
  - [ ] .team/ 已初始化
阻塞动作: 报错，提示用户补全需求文档

### Gate 1: 项目启动会完成
入口: Gate 0 通过
出口:
  - [ ] .team/kickoff/assignment.md 存在
  - [ ] .team/kickoff/gates.md 存在
  - [ ] 7 份角色任务书全部存在
阻塞动作: PM 自行补全

### Gate 2: 架构设计完成
入口: Gate 1 通过
出口:
  - [ ] .team/arch/chief.md 非空
  - [ ] .team/arch/frontend.md 非空
  - [ ] .team/arch/backend.md 非空
  - [ ] 接口名称交叉比对无遗漏
阻塞动作: 重跑缺失角色的 agent

### Gate 3: 架构评审通过
入口: Gate 2 通过
出口:
  - [ ] 3 份评审报告存在
  - [ ] blocker 级问题数 = 0
阻塞动作: 定向修复 → 重新评审（最多 2 轮）

### Gate 4: 任务拆分完成
入口: Gate 3 通过
出口:
  - [ ] .team/tasks/frontend.md 非空
  - [ ] .team/tasks/backend.md 非空
  - [ ] .team/tasks/interface-contract.md 非空
  - [ ] 前后端文件路径无重叠
  - [ ] 任务条目覆盖所有验收标准
阻塞动作: PM 自行补全

### Gate 5: 编码完成
入口: Gate 4 通过
出口:
  - [ ] 前端/后端实现报告中所有任务 [x]
  - [ ] 构建命令 exit code = 0（超时 300s）
  - [ ] lint 命令 exit code = 0（超时 300s）
阻塞动作: 重跑失败角色的开发 agent

### Gate 6: 测试通过
入口: Gate 5 通过
出口:
  - [ ] 测试命令 exit code = 0（超时 300s）
  - [ ] 失败用例数 = 0
  - [ ] 覆盖率 >= 阈值
阻塞动作: 缺陷 → 开发修复 → 重测（最多 3 轮）

### Gate 7: 项目评审通过
入口: Gate 6 通过
出口:
  - [ ] 3 份项目评审报告存在
  - [ ] blocker 级问题数 = 0
阻塞动作: 定向修复 → 重测 → 重新评审（最多 2 轮）
```

**最大重试超限退出策略**：生成 `.team/blocked-report.md`，包含：
- 阻塞在哪个 Gate
- 失败原因摘要（来自 `status.json` 的 `lastErrorSummary`）
- 未解决的 blocker 问题清单
- 建议下一步（用户确认/人工介入/修改需求后 `--resume`）

---

## 9. PM 状态追踪

PM 通过 `.team/status.json` 追踪全流程进度：

```json
{
  "version": "1.0",
  "startedAt": "2026-03-15T10:00:00Z",
  "inputsHash": "sha256_of_requirement_doc_content",
  "protocolVersion": "1.0",
  "currentPhase": "phase5-implementation",
  "resumable": true,
  "gates": {
    "gate0": { "status": "passed", "passedAt": "...", "attempts": 1 },
    "gate1": { "status": "passed", "passedAt": "...", "attempts": 1 },
    "gate2": { "status": "passed", "passedAt": "...", "attempts": 1 },
    "gate3": {
      "status": "passed", "passedAt": "...", "attempts": 2,
      "failureReason": "后端架构缺少分页参数（blocker）",
      "note": "第 2 轮修订后通过"
    },
    "gate4": { "status": "passed", "passedAt": "...", "attempts": 1 },
    "gate5": { "status": "in_progress", "attempts": 1 },
    "gate6": { "status": "pending" },
    "gate7": { "status": "pending" }
  },
  "agents": {
    "chief-architect-phase2": { "status": "completed", "duration": "45s" },
    "frontend-architect-phase2": { "status": "completed", "duration": "38s" },
    "backend-architect-phase2": { "status": "completed", "duration": "52s" },
    "backend-architect-phase2-fix1": {
      "status": "completed", "duration": "30s",
      "reason": "blocker fix",
      "lastErrorSummary": "RPC 缺少分页参数"
    },
    "frontend-developer-phase5": { "status": "running" },
    "backend-developer-phase5": { "status": "running" }
  }
}
```

**幂等策略**：
- `--resume`：读取 `status.json`，从最后一个非 `passed` Gate 继续，已通过的 Gate 跳过
- `--force`：忽略 `status.json`，全部重跑
- 默认（无参数）：如果 `status.json` 存在且 `inputsHash` 匹配，行为同 `--resume`；否则全新开始

---

## 10. 跨平台实现

### 10.1 核心共用层

角色 prompt（`roles/*.md`）、协议（`protocols/*.md`）、模板（`templates/*.md`）是两端共用的核心资产。

### 10.2 Claude Code 实现

`SKILL.md` 作为 orchestrator（PM 角色）：

```yaml
---
name: virtual-team
description: Multi-agent virtual development team that takes a requirement doc and delivers architecture, code, and tests
argument-hint: "<requirement.md> [--interactive] [--resume] [--force]"
context: fork
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, TodoWrite, AskUserQuestion
---
```

### 10.3 Codex CLI 实现

**角色配置**（`codex/config.toml`）：

```toml
# PM orchestrator 由外层 codex 调用承担，不配置为子 agent。
# 以下 7 个子角色由 PM 按阶段调度。

[agents]
max_threads = 3    # 最大并发数按最大阶段需求设定（评审会 3 个并行）
max_depth = 1

[agents.chief-architect]
description = "Total architecture design, cross-cutting concerns, risk identification"
config_file = "codex/agents/chief-architect.toml"

[agents.frontend-architect]
description = "Frontend component design, routing, state management"
config_file = "codex/agents/frontend-architect.toml"

[agents.backend-architect]
description = "Backend API/RPC design, storage, caching strategy"
config_file = "codex/agents/backend-architect.toml"

[agents.frontend-developer]
description = "Frontend code implementation based on architecture and task list"
config_file = "codex/agents/frontend-developer.toml"

[agents.backend-developer]
description = "Backend code implementation based on architecture and task list"
config_file = "codex/agents/backend-developer.toml"

[agents.frontend-tester]
description = "Frontend test writing and execution"
config_file = "codex/agents/frontend-tester.toml"

[agents.backend-tester]
description = "Backend test writing and execution"
config_file = "codex/agents/backend-tester.toml"
```

### 10.4 各阶段并发上限

| 阶段 | 并发数 | 原因 |
|------|--------|------|
| Phase 2a | 1 | 总架构必须先行 |
| Phase 2b | 2 | 前端+后端并行 |
| Phase 3 | 3 | 三个评审并行 |
| Phase 5 | 2 | 前端+后端并行，文件路径不重叠 |
| Phase 6 | 2 | 前端+后端测试并行 |
| Phase 7 | 3 | 三个评审并行 |

---

## 11. 角色 System Prompt 设计

### 11.1 通用行为规范（`roles/_common.md`）

```markdown
## 通用行为规范

1. 先读取所有输入文件再开始工作，不要边读边做
2. 严格按照任务书的要求执行，不做额外的事
3. 遵循项目现有代码风格和模式
4. 产出物必须写到任务书指定的路径
5. 产出物必须包含自检结果（逐条对照验收标准）
6. 遇到阻塞时记录到报告中，不要停止或猜测
7. 不要修改任务书中标注为"禁止修改"的文件
8. 不要引入任务书未提及的新依赖
9. 不要删除任何现有文件（除非任务书明确要求）
10. 不要执行任务书未列出的命令
11. 接口契约文件（interface-contract.md）为只读，不可修改
```

### 11.2 各角色 prompt 核心结构

每个 `roles/{role}.md` 包含：

```markdown
# {角色名称}

## 身份定义
你是{角色}，你的专业领域是{...}

## 职责范围
- 负责{...}
- 不负责{...}（那是{其他角色}的职责）

## 工作方法
{该角色特有的工作方式}

## 质量标准
{该角色特有的质量要求}

## 常见陷阱
{该角色容易犯的错误和避免方式}
```

### 11.3 测试工程师特有规范

```markdown
## 测试修改边界
- 允许修复：语法错误、import 路径、mock 数据、类型标注等技术性问题
- 禁止修改：断言逻辑（不得通过降低验收标准来让测试通过）
- 如果验收标准本身有歧义：记录到报告中，标注为"需 PM 裁决"，不自行解释
```

---

## 12. 实施计划

| 阶段 | 内容 | 预估耗时 |
|------|------|---------|
| Step 1 | 需求文档模板 + 产出物模板（templates/*.md） | 2h |
| Step 2 | 8 个角色 system prompt（roles/*.md） | 4h |
| Step 3 | 8 个阶段协议（protocols/*.md） | 3h |
| Step 4 | 安全策略实现（命令 allowlist、超时、ownership 规则、resume 机制） | 2h |
| Step 5 | Claude Code SKILL.md（PM orchestrator 逻辑） | 6h |
| Step 6 | Codex config.toml + 7 个角色 agent toml | 2h |
| Step 7 | 端到端测试 - 正常路径（用 news-to-stocks 需求） | 3h |
| Step 8 | 端到端测试 - 失败路径（命令不存在、超时、并发冲突、最大重试、resume） | 2h |
| Step 9 | 调优（prompt 调参、Gate 条件调整、修复循环优化） | 3h |
| **合计** | | **~27h / 3.5-4 天** |

---

## 13. 已确认的设计决策

| 决策 | 选项 | 确认 |
|------|------|------|
| 执行模式 | B+C 混合（阶段串行 + 阶段内并行） | ✓ |
| PM 角色 | Orchestrator 本身，不作为子 agent | ✓ |
| 交互模式 | 默认全自动，`--interactive` 暂停，`--resume` 续跑，`--force` 重跑 | ✓ |
| Gate 不通过修复 | 定向修复（只重跑出问题的角色） | ✓ |
| 评审裁决 | PM 汇总，blocker 一票否决 | ✓ |
| 测试 | 真跑测试（Bash tool 执行，超时 300s） | ✓ |
| 跨平台 | 核心共用（roles/protocols/templates）+ 调度分离 | ✓ |
| 工作目录 | `.team/`，`.team/.gitignore` 自我忽略，不改仓库根 `.gitignore` | ✓ |
| 最大重试 | 架构评审 2 轮、项目评审 2 轮、测试修复 3 轮；超限生成 blocked-report | ✓ |
| 安全边界 | 命令 allowlist + 超时 + 文件 ownership + 默认不 commit | ✓ |
| 幂等策略 | inputsHash + 已通过 Gate 跳过 + `--force` 覆盖 | ✓ |
| 并发安全 | 文件路径不重叠 + 接口契约冻结 + 共享文件单 owner | ✓ |
| Codex 降级 | 无交互能力时写 pause-required.md 后退出 | ✓ |

---

## 14. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 子 agent 上下文窗口不足 | 大项目代码探索可能超限 | 任务书精确指定要读的文件，避免盲目探索 |
| LLM 生成的架构方案质量不稳定 | 评审通过但实现时发现问题 | 架构评审 + 项目评审双重把关；评审 agent 读实际代码 |
| 并发 agent 修改同一文件 | 代码冲突 | PM 任务拆分时确保文件路径不重叠；接口契约冻结；共享文件单 owner + 串行 |
| 修复循环不收敛 | 反复打回浪费资源 | 最大重试次数；超限生成 blocked-report 终止，交用户决策 |
| 测试框架不存在或配置错误 | 测试阶段无法执行 | Phase 0 验证命令可执行；不可用则跳过自动测试，标注手动验证 |
| Codex 和 Claude Code 行为差异 | 同一 prompt 两端产出不一致 | 核心逻辑在 prompt 中；模板强制产出格式 |
| 命令注入 / 破坏性命令 | 执行任意 shell | 命令 allowlist + 超时 300s + cwd 限定项目路径 + 只执行需求文档中用户显式填写的命令 |
| 不可恢复 / 不可重入 | 中断后整套重跑 | status.json 记录 inputsHash + Gate 状态；`--resume` 断点续跑；`--force` 强制重跑 |

---

## 附录：Review 意见处理记录

| # | 章节 | 意见 | 处理 | 理由 |
|---|------|------|------|------|
| 1 | §1 | PM 角色定位需明确 | 采纳 | PM 两端都是 orchestrator 本身，新增 §1.2 |
| 2 | §1 | Gate 条件需更可机验 | 采纳 | 分级处理：Gate 0/5/6 执行验证，Gate 2 接口交叉比对，Gate 4 覆盖验证 |
| 3 | §1 | 默认自动化边界 | 采纳 | 新增 §1.3 |
| 4 | §1.2 | 跨平台降级定义 | 采纳 | 新增 §1.5 + pause-required.md 机制 |
| 5 | §1.2 | 命令安全边界前置 | 采纳 | 新增 §5 安全策略 + Phase 0 验证 |
| 6 | §2 | 补充 README | 采纳 | 目录结构新增 README.md |
| 7 | §2 | Codex 侧 PM 缺位说明 | 采纳 | config.toml 注释说明 + §1.2 |
| 8 | §3 | .team/.gitignore 自我忽略 | 采纳 | 不改仓库根 .gitignore |
| 9 | §3 | 幂等/可恢复写入策略 | 采纳 | 新增 §3.1 + status.json inputsHash |
| 10 | §4 | 允许相对路径 | 采纳 | Phase 0 规范化 |
| 11 | §4 | 命令安全校验 | 采纳 | 合并到 §5 |
| 12 | §4 | 增加禁止操作字段 | 部分采纳 | 新增可选字段 + _common.md 默认规则 |
| 13 | §5.5 | Gate 编号错位 | 采纳 | 新增 §6 Gate ↔ Phase 映射表 |
| 14 | §5.5 | 并发写文件 ownership | 采纳 | 新增 §5.2 ownership 规则 |
| 15 | §5.6 | 测试工程师改测试边界 | 采纳 | §11.3 测试工程师特有规范 |
| 16 | §5.6 | 测试命令安全校验 | 采纳 | 合并到 §5 |
| 17 | §6 | Gate ↔ Phase 映射表 | 采纳 | 新增 §6 |
| 18 | §6 | 升级为最小可验证条件 | 部分采纳 | Gate 0/2/4/5/6 升级，Gate 1/3/7 保持 |
| 19 | §6 | 安全门禁 | 采纳 | Gate 0 命令 allowlist，Gate 5/6 超时 |
| 20 | §7 | 断点续跑 resume | 采纳 | inputsHash + --resume + --force |
| 21 | §7 | 记录失败原因摘要 | 采纳 | agent/gate 增加 lastErrorSummary/failureReason |
| 22 | §7 | 幂等策略显式 | 采纳 | 已通过 Gate 跳过 + --force 覆盖 |
| 23 | §8 | PM orchestrator 落点 | 采纳 | config.toml 注释 + §1.2 |
| 24 | §8 | 按阶段定义并发上限 | 采纳 | 新增 §10.4 并发上限表 |
| 25 | §8 | 交互暂停等价实现 | 采纳 | §1.5 降级表 |
| 26 | §10 | 增加安全与幂等 Step | 采纳 | 新增 Step 4 |
| 27 | §10 | 端到端测试覆盖失败路径 | 采纳 | Step 7/8 拆分正常+失败 |
| 28 | §11 | .gitignore 改为自我忽略 | 采纳 | 同 #8 |
| 29 | §11 | 最大重试退出策略 | 采纳 | blocked-report.md |
| 30 | §12 | 命令注入风险 | 采纳 | 新增风险行 |
| 31 | §12 | 共享文件冲突风险 | 采纳 | 新增风险行 + §5.2 |
| 32 | §12 | 不可恢复风险 | 采纳 | 新增风险行 + resume 机制 |
