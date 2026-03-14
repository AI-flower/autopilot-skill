# 🚀 Praxis — Claude Code Skill

[![Version](https://img.shields.io/badge/version-0.4.4-blue)](https://github.com/AI-flower/praxis-skill/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.1%2B-purple)](https://claude.ai/claude-code)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)]()

**Universal AI task execution engine for Claude Code.**
Describe any task in natural language → Praxis analyzes, plans, installs what's needed, and executes — with zero interruptions.

---

## ⚡ One-Line Install

```bash
npx skills add AI-flower/praxis-skill --global --yes
```

Or via curl:
```bash
curl -fsSL https://raw.githubusercontent.com/AI-flower/praxis-skill/main/install.sh | bash
```

---

## 🎯 What It Does

Just describe your need — Praxis handles everything else:

```
"帮我做一个宠物行业趋势报告，发到我邮箱"
"generate a spring travel video with narration and BGM"
"帮我爬取竞品价格并生成分析图表"
"build me a landing page for my SaaS product"
```

**You describe → AI plans → One confirm → Result delivered.**

### Core capabilities:
- **Intent analysis** — Understands what you need, picks the right tools
- **Auto dependency install** — Installs missing Python packages, CLI tools silently
- **Credential resolution** — Finds API keys from env/keychain, auto-registers free tiers
- **Output formats** — PDF, Word, video, images, code (auto-detected from context)
- **Email delivery** — Sends results with file/video attachments automatically
- **Locale-aware naming** — Files named in your language (中文/English/日本語...)
- **Solution library** — Reuses past executions to save time

---

## 📦 Skill Registry Commands

```bash
# Search for skills (local + GitHub)
python3 ~/.claude/skills/praxis/scripts/report.py find-skill "praxis" --github --pretty

# Install a skill by name or URL
python3 ~/.claude/skills/praxis/scripts/report.py install-skill praxis

# Publish your own skill to the registry
python3 ~/.claude/skills/praxis/scripts/report.py register-skill \
  --name my-skill --description "..." --repo "https://github.com/..." \
  --tags "automation,ai" --version "1.0.0"
```

---

## 🔧 Requirements

- Claude Code 2.1+
- Python 3.8+
- `git`, `curl`

---

## 🚀 Usage

After install, just describe any task in Claude Code:

```
帮我分析这份CSV数据并生成可视化报告
create a Python web scraper for product prices
生成一个关于西湖的旅游宣传视频
```

Praxis auto-triggers on natural language task descriptions.

---

## 📁 Structure

```
praxis-skill/
├── SKILL.md              # Skill definition (Claude Code format)
├── skills.json           # Discovery manifest (skill registry compatible)
├── install.sh            # One-click installer
├── uninstall.sh          # Clean uninstall
├── scripts/
│   └── report.py         # Core engine (find-skill, install-skill, send-email, etc.)
├── skills/praxis/     # skills.sh compatible subdirectory
│   └── SKILL.md
├── references/           # Internal reference docs
└── templates/            # Task templates
```

---

## 🌐 Discoverability

This skill is indexed via:
- GitHub Topics: `claude-code-skill` · `claude-skill` · `praxis` · `claude-code` · `anthropic`
- `skills.json` manifest (skill registry standard)
- Built-in search: `find-skill praxis --github`

---

## 📄 License

MIT © [AI-flower](https://github.com/AI-flower)
