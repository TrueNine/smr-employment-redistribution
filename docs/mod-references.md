# MOD 开发参考手册 — Surviving Mars: Relaunched

> 本文件是 Employment - Redistribution 及后续 SURVIVING MARS: Relaunched MOD 开发的**唯一参考入口**。
> 目标：以后改进本 MOD 或开发新 MOD，不需要再盲目翻游戏文档。
> 所有信息来自随游戏发布的官方文档与未打包 Lua 源码（与游戏版本同步，权威来源）。

---

## 1. 资源位置（都在本机，已验证存在）

### 游戏安装目录
```
C:\Program Files (x86)\Steam\steamapps\common\Project Spark\
├─ Mars.exe / MarsDebug.exe        ← MarsDebug 按 Enter 可开调试控制台
├─ Packs\*.fpk                     ← 打包资产（Data/Lua/UI 等）
├─ DLC\norman.fpk, thomas.fpk      ← DLC 包（norman=Feeding the Future）
├─ Local\                          ← 游戏本地数据（账号存储等）
└─ ModTools\
   ├─ Docs\*.md.html              ← ★ 官方 MOD 开发文档（HTML）
   ├─ Samples\                    ← 官方示例 MOD
   ├─ Src\
   │  ├─ Lua\*.lua               ← 未打包的游戏 Lua 源码（可直接读实现）
   │  ├─ Data\*.lua              ← 游戏 Preset 数据（TraitPreset、BuildingTemplate…）
   │  ├─ CommonLua\*             ← 引擎公共 Lua（CommonLua/Modding/Mod.lua、CommonLua/LuaExportedDocs/Global/*.lua…）
   └─ SolEngineLua.vsix          ← VS Code 调试扩展（可 attach 到游戏调试 Lua）
```

### 官方文档清单（`ModTools\Docs\`，55 个 HTML 文件）

| 文档 | 内容 | 何时看 |
| --- | --- | --- |
| `index.md.html` | 总览、MOD 存放路径、Mod Editor 用法、Lua 环境 | 入门 |
| `LuaDoc_Msg.md.html` | 全部 OnMsg 事件表 | 挂事件 |
| `Colonists.md.html` | 居民生命周期、年龄组、工作、状态、示例 | 居民类 MOD |
| `ModItemTrait.md.html` | 特质系统（组、增删、过滤、DailyUpdate…） | 改特质 |
| `ModItemOption.md.html` | 选项条目（toggle/number/choice）与 UI 行为 | 加选项 |
| `ModItemCode.md.html` | Lua 沙箱全局变量（CurrentMod*）、持久数据、调试 | 写代码 |
| `LuaDoc__G.md.html` | 引擎全局函数（线程、压缩、持久化、工具） | 调引擎 |
| `LuaDoc_Gameplay.md.html` | 高层玩法函数（研究、资金、锁建筑/特质…） | 玩法改动 |
| `LuaMarsMapsLabels.md.html` | labels 体系（city/dome/colony，Unemployed…） | 找对象集合 |
| `LuaDoc_CObject.md.html` | CObject 方法（IsValid、位置、状态…） | 对象操作 |
| `LuaDoc_SupplyGrid.md.html` / `LuaDoc_GridObject.md.html` / `LuaDoc_terrain.md.html` / `LuaDoc_hex.md.html` / `LuaDoc_point.md.html` / `LuaDoc_Selection.md.html` / `LuaDoc_camera*.md.html` | 网格/对象/地形/相机 | 高级 |
| `ModItemBuildingTemplate.md.html` / `ModItemEntity.md.html` / `ModItemEffect.md.html` / `ModItemGameRule.md.html` / `ModItemTech*.md.html` / `ModItemCrop.md.html` / `ModItemSound.md.html` / `ModItemLocTable.md.html` / `ModItemTrait.md.html` / `ModItemAnimal.md.html` / `ModItemVegetation.md.html` / `ModItemCommanderProfile.md.html` 等 | 各 ModItem 类型的属性 | 加新 ModItem |
| `LuaConditionDoc.md.html` / `LuaEffectDoc.md.html` / `ModItemStoryBit.md.html` | 条件/效果/剧情 | 做任务线 |
| `Research.md.html` | 科技系统 | 科技类 |

