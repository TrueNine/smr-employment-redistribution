# MOD 开发参考资料（项目专用）

> 本文件汇总本项目用到的全部外部参考与开发结论，改代码前查这里，不必再翻游戏文档。
> 权威来源路径：
> - 游戏文档：`C:\Program Files (x86)\Steam\steamapps\common\Project Spark\ModTools\Docs\`
> - 游戏公开源码：`C:\Program Files (x86)\Steam\steamapps\common\Project Spark\ModTools\Src\`（`Lua/`、`CommonLua/`、`Data/`）
> - 示例 MOD：`ModTools\Samples\Mods\`（不能直接加载，需复制到 `%AppData%\Surviving Mars Relaunched\Mods\`）

---

## 1. 本 MOD 现状速查

| 项 | 值 |
| --- | --- |
| MOD 目录 | `%AppData%\Surviving Mars Relaunched\Mods\Employment - Redistribution` |
| MOD id | `dyLFuib` |
| 创意工坊 item | `3800017811` |
| 选项 | `Enable_Unemployment_Redist`（toggle，默认 true）；`Unemployment_Redist_Sols`（number 1-30，默认 3） |
| 运行时逻辑 | 仅 `Code/Script.lua`（`ModItemCode` 载入），事件：`OnMsg.NewDay`（计数/触发）+ `OnMsg.ModsReloaded`/`OnMsg.ApplyModOptions`（读选项）+ `OnMsg.NewGame`/`OnMsg.PostLoadGame`/`OnMsg.ModUnloadLua`（清计数器） |
| 计数表 | `unemp_days`（弱键表，内存级，不跨存档） |

### 关键行为结论（已在源码/文档中核实）

1. **"无专长"的实现**：专长 = 特质组 `Specialization`；`colonist.specialist` 存专长 id；`"none"` 是特质 `No specialization`（`Data/TraitPreset.lua:612` 起，`group = "Specialization"`，`display_name = "No specialization"`，`auto = false`）。给居民 `AddTrait("none")` 时其 `OnApply` 会调用 `colonist:SetSpecialization("none")`，所以退专长 = `c:RemoveTrait(c.specialist, true)` + `c:AddTrait("none")`。
2. **有效专长全集**：`const.ColonistSpecialization`（`Src/Lua/Specialization.lua:4`），key 为 `none / scientist / engineer / security / geologist / medic / botanist / Tourist`。判断"真专长"：`c.specialist` 在 `const.ColonistSpecialization` 中且 ~= "none"。（Tourist 也可作专长出现，但 `ColonistSpecializationList` 里被移除，属于游客场景。）
3. **`SetSpecialization(spec)` 语义**（`Src/Lua/Units/Colonist.lua:3071`）：若 spec 已在 traits 中，只更新 `self.specialist` 并换模型；否则会先 `AddTrait(spec)`，切专长时 `RemoveTrait(旧)`。切换后发 `Msg("NewSpecialist", self)`。
4. **工作匹配**：建筑 `workplace.specialist` 与 `colonist.specialist` 匹配才给 `preferred_workplace_performance_bonus`，不匹配吃 `g_Consts.NonSpecialistPerformancePenalty` 惩罚（`Colonist.lua:1644` `ChangeWorkplacePerformance`）。所以把居民退成 none 后，他只能进"任意专长"岗位或接受降效率。
5. **失业判定入口**：`UICity.labels.Unemployed`（城市级）与 `dome.labels.Unemployed`（穹顶级）。`labels` 里某 label 可能不存在，必须 `or empty_table` / `or {}` 保护；取长度要写 `#(x or "")`。
6. **居民对象随时可能销毁**（死亡/回地球/克隆替换），对居民的任何调用包 `pcall`；迭代中先判断 `IsValid(c)`。
7. **年龄特质 id**：`Child` / `Youth` / `Adult` / `Middle Aged`（注意带空格）/ `Senior`，直接 `colonist.traits.<id>` 判断。
8. **事件时机**：`OnMsg.NewDay(day)` 每太阳日一次，`day` 即 `UIColony.day`。`NewGame` 新开局；`PostLoadGame` 读档完成（可做 fixup）；`LoadGame` 是读档中途。`ModUnloadLua(mod_id)` 在卸载 MOD 前。

