<!-- BEGINE:AGENTS.md -->

# AGENTS.md — Employment - Redistribution

> **开发/改代码前请先读 [`docs/mod-references.md`](docs/mod-references.md)**——已汇总全部官方文档路径、游戏源码位置、MOD 系统机制、常用 API 速查与踩坑记录，不用再盲目翻文档。

Surviving Mars: Relaunched（内部代号 Project Spark，Steam AppID 3215050）的本地 MOD。
功能：有专长的居民连续失业 N 个太阳日（选项，默认 3，可设 1-30）后，被退回「无专长」；儿童、老人、本身无专长者不受影响。

- MOD id: `dyLFuib`
- Steam 创意工坊 item: `3800017811`
- 本目录即 MOD 的完整内容目录（`%AppData%\Surviving Mars Relaunched\Mods\Employment - Redistribution`）

## 游戏版本基线（开发/测试时的实际版本）

| 项 | 值 | 来源 |
| --- | --- | --- |
| 游戏 Build version | `1.1.0.403908` | 运行日志 `logs\MarsDebug*.log`（"Build version" 行） |
| 游戏 Lua revision | `403908`（= `metadata.lua` 的 `saved_with_revision`） | 同上 |
| 游戏 Assets revision | `33006` | 同上 |
| MOD 开发时 lua_revision | `350453`（= `metadata.lua` 的 `lua_revision`，编辑器自动维护） | `metadata.lua` |
| Steam AppID | `3215050` | 日志 / 创意工坊 |

> 游戏更新后（`saved_with_revision` 变化）需重进 MOD 编辑器保存一次并复测；API 以新装目录下的 `ModTools\Docs\` 为准。

## 文件结构

| 文件 | 说明 |
| --- | --- |
| `metadata.lua` | MOD 定义（`PlaceObj('ModDef', ...)`）。**由游戏内 MOD 编辑器自动生成/重写**，保存时自动升 `version`、刷新 `code_hash`/`saved`/`steam_id`。不要手改 `lua_revision`、`saved_with_revision` 等字段。 |
| `items.lua` | MOD 条目序列化（`ModItemCode` + 两个选项）。编辑器保存时也会重写此文件。 |
| `Code/Script.lua` | 唯一的运行时 Lua 代码。由 `ModItemCode` 载入，可在编辑器外自由编辑。 |

## 关键规则（改代码前必读）

1. **选项的三处联动**：`items.lua` 里选项的 `name`（如 `Unemployment_Redist_Sols`）必须与 `Code/Script.lua` 里的键名、`metadata.lua` 的 `default_options` 键一致。改选项名/增删选项时三处同步，然后在 MOD 编辑器里保存（保存会触发 Lua reload 并重生 metadata/items）。
2. **改完 items.lua / metadata.lua 后**，到游戏的 MOD 编辑器里点保存，否则游戏可能读到不一致的状态（编辑器保存时若检测到 items.lua 被外部修改会弹确认框，选"覆盖"即可）。
3. `Code/Script.lua` 在沙箱环境运行，可用的全局对象/函数见游戏文档（下文）。对居民对象的一切调用建议包 `pcall`（居民可能在消息处理中途死亡/销毁）。
4. 本 MOD 的计数表 `unemp_days` 是**内存级**的（弱键表），不跨存档持久化；`OnMsg.NewGame` / `OnMsg.PostLoadGame` / `OnMsg.ModUnloadLua` 里必须清空，否则会跨档污染。
5. 选项值读取入口：`OnMsg.ModsReloaded` / `OnMsg.ApplyModOptions` → `CurrentModOptions.GetProperty(name)`。脚本顶部另有本地 `mod` 表作为兜底默认值。
6. 想开日志调试：把 `Code/Script.lua` 顶部 `DEBUG` 改为 `true`，游戏控制台会打印带 `[EmploymentRedist]` 前缀的日志。测完改回 `false`。

## 用到的游戏 API（来自随游戏发布的文档）

文档位置（与游戏版本同步，权威来源）：
`C:\Program Files (x86)\Steam\steamapps\common\Project Spark\ModTools\Docs\`
- `LuaDoc_Msg.md.html` — OnMsg 事件表
- `LuaMarsMapsLabels.md.html` — labels（`UICity.labels.Unemployed` 等）
- `ModItemOption.md.html` — 选项条目
- `Colonists.md.html` / `ModItemTrait.md.html` — 居民/特质
- 未打包的游戏源码可查：`ModTools\Src\Lua\Specialization.lua`（`const.ColonistSpecialization`）、`ModTools\Src\Data\TraitPreset.lua`

本 MOD 依赖的具体行为：
- 每太阳日 `OnMsg.NewDay(day)`
- `UICity.labels.Unemployed`：当前全体失业居民
- 专长 = 特质组 `Specialization`，居民属性 `colonist.specialist`；"无专长"的特质 id 是 `"none"`，其 `OnApply` 自动调用 `colonist:SetSpecialization("none")`
- 排除判定：`colonist.traits.Child`、`colonist.traits.Senior`（老人本身不能工作，不会出现在 Unemployed label 里，此处为双保险）
- 退回专长：`c:RemoveTrait(c.specialist, true)`（第二参 ignore_missing）+ `c:AddTrait("none")`

## 发布流程（本地 → 创意工坊）

1. 修改 `Code/Script.lua`（必要时改 `items.lua`）
2. 启动游戏 → MOD 编辑器里打开 Employment - Redistribution → 保存（外部 items.lua 被改过会弹确认，选覆盖）
3. 编辑器里上传到 Steam 创意工坊（会同步更新 metadata.lua 的 `steam_id`/`code_hash`）
4. `metadata.lua` 的 `last_changes` 保持中文或英文一句话更新说明，`version` 由编辑器自动递增，不用手填

## 验证方法（测试通过记录）

- 把 `Unemployment_Redist_Sols` 调成 1，拆掉某有专长居民的岗位使其失业，1 个太阳日后其专长变为 "No specialization"
- 对照组：儿童/老人/无专长者不受影响；重新就业后计数清零；阈值调大（30）时不触发
- 游戏中按 `Enter` 可打开调试控制台（`MarsDebug.exe` 运行时），可输入任意 Lua 代码查状态

<!-- END:AGENTS.md -->
