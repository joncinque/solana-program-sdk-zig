const std = @import("std");
const assert = std.debug.assert;

const heap_start = @as([*]u8, @ptrFromInt(0x300000000));
const heap_length = 32 * 1024;

pub const reverse_allocator: std.mem.Allocator = @constCast(&ReverseFixedBufferAllocator.comptimeInit(heap_start[0..heap_length])).allocator();
pub const allocator: std.mem.Allocator = @constCast(&FixedBufferAllocator.comptimeInit(heap_start[0..heap_length])).allocator();

// Just like std.heap.FixedBufferAllocator, with a few key differences:
// * The current end index used by allocations is stored in the first `usize`
// bytes of the provided buffer, allowing it to be used in `comptime` contexts
pub const FixedBufferAllocator = struct {
    buffer: []u8,

    fn end_index(self: *FixedBufferAllocator) *usize {
        return @as(*usize, @ptrCast(@alignCast(self.buffer[0..@sizeOf(usize)])));
    }

    pub fn comptimeInit(buffer: []u8) FixedBufferAllocator {
        return FixedBufferAllocator{
            .buffer = buffer,
        };
    }

    pub fn init(buffer: []u8) FixedBufferAllocator {
        var fba = FixedBufferAllocator{
            .buffer = buffer,
        };
        fba.end_index().* = @sizeOf(usize);
        return fba;
    }

    /// *WARNING* using this at the same time as the interface returned by `threadSafeAllocator` is not thread safe
    pub fn allocator(self: *FixedBufferAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn ownsSlice(self: *FixedBufferAllocator, slice: []u8) bool {
        return sliceContainsSlice(self.buffer, slice);
    }

    /// NOTE: this will not work in all cases, if the last allocation had an adjusted_index
    ///       then we won't be able to determine what the last allocation was.  This is because
    ///       the alignForward operation done in alloc is not reversible.
    pub fn isLastAllocation(self: *FixedBufferAllocator, buf: []u8) bool {
        return buf.ptr + buf.len == self.buffer.ptr + self.end_index().*;
    }

    fn alloc(ctx: *anyopaque, n: usize, log2_ptr_align: u8, ra: usize) ?[*]u8 {
        const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
        _ = ra;

        if (self.end_index().* == 0) {
            self.end_index().* = @sizeOf(usize);
        }

        const ptr_align = @as(usize, 1) << @as(std.mem.Allocator.Log2Align, @intCast(log2_ptr_align));
        const current_end_index = self.end_index().*;
        const adjust_off = std.mem.alignPointerOffset(self.buffer.ptr + current_end_index, ptr_align) orelse return null;
        const adjusted_index = current_end_index + adjust_off;
        const new_end_index = adjusted_index + n;
        if (new_end_index > self.buffer.len) return null;
        self.end_index().* = new_end_index;
        return self.buffer.ptr + adjusted_index;
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        new_size: usize,
        return_address: usize,
    ) bool {
        const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
        _ = log2_buf_align;
        _ = return_address;
        assert(@inComptime() or self.ownsSlice(buf));

        if (!self.isLastAllocation(buf)) {
            if (new_size > buf.len) return false;
            return true;
        }

        if (new_size <= buf.len) {
            const sub = buf.len - new_size;
            self.end_index().* -= sub;
            return true;
        }

        const add = new_size - buf.len;
        if (add + self.end_index().* > self.buffer.len) return false;

        self.end_index().* += add;
        return true;
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        log2_buf_align: u8,
        return_address: usize,
    ) void {
        const self: *FixedBufferAllocator = @ptrCast(@alignCast(ctx));
        _ = log2_buf_align;
        _ = return_address;
        assert(@inComptime() or self.ownsSlice(buf));

        if (self.isLastAllocation(buf)) {
            self.end_index().* -= buf.len;
        }
    }

    pub fn reset(self: *FixedBufferAllocator) void {
        self.end_index().* = @sizeOf(usize);
    }
};

fn sliceContainsSlice(container: []u8, slice: []u8) bool {
    return @intFromPtr(slice.ptr) >= @intFromPtr(container.ptr) and
        (@intFromPtr(slice.ptr) + slice.len) <= (@intFromPtr(container.ptr) + container.len);
}

// Just like std.heap.FixedBufferAllocator, with a few key differences:
// * Allocations start at the high address and go down
// * The current end index used by allocations is stored in the final `usize`
// bytes of the provided buffer, allowing it to be used in `comptime` contexts
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
                .free = ReverseFixedBufferAllocator.free,
                // For an allocator that grows from high addresses to low, it
                // isn't possible to resize without rewriting all the memory at
                // the new lower address, so we just omit it here
                .resize = std.mem.Allocator.noResize,
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
var test_fixed_buffer: [test_size]u8 = undefined;
test "ReverseFixedBufferAllocator" {
    var bump_allocator = ReverseFixedBufferAllocator.init(&test_fixed_buffer);

    try std.heap.testAllocator(bump_allocator.allocator());
    try std.heap.testAllocatorAligned(bump_allocator.allocator());
    try std.heap.testAllocatorLargeAlignment(bump_allocator.allocator());
    try std.heap.testAllocatorAlignedShrink(bump_allocator.allocator());
}

test "FixedBufferAllocator" {
    var bump_allocator = FixedBufferAllocator.init(&test_fixed_buffer);

    try std.heap.testAllocator(bump_allocator.allocator());
    try std.heap.testAllocatorAligned(bump_allocator.allocator());
    try std.heap.testAllocatorLargeAlignment(bump_allocator.allocator());
    try std.heap.testAllocatorAlignedShrink(bump_allocator.allocator());
}
