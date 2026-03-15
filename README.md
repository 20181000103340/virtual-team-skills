# Virtual Team Skills

多 agent 虚拟开发团队技能套件，适用于 Claude Code 和 Codex CLI。

## 包含技能

| 技能 | 说明 |
|------|------|
| `/virtual-team` | 多 agent 开发团队，输入需求文档，自动完成架构→编码→测试全流程 |
| `/virtual-team-init` | 交互式向导，引导用户生成结构化需求文档 |

## 支持语言

TypeScript/JavaScript、Python、Go、Rust、Java/Kotlin、Ruby、C#/.NET、C/C++

## 支持架构模式

web-fullstack / backend-api / cli-library / monolith / ddd-layered

## 安装

```bash
# 克隆仓库
git clone <repo-url> ~/virtual-team-skills

# 运行安装脚本（创建符号链接到 ~/.claude/skills/）
cd ~/virtual-team-skills
./install.sh
```

## 手动安装

```bash
ln -sf ~/virtual-team-skills/skills/virtual-team ~/.claude/skills/virtual-team
ln -sf ~/virtual-team-skills/skills/virtual-team-init ~/.claude/skills/virtual-team-init
```

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
├── install.sh
├── .gitignore
└── skills/
    ├── virtual-team/          # 主技能
    │   ├── SKILL.md           # Claude Code 入口
    │   ├── README.md
    │   ├── DESIGN.md          # 设计文档
    │   ├── roles/             # 角色 prompt
    │   ├── protocols/         # 阶段协议
    │   ├── templates/         # 产出物模板
    │   ├── codex/             # Codex CLI 配置
    │   └── tests/             # 验证测试
    └── virtual-team-init/     # 需求文档生成向导
        └── SKILL.md
```

## 详细文档

- [Virtual Team 设计文档](skills/virtual-team/DESIGN.md)
- [Virtual Team 使用说明](skills/virtual-team/README.md)
- [需求文档模板](skills/virtual-team/protocols/requirement-template.md)
