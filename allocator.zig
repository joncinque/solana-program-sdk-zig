const std = @import("std");

const heap_start = @as([*]u8, @ptrFromInt(0x300000000));
const heap_length = 32 * 1024;

pub const allocator: std.mem.Allocator = @constCast(&ReverseFixedBufferAllocator.comptimeInit(heap_start[0..heap_length])).allocator();

const ReverseFixedBufferAllocator = struct {
    buffer: []u8,

    fn isLastAllocation(self: *ReverseFixedBufferAllocator, buf: []u8) bool {
        return buf.ptr == self.buffer.ptr + self.end_index().*;
    }

    fn end_index(self: *ReverseFixedBufferAllocator) *usize {
        const cutoff = self.buffer.len - @sizeOf(usize);
        return @as(*usize, @ptrCast(@alignCast(self.buffer[cutoff..])));
    }

    pub fn comptimeInit(buffer: []u8) ReverseFixedBufferAllocator {
        return ReverseFixedBufferAllocator{
            .buffer = buffer,
        };
    }

    pub fn init(buffer: []u8) ReverseFixedBufferAllocator {
        const cutoff = buffer.len - @sizeOf(usize);
        var end = @as(*usize, @ptrCast(@alignCast(buffer[cutoff..])));
        end.* = cutoff;
        return ReverseFixedBufferAllocator{
            .buffer = buffer,
        };
    }

    pub fn allocator(self: *ReverseFixedBufferAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = ReverseFixedBufferAllocator.alloc,
                .resize = std.mem.Allocator.noResize,
                .free = ReverseFixedBufferAllocator.free,
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

        const self: *ReverseFixedBufferAllocator = @ptrCast(@alignCast(ctx));
        if (self.end_index().* == 0) {
            const cutoff = self.buffer.len - @sizeOf(usize);
            var end = @as(*usize, @ptrCast(@alignCast(self.buffer[cutoff..])));
            end.* = cutoff;
        }
        const ptr_align = @as(usize, 1) << @as(std.mem.Allocator.Log2Align, @intCast(log2_ptr_align));
        const buffer_address = @intFromPtr(self.buffer.ptr);
        var new_end_address = buffer_address + self.end_index().* - n;
        new_end_address &= ~(ptr_align - 1);
        if (new_end_address - buffer_address < @sizeOf([*]u8)) {
            return null;
        }
        const new_end_index = new_end_address - buffer_address;
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
        const self: *ReverseFixedBufferAllocator = @ptrCast(@alignCast(ctx));
        _ = return_address;

        if (!self.isLastAllocation(buf)) {
            if (new_size > buf.len) return false;
            return true;
        }

        const ptr_align = @as(usize, 1) << @as(std.mem.Allocator.Log2Align, @intCast(log2_buf_align));

        if (new_size <= buf.len) {
            const sub = buf.len - new_size;
            var new_end_index = self.end_index().* + sub;
            new_end_index &= ~(ptr_align - 1);
            self.end_index().* = new_end_index;
            return true;
        }

        const add = new_size - buf.len;
        if (add > self.end_index().*) {
            return false;
        }
        var new_end_index = self.end_index().* - add;
        new_end_index &= ~(ptr_align - 1);
        self.end_index().* = new_end_index;
        return true;
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        return_address: usize,
    ) void {
        var self: *ReverseFixedBufferAllocator = @ptrCast(@alignCast(ctx));
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
    var bump_allocator = ReverseFixedBufferAllocator.init(&test_bump_allocator_memory);

    try std.heap.testAllocator(bump_allocator.allocator());
    try std.heap.testAllocatorAligned(bump_allocator.allocator());
    try std.heap.testAllocatorLargeAlignment(bump_allocator.allocator());
    try std.heap.testAllocatorAlignedShrink(bump_allocator.allocator());
}