---

## 2. OnMsg 事件全表（摘要自 `Docs/LuaDoc_Msg.md.html`）

- 每日/每小时：`OnMsg.NewDay(day)`、`OnMsg.NewHour(hour)`
- 居民：`ColonistBorn(colonist, event)`、`ColonistArrived(colonist)`、`ColonistLeavingMars(colonist, rocket)`、`ColonistDied(colonist, reason)`、`ColonistChangeWorkplace(colonist, new, old)`、`NewSpecialist(colonist)`
- 特质：`ColonistAddTrait(colonist, trait_id)` / `ColonistRemoveTrait(colonist, trait_id)`
- 状态：`ColonistStatusEffect(colonist, status_effect, bApply, now)`（如 `StatusEffect_Unemployed`、`StatusEffect_Homeless`、`StatusEffect_Earthsick`）
- MOD：`ModsReloaded()`、`ApplyModOptions(mod_id)`、`ModUnloadLua(mod_id)`、`NewGame()`、`PreLoadGame(metadata)`、`LoadGame(metadata, version)`、`PostLoadGame(metadata, version)`、`SaveGameStart()`、`ChangeMap()`
- 建筑/班次：`ConstructionComplete(building)`、`OnSetWorking(building, working)`、`NewWorkshift(workshift)`
- 火箭：`RocketLanded(rocket)`、`RocketLaunchFromEarth`、`RocketLaunched(rocket)`、`RocketLaunchedAnywhere`、`RocketReachedEarth`、`RocketStatusUpdate(rocket, status)`（status 字符串：`"on earth"` / `"arriving"` / `"in orbit"` / `"landing"` / `"landed"` / `"refueling"` / `"countdown"` / `"takeoff"` 等）
- 科技：`TechResearched(tech_id, city)`
- 灾害：`DomeHitByMeteor(dome, meteor)`
- 政治/任务：`AnomalyRevealed`/`AnomalyAnalyzed(anomaly)`、`PlanetaryAnomalySpawned`、`SpecialProjectSpawned`、`ColonyApprovalPassed`
- 选中标记：`SelectedObjChange(object, previous)`

### 自定义消息

`Msg("MyEvent", ...)` 发送；任何 MOD/游戏代码都可收发，消息名可能撞车，建议前缀 `MyMod_MyEvent`。

---

## 3. 居民（Colonist）API

（来自 `Docs/Colonists.md.html` + `Src/Lua/Units/Colonist.lua`）

- 四统计值 `0..100`：`colonist.stat_health / stat_sanity / stat_comfort / stat_morale`
- 增减：`colonist:ChangeHealth/ChangeSanity/ChangeComfort/ChangeMorale(±amount)`；文档示例统计值乘 `const.Scale.Stat` 缩放（该值通常 = 1）
- 修饰器：`colonist:SetModifier(prop, id, amount, percent, display_text)`；清零 `colonist:SetModifier(prop, id, 0, 0)`。`prop` 常用 `performance`、`base_morale`、`death_age`
- 特质：`colonist.traits.<id>`（bool）、`colonist:AddTrait(id)`（重复调用幂等）、`colonist:RemoveTrait(id, ignore_missing)`（无该特质且不 ignore 会 assert！）
- 专长：`colonist.specialist`（string，见 §1.2）
- 住所/工作：`colonist.residence`、`colonist.workplace`、`colonist:CanWork()`、`colonist:GetFired()`（主动辞职，释放岗位）
- 穹顶：`colonist.dome`（可 nil，如在外/太空）；`colonist.dome.labels.X` 访问本穹顶 label
- 状态效果表：`colonist.status_effects.<StatusEffect_*>`（存在即生效）
- 其他：`IsValid(colonist)`、`colonist:IsDying()`、`colonist:Random(100)`（带盐可复现随机）、`colonist.name`
- 穹顶内按特质查人：`dome.labels[GetTraitLabel("Lazy")]`；特质 label 名格式 `Trait<CapitalizedTrait>`（如 `TraitCoward`）

