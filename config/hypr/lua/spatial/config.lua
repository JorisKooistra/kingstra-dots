return {
    -- Keep a visible strip of neighboring cells around the focused window.
    fill_single = true,
    peek_x = 24,
    peek_y = 24,
    gap_x = 12,
    gap_y = 12,

    -- Window dimensions are fractions of one grid cell. The largest preset
    -- still preserves the configured edge peeks.
    width_steps = { 0.50, 0.67, 0.85, 1.00 },
    height_steps = { 0.50, 0.67, 0.85, 1.00 },
    default_width_step = 4,
    default_height_step = 4,
}
