# 位数据合并功能

## 功能说明

当同一个 section 中存在多个同名的 key，并且名称格式为 `key.subkey` 时，如果类型是整数（包括二进制），则会自动合并（按位或操作）为一个值。

## 使用示例

### 基本用法（默认 u8 类型）

```ini
flags.a=0b00000001
flags.b=0b00000010
flags.c=0b00000100
flags.d=4
```

读取合并后的值：

```zig
const value = try config.getU8("flags"); // 返回 7 (0b00000111)
```

### 显式类型标识

```ini
permissions.read:u16=1
permissions.write:u16=2
permissions.execute:u16=4
permissions.delete:u16=8
```

读取合并后的值：

```zig
const value = try config.getU16("permissions"); // 返回 15
```

### Section 中的位合并

```ini
[user_perms]
user.read=1
user.write=2
user.execute=4
```

读取合并后的值：

```zig
const value = try config.getSectionU8("user_perms", "user"); // 返回 7
```

### 嵌套键（支持多个 `.`）

```ini
file.owner.read=0b100000000
file.owner.write=0b010000000
file.owner.execute=0b001000000
```

读取合并后的值：

```zig
const value = try config.getU32("file.owner"); // 返回合并后的值
```

## 特性

1. **自动类型推断**：如果没有显式指定类型，默认使用 u8 类型。如果合并后的值超过 u8 范围，会自动升级到合适的类型（u16、u32、u64）

2. **支持所有整数类型**：u8、u16、u32、u64、i8、i16、i32、i64

3. **支持不同进制**：可以混合使用十进制、二进制（0b）和十六进制（0x）

4. **使用最后的 `.` 作为分隔符**：对于嵌套键如 `file.owner.read`，只有最后一个 `.` 用于分隔位标识

## 实际应用场景

- 文件权限管理（owner/group/others 的 r/w/x 权限）
- 硬件寄存器配置（GPIO、中断使能等）
- 特性标志管理
- 配置选项的组合
