# Page 5: 330 km CMA + CD physical BER

MATLAB R2016a entry: `start_cma_cd_gui`. This entry reads RF47 long-PRBS
state without enabling/restarting replay. RF47 must already be in the
validated 262144-symbol long-PRBS mode. Do not use the legacy short-replay
startup script to prepare this measurement.

The other pages, page-3 DSP, and shared DSP helpers are not changed.
The GUI shell backup is `../backups/page5_cma_cd_20260922/main_realtime_eye.m`.

## Signal path

Single-trigger 1M x 4 at 40 GSa/s; scope stops during DSP. Audit the RF47
reference before and after each acquisition. Remove DC, estimate/derotate
CFO, apply the same NRZ anti-alias filter and 8 GSa/s resampling as page 3,
then apply a padded complex frequency-domain CD inverse to both polarizations.
Follow with an isolated copy of page-3 15-tap blind CMA, fourth-moment phase
tracking, blind level normalization and prefix reference synchronization.
No LMS, RLS, reference-trained FIR or substitution of ideal symbols.

Default total dispersion is **+5610 ps/nm**, a nominal assumption of
330 km x 17 ps/nm/km at 1550 nm, NOT an independently measured CD.
The inverse uses beta2L = -lambda^2 D/(2*pi*c), SI units, and
exp(+j*beta2L*omega^2/2). Padding avoids record wrap-around.
Source for the digital-filter approach: S. J. Savory,
https://doi.org/10.1364/OE.16.000804.

If prefix synchronization fails, try the opposite CD sign (receiver
conjugation convention), CFO aliases spaced by Rs/4, then a bounded CD grid.
Selection uses only consistent prefix correlation; never test-window BER.
Successful CD is cached in page-5 state. Each new window trains fresh blind
CMA taps. Short CMA can absorb residual CD, so successful CD is not a unique
estimate of actual fiber dispersion. Clear page 5 to reset this cache.

Override nominal settings, if known:

```matlab
start_cma_cd_gui(struct('dispersionCmaOptions', ...
    struct('dispersionPsNm',5610,'wavelengthNm',1550)));
```

## BER meaning

First 29900 output symbols resolve ambiguity only. Three separate prefix
sections must agree on source/permutation/conjugation/cyclic reference shift.
35000 held-out bits per lane (140000 total) are compared for each valid window.
No samples from this window are used to select a DSP candidate.
One zero-error window is not proof of zero long-term BER: its one-sided 95%
Poisson upper bound is about 2.14e-5 (total), not a 1e-10 measurement.

Plot X is actual acquisition timestamp, Y is that window's BER (not cumulative).
Zero is plotted at zero on a linear axis. Invalid synchronization produces
a NaN gap and increments the failure counter, but not the BER bit counter.
A high BER after successful prefix lock is retained, never hidden as a zero.
Cumulative counters remain in the header. Clearing page 5 leaves other pages alone.

## Verification

`../tests_page5_cma_cd_20260922/test_page5_cd.m` checks the CD forward/inverse
pair, the saved real 330 km record, GUI isolation, window history, invalid
gaps, high-BER retention and page-only clearing. Test MATLAB version: R2016a.
The real initial record measured 0/140000 errors, EVM X/Y 0.2248/0.2187.
The same record also measured zero without explicit CD; it does not establish
a BER improvement due to the new module. Live validation is recorded separately.