### 居民生成（`Colonist.lua:4488` 附近）

新 applicant 的 `specialist` 按 `g_Consts[spec.."_arrival_chance"]` 权重随机；`g_Consts.unskilled_arrival_chance` 决定无专长概率；`race` 1-5 对应 `ColonistRace = {"Ca","Af","As","Ar","Hs"}`。

---

## 4. 特质（Trait）机制

（`Docs/ModItemTrait.md.html`）

- 特质预设数据在 `Src/Data/TraitPreset.lua`（`PlaceObj('TraitPreset', ...)` 列表）
- 特质组（`group`）：`Age Group`、`Specialization`、`Gender`、`Perks`("Positive")、`Flaws`("Negative")、`Quirks`("other")
- 生命周期钩子：`OnApply(trait, colonist, init)` / `OnUnApply` / `DailyUpdate(trait, colonist)` / `OnEat` / `OnEatIngredients`
- 属性修饰：`modify_target`("self"/"dome colonists") + `modify_property` + `modify_amount`/`modify_percent` + `infopanel_effect_text`
- 工具函数：
  - `GetCompatibleTraits(compatible, nonerare, rare, category)` → 两表（非罕见/罕见）
  - `GetRandomTrait(compatible, nonerare, rare, category, base_only, ...)`
  - `TraitFilterColonist(trait_filter, colonist_traits)`（正数匹配 / 负数不匹配）
  - `LockTrait(name, reason)` / `UnlockTrait(name, reason)` / `IsTraitAvailable(name)`
- 兴趣服务列表：`ServiceInterestsList = {interestSocial, interestRelaxation, interestExercise, interestGaming, interestShopping, interestLuxury, interestDrinking, interestGambling, interestPlaying, interestDining, interestSafari, needFood, needMedical}`
- 定义新特质 ModItem：编辑器里加 `ModItemTrait`

### 本 MOD 相关

专长特质（scientist 等）注册在 `const.ColonistSpecialization`（§1.2）；`none` 特质的 `OnApply` 调 `SetSpecialization("none")`（源码 `Data/TraitPreset.lua:628`）。

---

## 5. 选项（ModItemOption）机制

（`Docs/ModItemOption.md.html` + `Docs/ModItemCode.md.html`）

- 类型：`ModItemOptionToggle`（on/off）、`ModItemOptionNumber`（滑块，Min/Max）、choice（字符串列表）
- `name` 是 Lua 读取键，**三处必须一致**：`items.lua` 的 `name`、`Code/Script.lua` 的键、`metadata.lua` 的 `default_options` 键（见 AGENTS.md 规则 1）
- 游戏内读取：`CurrentModOptions:GetProperty("OptionName")`；兜底默认值放脚本本地表
- 变更事件：`OnMsg.ApplyModOptions(mod_id)`（玩家点 Apply）+ `OnMsg.ModsReloaded()`（加载/热重载）
- 选项存于自动生成的 `options.lua` 类里，改选项结构注意向后兼容；无 `name` 的选项无效
- `CurrentModId` / `CurrentModPath` 全局可用；不鼓励用 `CurrentModOptions` 回写选项值

---

## 6. Labels（标签系统）

（`Docs/LuaMarsMapsLabels.md.html`）

- 城市：`UICity.labels.<Label>`；穹顶：`dome.labels.<Label>`；全殖民地：`UIColony.city_labels.labels.<Label>`
- 手动挂标签：`UICity:AddToLabel("MyLabel", obj)`（隐式同步到 colony label）；`LabelContainer:InitEmptyLabel(name)` 预建空表
- 常用城市 label：`Colonist`、`Unemployed`、`Homeless`、`DeadColonist`、`Building`、`BuildingNoDomes`、`Workplace`、`ResearchLab`、`TrainingBuilding`、`ResourceProducer/Exploiter`、`Drone`、`Rover`、`Suspended`（尘暴停工）、`OutsideBuildings`/`InsideBuildings`……；每栋建筑还会出现在其类名/模板名/建菜单类别名的 label 里；建造中对象额外带 `<Label>_Construction` 后缀 label
- 穹顶级 label：`Colonist`、`Unemployed`、`Homeless`、`Building`、`Residence`、`Spire`、`Service`；`interest<Service>` 形式（如 `interestPlaying`）
- Label 修饰器（批量改某 label 下所有对象属性）：
  ```lua
  local m = LabelModifier:new{container = dome, label = "Building", id = "MyMod",
                              prop = "performance", amount = 10, percent = 10,
                              display_text = T{...}}
  dome:SetLabelModifier("Building", m.id, m)   -- 加
  dome:SetLabelModifier("Building", m.id)       -- 删（只传 id）
  ```
