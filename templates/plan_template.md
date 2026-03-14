# Plan Output Template

Use this format when generating execution plans for users.
Adapt language to match user's input language.

---

## Chinese Template

```
## 执行计划

**你的需求**: {用一句话描述用户想要实现的目标}
**分类**: {行业} > {场景}
**步骤数**: {N} 步

### 第 1 步: {步骤名称}
- 做什么: {用大白话描述}
- 怎么做: {简述方法}
- 如果出问题: {自动修复策略}

### 第 2 步: {步骤名称}
...

---
预计用时: {大约时间}

确认执行？(Y/N)
```

## English Template

```
## Execution Plan

**Your Need**: {one-line description of what will be achieved}
**Category**: {industry} > {scenario}
**Steps**: {N}

### Step 1: {step name}
- What: {plain language description}
- How: {brief method}
- If issues: {auto-fix strategy}

### Step 2: {step name}
...

---
Estimated time: {rough estimate}

Proceed? (Y/N)
```
