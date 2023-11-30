const std = @import("std");

const heap_start = @as([*]u8, @ptrFromInt(0x300000000));
const heap_length = 32 * 1024;

pub const allocator: std.mem.Allocator = .{
    .ptr = @as(*Allocator, @ptrCast(@alignCast(heap_start))),
    .vtable = &.{
        .alloc = Allocator.allocFn,
        .resize = Allocator.resizeFn,
        .free = Allocator.freeFn,
    },
};

const Allocator = struct {
    end_index: usize,

    fn isLastAllocation(self: Allocator, buf: []u8) bool {
        return buf.ptr + buf.len == heap_start + self.end_index;
    }

    fn allocFn(
        ctx: *anyopaque,
        n: usize,
        log2_ptr_align: u8,
        return_address: usize,
    ) ?[*]u8 {
        _ = return_address;

        const self = @as(*Allocator, @ptrCast(@alignCast(ctx)));
        if (self.end_index == 0) {
            self.end_index = comptime std.mem.alignPointerOffset(heap_start, @alignOf(Allocator)).? + @sizeOf(Allocator);
        }

        const ptr_align = @as(usize, 1) << @as(std.mem.Allocator.Log2Align, @intCast(log2_ptr_align));
        const offset = std.mem.alignPointerOffset(heap_start + self.end_index, ptr_align) orelse {
            return null;
        };

        const adjusted_index = self.end_index + offset;
        const new_end_index = adjusted_index + n;

        if (new_end_index > heap_length) {
            return null;
        }
        self.end_index = new_end_index;

        return heap_start + adjusted_index;
    }

    fn resizeFn(
        ctx: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        new_size: usize,
        return_address: usize,
    ) bool {
        _ = log2_buf_align;
        _ = return_address;

        const self = @as(*Allocator, @ptrCast(@alignCast(ctx)));
        if (self.end_index == 0) {
            self.end_index = comptime std.mem.alignPointerOffset(heap_start, @alignOf(Allocator)).? + @sizeOf(Allocator);
        }

        if (!self.isLastAllocation(buf)) {
            if (new_size > buf.len) {
                return false;
            }
            return true;
        }

        if (new_size <= buf.len) {
            const sub = buf.len - new_size;
            self.end_index -= sub;
            return true;
        }

        const add = new_size - buf.len;
        if (add + self.end_index > heap_length) {
            return false;
        }
        self.end_index += add;
        return true;
    }

    fn freeFn(
        ctx: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        return_address: usize,
    ) void {
        _ = log2_buf_align;
        _ = return_address;
        const self = @as(*Allocator, @ptrCast(@alignCast(ctx)));
        if (self.isLastAllocation(buf)) {
            self.end_index -= buf.len;
        }
    }
};