**读法**：这些是 markdeep 生成的 HTML，可用
```powershell
$h = Get-Content <file> -Raw; [regex]::Replace($h, '<[^>]+>', "`n")   # 去掉标签当纯文本读
```

### 未打包源码（可直接 Read 的文件，验证过）
- `Src\Lua\Specialization.lua` — `const.ColonistSpecialization`、`ValidateSpecialization`、实体命名
- `Src\Lua\Traits.lua` — 特质 UI/生成逻辑
- `Src\Lua\Units\Colonist.lua` — 居民实现
- `Src\Data\TraitPreset.lua` — 全部特质 Preset（含年龄组、专长组、OnApply 钩子）
- `Src\CommonLua\Modding\Mod.lua` — MOD 加载/保存/选项机制（`ModsReloadDefs`、`HasModsWithOptions`、`ModOptionsObject`…）
- `Src\CommonLua\LuaExportedDocs\Global\thread.lua` — 线程/时间 API 带注释
- `Src\Lua\_GameConst.lua` — `const.DayDuration = const.Scale.sols`、`const.HourDuration = const.Scale.h`

### 本地其他 MOD（可抄结构）
```
%AppData%\Surviving Mars Relaunched\Mods\WW Constant Meteor Storms\
  ├─ items.lua / metadata.lua
  └─ Code\Script.lua     ← 定时器 + 选项 + 灾害触发的完整范例（本 MOD 的模板来源）