- 公式：`final = original * (100 + total_percent)/100 + total_amount`（percent 10 = 10%）
- 城市级便捷封装：`CreateLabelModifier(id, label, prop, amount, percent)` / `ChangeLabelModifier` / `RemoveLabelModifier`（见 §11）

### 地图/City 全局变量

`MainMap`（地表，恒存在）、`UndergroundMap`、`CurrentMap`、`UICity`（当前地图城市）、`Cities`/`LoadedMaps`（数组）、`UIColony`（`UIColony.day`/`.hour`/`.funds`/`.asteroids`…）。小行星地图：`UIColony.asteroids[i]` 是 descriptor，未生成前只有 descriptor，生成后 `.map` 可访问。

---

## 7. 时间 / const 关键常量

（`Src/Lua/_GameConst.lua` + `CommonLua/Core/const.lua`）

- `const.DayDuration` = `const.Scale.sols`（1 个太阳日的游戏时间单位）；`const.HoursPerDay` = `Scale.sols / Scale.h`（默认 24 小时/日）；`const.HourDuration` = `Scale.h`
- `const.Scale` 基础度量在 `CommonLua/Core/const.lua:60`（`km/m/cm/deg/sec/min` 等）；`Scale.sols`/`Scale.h` 的默认值由 C 侧或游戏选项（时间速度）决定，Lua 里没有再赋值。`Sleep(3 * const.DayDuration)` = 3 个太阳日（游戏内线程）。
- 其它常用：`const.ResearchPointsScale` = 1000、`const.ReconPointsScale` = 1000、`const.SoilQualityScale` = 100、`const.Scale.Stat`（统计值缩放，通常 =1）、`const.DefaultAutosaveIntervalScale`（=1 个太阳日）
- 真实时钟线程：`CreateRealTimeThread(fn)`；游戏时钟线程：`CreateGameTimeThread(fn)`；`GameTime()` 返回当前游戏时间
- 本地化字符串：`T(id, "text")` 或 `T{id, "templ <x>", x = ...}`；`Untranslated("...")` 直出

---

## 8. 线程与消息（Threads / Messages）

- 协作线程基于协程：`CreateGameTimeThread(function() Sleep(ms) ... end)`；`Sleep` 单位同 `GameTime()`（游戏毫秒，受游戏速度影响）
- `WaitThread(thread, timeout)` → `in_time, finished, ...`
- 命名流程挂起/恢复：`SuspendProcessing(map, process, reason, ignore_errors)` / `ResumeProcessing(map, process, reason, ignore_errors)` / `IsProcessingSuspended`
- 类生命周期消息（改 classdef 用）：`OnMsg.ClassesPreprocess/Generate/PreBuilt/PostBuilt/Postprocess`

---

## 9. 持久化数据（跨存档/跨会话）

（`Docs/ModItemCode.md.html`）

- **MapVar**：随地图初始化、随存档保存、切图清空重建。适合"本存档内的数据"。注意：在 MOD 编辑器里热加载不会初始化 table 型 MapVar（没有地图切换），需重启编辑器地图
- **`WriteModPersistentData(mod, data)` / `ReadModPersistentData(mod)`**：跨游戏会话的每-MOD 持久存储，`data` 必须是 string（≤ `const.MaxModDataSize`），通常配 `Compress/Decompress` 或 `AsyncCompress` 存序列化数据；`WriteModPersistentStorageTable(mod)` 是便捷封装
- 序列化任意值：`TupleToLuaCode(values...)` → 可执行代码串；`LuaCodeToTuple(code, env)` 反向；`ValueToLuaCode(value, indent)`

