# Virtual Team Skills

多 agent 虚拟开发团队技能套件，支持 Claude Code、Codex CLI 和 OpenClaw 三个平台。

## 包含技能

| 技能 | 说明 |
|------|------|
| `virtual-team` | 多 agent 开发团队，输入需求文档，自动完成架构→编码→测试全流程 |
| `virtual-team-init` | 交互式向导，引导用户生成结构化需求文档 |

## 支持语言

TypeScript/JavaScript、Python、Go、Rust、Java/Kotlin、Ruby、C#/.NET、C/C++

## 支持架构模式

web-fullstack / backend-api / cli-library / monolith / ddd-layered

## 安装

```bash
git clone https://github.com/20181000103340/virtual-team-skills.git ~/virtual-team-skills
cd ~/virtual-team-skills

# 选择平台安装
./install.sh claude-code    # Claude Code
./install.sh openclaw       # OpenClaw
./install.sh codex          # Codex CLI（显示配置说明）
./install.sh all            # 全部平台
```

## 平台支持

| 平台 | 执行开发流程 | 生成需求文档 | 安装方式 |
|------|-------------|-------------|---------|
| **Claude Code** | `/virtual-team req.md` | `/virtual-team-init` | `./install.sh claude-code` |
| **OpenClaw** | skill 自动加载 | skill 自动加载 | `./install.sh openclaw` |
| **Codex CLI** | TOML config | 不支持（无交互） | `./install.sh codex` |

> **Codex 用户**：先在 Claude Code 或 OpenClaw 中生成需求文档，再用 Codex 执行开发流程。

## 使用

```bash
# 1. 生成需求文档（交互式向导）
/virtual-team-init

# 2. 运行虚拟团队
/virtual-team requirement.md --interactive
```

## 目录结构

```
virtual-team-skills/
├── README.md
├── LICENSE
├── install.sh              # 平台安装脚本
├── .gitignore
├── core/                   # 共享核心（平台无关）
│   ├── roles/              # 角色 prompt（8 个角色）
│   ├── protocols/          # 阶段协议（9 个阶段）
│   ├── templates/          # 产出物模板（13 个模板）
│   ├── tests/              # 验证测试
│   └── DESIGN.md           # 设计文档
└── adapters/               # 平台适配层
    ├── claude-code/        # Claude Code
    │   ├── SKILL.md        # PM 编排器（用 Agent tool）
    │   ├── README.md
    │   └── init/
    │       └── SKILL.md    # 需求向导（用 AskUserQuestion）
    ├── codex/              # Codex CLI
    │   ├── config.toml     # 多 agent TOML 配置
    │   └── agents/         # 各角色 agent 定义
    └── openclaw/           # OpenClaw
        ├── SKILL.md        # PM 编排器（用 subagents spawn）
        └── init/
            └── SKILL.md    # 需求向导（用消息对话）
```

## 架构理念

**Core + Adapter** 模式：
- `core/` 包含所有平台共享的角色定义、协议、模板 — 只维护一份
- `adapters/` 为每个平台提供薄适配层 — 只处理平台差异（工具调用方式、交互方式）
- 安装脚本自动创建 `SKILL.md` + `core/` 符号链接

## 详细文档

- [设计文档](core/DESIGN.md)
- [需求文档模板](core/protocols/requirement-template.md)
- [Claude Code 使用说明](adapters/claude-code/README.md)
