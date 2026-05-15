require('smear_cursor').setup({
  scroll_buffer_space = false,
  smear_between_buffers = false,
  smear_between_neighbor_lines = false,
  scroll_buffer_space = false,
  stiffness = 0.5,
  trailing_stiffness = 0.5,
  matrix_pixel_threshold = 0.5,
  damping = 0.9999,  -- how "bouncy" the cursor is. 1 makes the cursor freeze in the top left lmao
  smear_insert_mode = false,
})
