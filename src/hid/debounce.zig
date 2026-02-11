//! Key Debouncing Layer
//!
//! Provides debouncing for keyboard matrix scans using a simple counter-based approach.
//! Each key maintains a counter that increments when pressed and decrements when released.
//! A key is considered pressed when the counter exceeds a threshold.

const std = @import("std");
const microzig = @import("microzig");

/// Key event types
pub const KeyEvent = enum {
    pressed,
    released,
};

/// A key event with key ID
pub const KeyEventData = struct {
    key: u8, // Key index (0-47)
    event: KeyEvent,
};

/// Maximum number of events that can be queued in a single scan
pub const MAX_EVENTS = 16;

/// Event queue for storing key events
pub const EventQueue = struct {
    events: [MAX_EVENTS]KeyEventData = undefined,
    count: usize = 0,

    pub fn add(self: *EventQueue, event: KeyEventData) void {
        if (self.count < MAX_EVENTS) {
            self.events[self.count] = event;
            self.count += 1;
        }
    }

    pub fn slice(self: *const EventQueue) []const KeyEventData {
        return self.events[0..self.count];
    }
};

/// Debounce configuration
pub const DEBOUNCE_THRESHOLD: u8 = 3; // Number of consistent reads before state change
pub const MAX_DEBOUNCE_COUNT: u8 = 5; // Maximum counter value

/// Debounce state for a single key
const KeyState = struct {
    counter: u8 = 0,
    is_pressed: bool = false,
};

/// Keyboard debouncer - generic over matrix type  
pub fn Debouncer(comptime MatrixType: type, comptime key_count: usize, comptime num_rows: usize, comptime num_cols: usize) type {
    _ = num_rows; // Used in process() method
    return struct {
        const Self = @This();
        
        matrix: *MatrixType,
        states: [key_count]KeyState,

        pub fn init(matrix: *MatrixType) Self {
            return Self{
                .matrix = matrix,
                .states = [_]KeyState{.{}} ** key_count,
            };
        }

        /// Process a matrix scan and update debounce state
        /// Returns an array of key events (press/release)
        pub fn process(self: *Self) !EventQueue {
            var events = EventQueue{};

            // Scan the matrix
            const pressed_keys = try self.matrix.scan();

            // Update debounce state for each key
            for (0..key_count) |key_idx| {
                const row: u8 = @intCast(key_idx / num_cols);
                const col: u8 = @intCast(key_idx % num_cols);
                const key = microzig.drivers.input.Key.new(row, col);

                const is_currently_pressed = pressed_keys.is_pressed(key);
                var state = &self.states[key_idx];

                // Update counter based on current reading
                if (is_currently_pressed) {
                    if (state.counter < MAX_DEBOUNCE_COUNT) {
                        state.counter += 1;
                    }
                } else {
                    if (state.counter > 0) {
                        state.counter -= 1;
                    }
                }

                // Check for state transitions
                if (!state.is_pressed and state.counter >= DEBOUNCE_THRESHOLD) {
                    // Key pressed
                    state.is_pressed = true;
                    events.add(.{
                        .key = @intCast(key_idx),
                        .event = .pressed,
                    });
                } else if (state.is_pressed and state.counter == 0) {
                    // Key released
                    state.is_pressed = false;
                    events.add(.{
                        .key = @intCast(key_idx),
                        .event = .released,
                    });
                }
            }

            return events;
        }

        /// Check if a specific key is currently pressed (debounced)
        pub fn isPressed(self: *const Self, key_idx: u8) bool {
            if (key_idx >= key_count) return false;
            return self.states[key_idx].is_pressed;
        }
    };
}