---

## 10. 常用全局函数速查（`Docs/LuaDoc__G.md.html`）

- 压缩/解压：`Compress/Decompress`（LZ4）、`AsyncCompress/AsyncDecompress`（ZSTD，默认算法）、`AsyncSerializeAndCompress`/`AsyncDecompressAndUnserialize`
- 随机：`Random(a, b, salt)`、`InteractionRand(n, seed)`、`AsyncRand()`
- 对象：`IsValid(obj)`、`IsValidPos`/`IsValidZ`、`FindNearestObject(list, pt, filter)`、`GetDomeAtHex/GetDomeAtPoint`、`IsObjInDome`、`IsUnitInDome`
- 地形/网格：`GetVoxelHeight`、`IsTerrainFlat`、`GetPassablePointNearby`；hex 轴向坐标 `q, r`
- 特效/声音：`PlayFX(action, moment, actor, target, pos, dir)`、`PlaySound(name, ...)`、`RGB/RGBA(r,g,b[,a])`
- 定位 UI：`ResolveUILocation(preset, params, dlg)`
- 弹框等待：`WaitCustomPopupNotification(title, text, choices, parent)`（必须在 GameTime 线程内调用）
- 集合工具：`array_set()`（有序集合）、`sync_set()`（同步集合）、`ripairs(arr)`（可安全删元素的反向迭代）、`table.find(t, key, value)`、`table.keys2(t, ...)`、`table.weighted_rand(weights, ...)`、`table.map(t, fn)`
- 哈希：`xxhash(...)`
- 检查 DLC：`IsDlcAvailable("dlc_id")`（DLC 是安装目录 `DLC/` 下的 `.hpk`，文件名 = id）
- 检查其他 MOD 是否加载：`ModsLoaded` 表 + `table.find(ModsLoaded, "id", mod_id)`

## 11. 游戏性函数（`Docs/LuaDoc_Gameplay.md.html`）

- 资金：`ChangeFunding(±value_M, "source")`（单位百万）；`UIColony.funds:ChangeFunding(...)`
- 科研：`GrantResearchPoints(n)`、`GrantReconPoints(n)`、`GrantTech(tech_id)`、`IsTechResearched`（返回次数或 nil）/`IsTechUnlocked`/`IsTechRepeatable`、`BoostTech(tech, percent)`/`BoostTechField(field, percent)`（field 传 `""` = 全部）
- 建造：`LockBuilding(class, "hide"/"disable", reason)` / `UnlockBuilding(class)` / `RemoveBuildingLock(class)`；`ModifyConstructionCost(building_or_category, resource, percent)`（资源用 `GroupResourceIds.ConstructionResources = {Concrete, Metals, Polymers, BlackCube, Electronics, MachineParts, PreciousMetals}` 或 `"all"`）
- 补给：`ModifyResupplyParam(id, "price"/"weight", percent)`、`ModifyResupplyParams(param, percent)`、`LockImport/UnlockImport(item, lock_id)`、`LockCrop/UnlockCrop`、`LockVegetationPlant/UnlockVegetationPlant`、`IsCropAvailable`
- 特质锁：`LockTrait/UnlockTrait/IsTraitAvailable`
- 升级：`UnlockUpgrade(upgrade_id)`
- Label 修饰器便捷封装：`CreateLabelModifier(id, label, prop, amount, percent)` / `ChangeLabelModifier(id, label, prop, new_amount, new_percent)` / `RemoveLabelModifier(id, label, prop)`（id 全局唯一，跨 MOD 也要不撞）

---

## 12. 类系统 / MOD 条目

