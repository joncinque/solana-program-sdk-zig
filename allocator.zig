const std = @import("std");

const heap_start = @as([*]u8, @ptrFromInt(0x300000000));
const heap_length = 32 * 1024;

pub const allocator: std.mem.Allocator = @constCast(&BumpAllocator.comptimeInit(heap_start[0..heap_length])).allocator();

const BumpAllocator = struct {
    buffer: []u8,

    fn isLastAllocation(self: *BumpAllocator, buf: []u8) bool {
        return buf.ptr == self.buffer.ptr + self.end_index().*;
    }

    fn end_index(self: *BumpAllocator) *usize {
        const cutoff = self.buffer.len - @sizeOf(usize);
        return @as(*usize, @ptrCast(@alignCast(self.buffer[cutoff..])));
    }

    pub fn comptimeInit(buffer: []u8) BumpAllocator {
        return BumpAllocator{
            .buffer = buffer,
        };
    }

    pub fn init(buffer: []u8) BumpAllocator {
        const cutoff = buffer.len - @sizeOf(usize);
        var end = @as(*usize, @ptrCast(@alignCast(buffer[cutoff..])));
        end.* = cutoff;
        return BumpAllocator{
            .buffer = buffer,
        };
    }

    pub fn allocator(self: *BumpAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = BumpAllocator.alloc,
                .resize = BumpAllocator.resize,
                .free = BumpAllocator.free,
            },
        };
    }

    fn alloc(
        ctx: *anyopaque,
        n: usize,
        log2_ptr_align: u8,
        return_address: usize,
    ) ?[*]u8 {
        _ = return_address;

        const self: *BumpAllocator = @ptrCast(@alignCast(ctx));
        if (self.end_index().* == 0) {
            const cutoff = self.buffer.len - @sizeOf(usize);
            var end = @as(*usize, @ptrCast(@alignCast(self.buffer[cutoff..])));
            end.* = cutoff;
        }
        const ptr_align = @as(usize, 1) << @as(std.mem.Allocator.Log2Align, @intCast(log2_ptr_align));
        var new_end_index = self.end_index().* - n;
        new_end_index &= ~(ptr_align - 1);
        if (new_end_index < @sizeOf([*]u8)) {
            return null;
        }
        self.end_index().* = new_end_index;

        return @ptrCast(self.buffer[new_end_index .. new_end_index + n]);
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        new_size: usize,
        return_address: usize,
    ) bool {
        const self: *BumpAllocator = @ptrCast(@alignCast(ctx));
        _ = log2_buf_align;
        _ = return_address;

        if (!self.isLastAllocation(buf)) {
            if (new_size > buf.len) return false;
            return true;
        }

        if (new_size <= buf.len) {
            const sub = buf.len - new_size;
            self.end_index().* += sub;
            return true;
        }

        const add = new_size - buf.len;
        if (add > self.end_index().*) {
            return false;
        }
        self.end_index().* -= add;
        return true;
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        return_address: usize,
    ) void {
        var self: *BumpAllocator = @ptrCast(@alignCast(ctx));
        _ = log2_buf_align;
        _ = return_address;

        if (self.isLastAllocation(buf)) {
            self.end_index().* += buf.len;
        }
    }
};

const test_size = 800000 * @sizeOf(u64);
var test_bump_allocator_memory: [test_size]u8 = undefined;
test "bump_allocator" {
    var bump_allocator = BumpAllocator.init(&test_bump_allocator_memory);

    try std.heap.testAllocator(bump_allocator.allocator());
    try std.heap.testAllocatorAligned(bump_allocator.allocator());
    try std.heap.testAllocatorLargeAlignment(bump_allocator.allocator());
    try std.heap.testAllocatorAlignedShrink(bump_allocator.allocator());
}
