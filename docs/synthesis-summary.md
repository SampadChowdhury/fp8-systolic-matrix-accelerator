# Historical synthesis evidence

The Lab 3 archive contained Synopsys Design Compiler reports for separate INT8 and FP8 4×4 compute engines mapped to the OSU FreePDK 45 nm `gscl45nm` standard-cell library. The raw reports and logs are intentionally not copied into this repository because they contain machine paths, tool-license text, and nearly 1.7 MB of instance-level listings. This page preserves the useful aggregate evidence.

These values describe the archived implementations, not the refactored dual-mode APB RTL in this repository.

| Metric | Archived INT8 engine | Archived FP8 E3M4 engine |
| --- | ---: | ---: |
| Intended frequency in Tcl | 600 MHz | 500 MHz |
| Effective clock period in timing report | 1.00 ns | 2.00 ns |
| Reported setup slack | 0.00 ns (MET) | 0.00 ns (MET) |
| Total cells | 7,019 | 13,399 |
| Combinational cells | 5,936 | 12,572 |
| Sequential cells | 1,083 | 699 |
| Total cell area | 24,790.303 µm² | 36,261.872 µm² |
| Approximate area | 0.024790 mm² | 0.036262 mm² |
| Dynamic power estimate | 18.4181 mW | 8.8201 mW |
| Leakage power estimate | 120.9500 µW | 167.7365 µW |
| Total power estimate | 18.5390 mW | 8.9878 mW |

## Interpretation constraints

- The INT8 Tcl used `expr 1000 / 600` with integer operands. Tcl therefore produced a 1.00 ns clock, which the timing report confirms, rather than the intended 1.667 ns period. The report proves closure at that constraint; it is not a measured maximum frequency.
- The FP8 Tcl produced the intended 2.00 ns period for 500 MHz.
- Both timing reports show exactly zero slack after optimization. No post-layout parasitics, clock-tree effects, or signoff corners were included.
- Power is a vectorless synthesis estimate unless switching activity is supplied. The values should not be read as measured silicon power or as energy-per-operation comparisons.
- Area conversion assumes the FreePDK report units are square micrometers.
- The archived INT8 and FP8 engines were separate top-level builds. The cleaned repository provides runtime mode selection and a 32-bit INT8 accumulator, so fresh synthesis is required for any new PPA claim.
