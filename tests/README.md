# lib tests

Runs every routine in `lib/` on an emulated Z80 and checks the results against a
reference model (addresses, pixels, lines, circles, sprites, scrolling, text, buffers).

Needs `sjasmplus` on the PATH and the Python `z80` package:

    python3 -m venv .venv && .venv/bin/pip install -r tests/requirements.txt
    .venv/bin/python tests/test_lib.py            # all tests
    .venv/bin/python tests/test_lib.py draw_line  # one test by name

All `lib/*.asm` files are assembled together at `$8000`, with `row_table` defined as `$B000`.
Not covered: timing, interrupts firing mid-routine, real 128K paging hardware.
