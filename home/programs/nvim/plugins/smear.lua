require('smear_cursor').setup({
  scroll_buffer_space = false,
  smear_between_buffers = false,
  smear_between_neighbor_lines = false,
  stiffness = 0.5,
  trailing_stiffness = 0.5,
  matrix_pixel_threshold = 0.5,
  damping = 0.95,    
  smear_insert_mode = false,
})
