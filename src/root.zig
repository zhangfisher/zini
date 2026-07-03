//! zini - INI 文件解析库
//!
//! 这是一个简洁高效的 INI 格式配置文件处理库
//!
//! 主要特性:
//! - 支持 Sections 和全局键值对
//! - 支持注释（; 和 #）
//! - 支持引号字符串
//! - 自动类型推断 (bool, int, float, string)
//! - 类型安全的值访问
//! - 简单直观的 API 设计

const std = @import("std");

// 导出类型模块
pub const types = @import("types.zig");
pub const DataType = types.DataType;

// 导出 INI 模块
pub const ini = @import("ini.zig");

// 重新导出主要类型以便用户直接使用
pub const Ini = ini.Ini;
pub const Section = ini.Section;
pub const Schema = ini.Schema;
pub const Error = ini.Error;

test "root module test" {
    // 简单的测试确保模块可以正确导入
    const testing = std.testing;
    _ = Ini;
    _ = Section;
    _ = Schema;
    _ = Error;
    _ = DataType;
    try testing.expect(true);
}