```

### Steam 创意工坊 MOD（只读、需复制到 %AppData% 下才可加载）
```
C:\Program Files (x86)\Steam\steamapps\workshop\content\3215050\<steam_id>\
```
文档明确说：**游戏不会直接从这里加载本地修改**；要改用就复制进 `%AppData%\Surviving Mars Relaunched\Mods\`。

---

## 2. MOD 系统核心机制（从 Mod.lua 源码提炼）

- **加载来源**：本地 `%AppData%\Surviving Mars Relaunched\Mods\`（source="appdata"）+ 创意工坊订阅。启动时 `ModsReloadDefs` 扫描；编辑器保存后触发 "Reloading" 重建。
- **每个 MOD 目录 = metadata.lua（ModDef 序列化）+ items.lua（ModItem 序列化）+ 自由文件**。metadata/items 由编辑器生成重写；手写也可，但改完建议进编辑器保存一次以同步 hash。
- **options 展示条件**（`OptionsContentWindow` 的 ForEach 条件）：
  `IsKindOf(item.options, "ModOptionsObject") and next(item.options:GetProperties())`
  → 即：该 MOD 的 **items 已加载**（勾选启用）且**至少有一个带 `name` 的 ModItemOption**。没启用就不会进 Options 的 "Mod Options" 页。
- **选项值入口**：`CurrentModOptions.GetProperty(id)`；玩家点 Apply 后发 `OnMsg.ApplyModOptions(mod_id)`；MOD 热重载发 `OnMsg.ModsReloaded`。
- **代码条目**：`ModItemCode{CodeFileName=...}` 相对 MOD 根目录；游戏 Lua 与全部 DLC Lua **保证先于** MOD 代码加载。
- **持久数据（跨存档会话）**：`WriteModPersistentData` / `ReadModPersistentData`（每 MOD 独立、字符串、上限 `const.MaxModDataSize`）；`WriteModPersistentStorageTable` 可直接存 `CurrentModStorageTable`。⚠ 本 MOD 的失业计数没用它（内存级），如需跨读档保留可加。
- **MapVars**：随地图存取的存档内变量；`OnMsg.NewMapLoaded` 后初始化，MOD 在编辑器载入时不会自动初始化表值型 MapVar（需重启测试地图）。
- **版本字段**：`lua_revision`（开发时游戏版本）、`saved_with_revision`、`code_hash`、`steam_id`、`version` —— 编辑器保存时自动维护，**不要手改**。
- **冲突规避**：OnMsg 名字、DefineClass 类名跨 MOD/游戏全局共享，自定义的都加唯一前缀（如 `OnMsg.MyMod_X`、`DefineClass.MyMod_Y`）。
- **调试**：
  - `MarsDebug.exe` 运行中按 `Enter` 开控制台可执行任意 Lua；`F9` 清屏。
  - VS Code 装 `SolEngineLua.vsix`，打开 `ModTools\Src\ModTools.code-workspace`，F5 attach。
  - 日志位置：`%AppData%\Surviving Mars Relaunched\logs\`（`[mod]` 前缀行看 MOD 加载/重载）。

---

## 3. 常用 OnMsg 事件速查（本游戏实际支持的）

| 事件 | 参数 | 用途 |
| --- | --- | --- |
| `NewDay(day)` | 太阳日号 | 每日 tick（本 MOD 主逻辑） |
| `NewHour(hour)` | 小时号 | 每小时 tick（气象 MOD 用的） |
| `NewGame` | — | 开新局，清状态 |
| `PostLoadGame` / `LoadGame` / `PreLoadGame` | metadata, version | 读档前后，清状态 |
| `ModsReloaded` | — | MOD 热重载后 |
| `ApplyModOptions(mod_id)` | mod id | 玩家应用了 MOD 选项（注意判 `mod_id == CurrentModId`） |
| `ModUnloadLua(mod_id)` | mod id | MOD 卸载前清理 |
| `ColonistArrived(colonist)` / `ColonistBorn(colonist, event)` / `ColonistDied(c, reason)` / `ColonistLeavingMars(c, rocket)` | | 居民生命周期 |
| `ColonistChangeWorkplace(colonist, new_wp, old_wp)` | | 换工作点（**未来做"失业检测"更精确的钩子**） |
| `NewSpecialist(colonist)` | | 居民获得专长时（可用于"只统计有专长者"白名单） |
| `RocketLanded(rocket)` / `RocketLaunched` / `RocketStatusUpdate` | | 火箭 |
| `ConstructionComplete(building)` / `OnSetWorking(building, working)` | | 建筑事件 |
| `MeteorStorm` / `MeteorStormEnded` | | 灾害 |
| `Msg(name, ...)` | | 自定义事件（跨 MOD，记得加前缀） |

---

## 4. 居民（Colonist）速查

### 年龄组（特质，互斥，组 "Age Group"）
| 特质 id | 说明 | 能工作 |
| --- | --- | --- |
| `Child` | 儿童，上学、进游乐场 | ✗ |
| `Youth` | 青年，成年时按学校/游乐场表现生成随机特质 | ✓ |
| `Adult` | 成年 | ✓ |
| `Middle Aged` | 中年 | ✓ |
| `Senior` | 老人（OnApply 时若 `g_SeniorsCanWork` 为假会 `SetWorkplace(false)`） | 默认 ✗ |

### 专长（特质，组 "Specialization"，`const.ColonistSpecialization` 的 key）
```
none / scientist / engineer / security / geologist / medic / botanist / Tourist
```
- 居民属性：`colonist.specialist`（string，"none"=无专长）
- 每个专长特质 `OnApply` 自动 `colonist:SetSpecialization(trait.id)`
- `GetSpecialization(spec)` 取显示名/desc；`ColonistClasses` 映射到实体类（Scientist/Engineer/…）
- 外观由 `GetSpecialistEntity(specialist, gender, race, age_trait, traits)` 生成（专长/性别/族裔/年龄组四段拼实体名）→ **移除专长时外观会自动回到通用居民**（游戏侧 `ChooseEntity` 处理）

### 常用操作
```lua
colonist.traits.SomeTrait      -- 是否有某特质（真/假）
colonist:AddTrait("Workaholic")           -- 安全多次调用
colonist:RemoveTrait("Lazy", true)        -- 第二参 true = ignore_missing
colonist:Affect("StatusEffect_X", "start") -- 加/移除自定义状态（需 DefineClass）
colonist:SetModifier("performance", "modid", -20, 0, T{...})  -- 数值修正
colonist:SetResidence(building)  colonist:SetWorkplace(building)
UICity.labels.Colonist         -- 全体居民
UICity.labels.Unemployed       -- 当前失业
dome.labels.Colonist / dome.labels.Unemployed / dome.labels[GetTraitLabel("Lazy")]
```

### 自定义状态（StatusEffect 范例，来自 Colonists.md）
```lua
DefineClass.StatusEffect_XXX = {
	__parents = { "StatusEffect" },
	display_name = T{"XXX"},
	description = T{"..."},
}
function StatusEffect_XXX:Start(unit, start) unit:SetModifier("performance","XXX",-10) end
function StatusEffect_XXX:Stop(unit)        unit:SetModifier("performance","XXX",0,0) end
```

---

## 5. 线程与时间 API（`LuaExportedDocs\Global\thread.lua` + `LuaDoc__G.md.html`）

```lua
GameTime()                          -- 当前游戏时间(ms)
CreateGameTimeThread(function()     -- 游戏时间线程（随暂停/倍速）
	Sleep(3 * const.DayDuration)    -- Sleep 用游戏时间；const.DayDuration = const.Scale.sols
end)
CreateRealTimeThread(function() ... end)  -- 真实时间线程
WaitThread(thread, timeout)         -- 等线程
AsyncRand(n)                       -- 异步随机（MOD 里替代 math.random，别在热路径用确定性 rand）
```
`_GameConst.lua`：`const.DayDuration = const.Scale.sols`，`const.HourDuration = const.Scale.h`（默认 1 sol = 24h；游戏可改时间比例）。

---

## 6. 选项条目速查（items.lua 序列化写法）

```lua
return {
	PlaceObj('ModItemCode', { 'CodeFileName', "Code/Script.lua" }),
	PlaceObj('ModItemOptionToggle', {
		'name', "MyToggle", "DisplayName", "...", "Help", "...", "DefaultValue", true, }),
	PlaceObj('ModItemOptionNumber', {
		'name', "MyNum", "DisplayName", "...", "Help", "...",
		'DefaultValue', 3, "MinValue", 1, "MaxValue", 30, }),
	-- 可选：PlaceObj('ModItemOptionChoice', { 'name', "X", 'ChoiceList', {"a","b"}, 'DefaultValue', "a" })
}
```
- `name` = 选项 id，代码里 `CurrentModOptions.GetProperty("MyNum")` 读值。
- 选项没有 `name`（或为空）会被判无效、不显示。
- 数字选项 UI 是滑杆（`GetOptionMeta` 里 `slider=true`），`StepSize` 缺省 1。

---

## 7. 本 MOD 回顾（就业再分配）

- 逻辑：`OnMsg.NewDay` → 遍历 `UICity.labels.Unemployed` → 合格者（非 Child/Senior、有真实专长）连续计数 → 达到 `Unemployment_Redist_Sols`（默认 3）→ `RemoveTrait(specialist, true)` + `AddTrait("none")` 退回无专长 → 清计数；重新就业/死亡/读档/新局均清零。
- 计数器 `unemp_days` 为弱键表（内存级）。**已知未做**：不跨存档持久化；Tourist 目前按"有专长"处理。
- 测试方式与已通过的用例见 `AGENTS.md`。

---

## 8. 开发新功能时优先去查的清单（按需取用）

| 需求 | 去哪查 |
| --- | --- |
| 新 OnMsg 事件 | `Docs\LuaDoc_Msg.md.html` |
| 居民/特质/状态 | `Docs\Colonists.md.html` + `Docs\ModItemTrait.md.html` + `Src\Data\TraitPreset.lua` |
| 标签（找对象集合） | `Docs\LuaMarsMapsLabels.md.html`（city/dome/colony labels，含 Unemployed/Homeless…） |
| 建筑类改动 | `Docs\ModItemBuildingTemplate.md.html` + `Src\Data\BuildingTemplate\*.lua` |
| 科技 | `Docs\Research.md.html` + `Docs\ModItemTechnology.md.html` + `LuaDoc_Gameplay.md.html`（GrantTech…） |
| 作物 | `Docs\ModItemCrop.md.html`；植被 `ModItemVegetation.md.html` |
| 灾害 | 参考 "WW Constant Meteor Storms" MOD 的 Preset 查找法（`Presets.MapSettings.Meteor` / `DataInstances.MapSettings_Meteor`） |
| 全局函数（压缩/持久/定位） | `Docs\LuaDoc__G.md.html` |
| 数值修正（label modifier） | `Docs\LuaDoc_Gameplay.md.html` 的 CreateLabelModifier 章 + `LuaMarsMapsLabels.md.html` 的 Label Modifiers 章 |
| UI/弹窗 | `Docs\ModItemLocTable.md.html`（本地化）、`WaitCustomPopupNotification`（`LuaDoc__G.md.html`） |
| 玩法函数（锁建筑/改价格/送研究） | `Docs\LuaDoc_Gameplay.md.html` |

---

## 9. 已知坑（踩过/注意）

1. **没启用 MOD 就不会出现选项**：Options → "Mod Options" 页逐 MOD 检查 `items 已加载 && 有 options`，未勾选启用就整页没有。
2. **items.lua 被外部改过，编辑器保存会弹 "modified externally…overwrite?"** —— 选 Yes 覆盖即可（日志里出现 `CanSaveMod` 的 WaitQuestion）。
3. **PowerShell 跑多命令不要用 `&&`**（本机 PS 版本不支持），用 `;` 分隔。
4. **logger 里 `Mars.exe` 与 `MarsDebug.exe` 分日志文件**；`-GED-ModEditor-*` 后缀的是编辑器进程。
5. **`math.random` 慎用**：MOD 沙箱里随机数走 `AsyncRand`（见气象 MOD 范例），确定性 rand 会影响存档一致性。
6. **metadata.lua 的 `version`/`code_hash`/`steam_id` 是编辑器写的**，手改会失去上传时的 diff 提示，改完必回编辑器存一次。
7. **文档 HTML 里的 T{...}/T(...) 是本地化包装**，MOD 里写用户可见文本也用 `T{...}` 保证可翻译。
