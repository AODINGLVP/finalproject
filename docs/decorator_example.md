# Decorator 示例说明

## 示例行为树

当前敌人使用的行为树示例文件：

```text
testgame/testgame/behavior_trees/enemy_patrol_combat.tres
```

在 Godot 行为树插件中加载：

```text
res://behavior_trees/enemy_patrol_combat.tres
```

这棵树用于控制测试场景中的敌人。为了保证 Demo 稳定，默认示例只使用 Blackboard Decorator，不再把 Cooldown Decorator 挂到攻击节点上。

## 示例结构

```text
Root
  Repeat Forever
    Combat Selector
      Attack Left
        Decorator: Player In Range
        Decorator: Player On Left
      Attack Right
        Decorator: Player In Range
        Decorator: Player On Right
      Patrol Sequence
        Move Left
        Move Right
```

## 执行逻辑

`Combat Selector` 每次 tick 都会从左到右重新检查子节点：

1. 如果玩家在攻击范围内，并且在敌人左侧，执行 `attack_left`。
2. 否则如果玩家在攻击范围内，并且在敌人右侧，执行 `attack_right`。
3. 如果两个攻击分支的 Decorator 都不满足，执行巡逻分支。

伪代码：

```text
if player_in_range and player_on_left:
    attack_left
elif player_in_range and player_on_right:
    attack_right
else:
    move_left
    move_right
```

## Blackboard Decorator 示例

示例参数：

```json
{
  "mode": "blackboard",
  "blackboard_key": "player_in_range",
  "operator": "equals",
  "value": true,
  "invert": false
}
```

含义：

```text
只有 blackboard["player_in_range"] == true 时，节点才允许执行。
```

示例树中使用的黑板变量：

```text
player_in_range
player_on_left
player_on_right
```

这些值由 `scripts/enemy_actor.gd` 在运行时更新。

## 当前 Decorator 支持的模式

运行时支持以下基础 Decorator：

```text
blackboard
cooldown
time_limit
invert
always_success
always_failure
force_success
force_failure
succeeder
failer
repeat_forever
```

其中默认敌人示例当前只使用 `blackboard` 和 `repeat_forever`。

## Blackboard Decorator 支持的 operator

```text
equals
==
not_equals
!=
greater
>
less
<
greater_or_equal
>=
less_or_equal
<=
exists
is_set
not_exists
is_not_set
is_true
is_false
```

## 如何验证 Decorator 正常运行

1. 打开 Godot。
2. 打开底部 `Behavior Tree` 面板。
3. 在 `Resource Path` 输入：

```text
res://behavior_trees/enemy_patrol_combat.tres
```

4. 点击 `Load Tree`。
5. 确认 `Live Debug` 勾选。
6. 运行测试场景：

```text
res://scenes/test_game.tscn
```

7. 控制玩家靠近敌人左侧或右侧。

预期结果：

- 玩家在左侧且进入攻击范围时，`Attack Left` 分支会执行。
- 玩家在右侧且进入攻击范围时，`Attack Right` 分支会执行。
- 玩家离开攻击范围时，攻击分支的 Blackboard Decorator 失败，敌人进入 `Patrol Sequence`。
- Live Debug 中应能看到当前执行链条在攻击分支和巡逻分支之间切换。

## Cooldown Decorator 说明

`cooldown` Decorator 仍然作为运行时能力保留，但暂时不放进默认敌人 Demo，避免影响基础攻击演示。

示例参数：

```json
{
  "mode": "cooldown",
  "duration": 0.8
}
```

含义：

```text
节点启动后，需要等待指定时间才能再次启动。
```

当前实现已经处理 `RUNNING` 状态：如果动作已经开始执行，cooldown 不会在动作执行到一半时把它打断。

## 对毕业设计的说明价值

这个示例可以证明：

- 行为树可以根据黑板数据做决策。
- Decorator 可以作为节点执行前的条件过滤器。
- Selector 会根据 Decorator 的成功或失败选择不同分支。
- Live Debug 可以观察当前执行路径。

因此，这个示例适合作为毕业设计中 “Decorator 功能验证” 的基础演示案例。
