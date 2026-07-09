const std = @import("std");
const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;

pub fn create_peripheral_enum(comptime base_name: []const u8, match_type: ?[]const u8) type {
    const base_len = base_name.len;
    var names: [10]std.builtin.Type.EnumField = undefined;
    var names_index = 0;
    var num_index = 0;
    const peripheral = @typeInfo(peripherals);
    switch (peripheral) {
        .@"struct" => |data| {
            for (data.decls) |decls| {
                const decl_name = decls.name;
                const type_name = @typeName(@TypeOf(@field(peripherals, decl_name)));
                if (std.mem.indexOf(u8, decl_name, base_name)) |base_index| {
                    num_index = base_index + base_len;
                    if (match_type) |match| {
                        _ = std.mem.indexOf(u8, type_name, match) orelse continue;
                    }
                    const peri_num = std.fmt.parseInt(usize, decl_name[num_index..], 10) catch names_index;
                    names[names_index] = std.builtin.Type.EnumField{
                        .name = decls.name,
                        .value = peri_num,
                    };
                    names_index += 1;
                }
            }
        },
        else => unreachable,
    }

    var enum_names: [names.len][:0]const u8 = undefined;
    var enum_values: [names.len]usize = undefined;
    for (names[0..names_index], 0..) |ef, i| {
        enum_names[i] = ef.name;
        enum_values[i] = ef.value;
    }
    return @Enum(usize, .exhaustive, enum_names[0..names_index], enum_values[0..names_index]);
}

pub fn set_reg_field(reg: anytype, comptime field_name: anytype, value: anytype) void {
    var temp = reg.read();
    @field(temp, field_name) = value;
    reg.write(temp);
}
