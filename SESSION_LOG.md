# SESSION_LOG

## 完成

- 2026-09-25 将 Windows 魔兽世界怀旧服插件同步流程封装为项目级 `wow-classic-addon-sync` Skill，包含备份、tar over SSH、数量比对和 SHA-256 校验。
- 2026-09-25 将项目级插件同步 Skill 提交并推送到 GitHub，提交为 `b50f155`。

## 发现

- 2026-09-25 SSH agent 已加载 ED25519 密钥且 GitHub 认证成功，Git 远端使用 HTTPS 时不会调用该 agent，切换为 SSH 远端后推送正常。
- 2026-09-25 Windows `sha256sum` 的文件名标记会影响跨平台清单文本比较，按文件排序后仅比较 SHA-256 序列可避免误报。

## 待办

- 无