- `DefineClass.MyMod_Thing = { __parents = {...}, properties = {...} }`；**类名与消息名加前缀防撞名**（文档明确建议）
- 消息反应两种写法：`OnMsg.<Event>` 直接赋值函数（本项目用法）；非 ModItem 形式也可
- `ModItemCode`：载入单个 `.lua` 文件（本项目即 `Code/Script.lua`）；`CurrentModPath` 指向 MOD 根
- ModItem 清单（`Docs/index.md.html`）：Code / Option / Trait / Entity / BuildingTemplate / GameRule / StoryBit / Technology / MissionSponsor / CommanderProfile / Crop / Animal / Vegetation / RadioStation / Sound / 各 ActionFX / TechField / LocTable / ColonyColorScheme / MissionLogo / Lightmodel / Attachment / BuildMenuSubcategory
- 预设替换规则：同 Id 的 ModItem 预设**替换**游戏自带预设（如新增 Mission Sponsor 用 `ESA` 会覆盖原 ESA）
- 预设继承：编辑器里 `Copy from group` / `Copy from` 可直接复制现有预设属性（会覆盖同名属性，注意备份）
- StoryBit（随机事件）：`ModItemStoryBit`，Category = "Tick" 的会被周期性小概率随机执行；做随机事件前读 `Docs/ModItemStoryBit.md.html`
- MOD 依赖：metadata 的 `Dependencies`（最小 major.minor，可标 optional），依赖方先加载

---

## 13. 本项目的坑与约定

1. **弱键表**：`unemp_days = setmetatable({}, {__mode="k"})`——居民 C 对象销毁后条目自动消失；但"重新就业"不会自动清，所以 `NewDay` 里对不在 `Unemployed` label 的键做清理（`CleanupCounters`）。
2. **清理顺序**：先加计数（可能触发退专长），再清掉不在场的键——顺序反了会误清刚触发者。
3. **`empty_table`** 是游戏全局空表，label 缺省保护用。
4. **触发失败重试**：`ResetSpecialization` 返回 false 时保留计数，下个太阳日再试。
5. **`IsValid` 保护**：居民在 `NewDay` 迭代中可能已死，成员访问前先 `IsValid(c)`。
6. **调试**：`Script.lua` 顶部 `DEBUG = true`，控制台前缀 `[EmploymentRedist]`；游戏内按 Enter 开调试控制台（MarsDebug.exe），可执行任意 Lua 查状态。
7. **VS Code 调试**：装 `ModTools/SolEngineLua.vsix`，打开 `ModTools/Src/ModTools.code-workspace`，F5 附加；支持断点/Log Point/表达式求值（Alt-E）。语法检查装 sumneko.lua。
8. **发布**：改 `items.lua`/`Script.lua` → 游戏 MOD 编辑器保存（自动升 version、刷 `code_hash`/`saved`/`steam_id`，别手改这些字段）→ 编辑器上传工坊。`last_changes` 保持一句话。
9. **不要手改** `metadata.lua` 的 `lua_revision` / `saved_with_revision` / `code_hash` / `saved`。

## 14. 新功能方向备忘（下一步可用）

- **持久化计数**（跨读档不丢）：MapVar（随存档）或 `WriteModPersistentData`（跨会话，字符串序列化）
- **退专长公告**：`WaitCustomPopupNotification`（GameTime 线程）或 OnScreenNotification 机制（`Src/Lua/UI/OnScreenNotification.lua`）
- **按穹顶统计/批量效果**：`dome.labels.Unemployed` + LabelModifier / `SetLabelModifier`
- **随机事件（StoryBit）**：`ModItemStoryBit` + Msg Reactions，参考 `ForeignerInAForeignLand` 示例 MOD
- **新特质**：`ModItemTrait` 预设 + `OnApply/OnUnApply/DailyUpdate` 钩子；兴趣服务用 `interest*` 常量表（§4）
- **科研/资源类效果**：§11 的 Grant*/Modify* 函数
- **多 MOD 协作**：自定义消息名加前缀；`ModsLoaded` 检测依赖
- **示例 MOD 学习**：`ModTools\Samples\Mods\` 下 BulgarianSpaceProgram（赞助/派系/开局载荷）、CactusCrop（作物交互）、Cemetery（建筑逻辑 + 居民交互 + ActionFX）、Idiocracy（游戏规则）、MedicalResearcher（指挥官档案）、ShadowedSolarPanels（地形遮蔽判定）、ForeignerInAForeignLand（StoryBit 全特性）
