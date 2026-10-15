//! The audio-interface bus set: the patchbay of physical I/O the engine exposes
//! to a Program. Pure data (std only) so Programs that route it stay
//! host-testable. All slices are interleaved stereo f32 of the same length.
pub const AudioIO = struct {
    line_in: []const f32, // codec ADC (external input)
    usb_in: []const f32, // host playback over USB (OUT); silence when host idle
    line_out: []f32, // codec DAC (external output); engine pre-zeros
    usb_out: []f32, // host capture over USB (IN); engine pre-zeros
};
