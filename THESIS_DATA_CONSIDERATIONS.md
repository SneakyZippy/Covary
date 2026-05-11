# Thesis & Research Considerations: Visualizing EMA Data

When using Covary for Ecological Momentary Assessment (EMA) research, the way data is visualized and aggregated can introduce certain biases or methodological artifacts. If you are comparing behaviors (like coffee intake) against subjective states (like energy levels), here are the key data science and HCI considerations to discuss in your thesis.

## 1. The "Micro-Variance Exaggeration" (Min-Max Normalization Bias)
When plotting two metrics on the same chart (e.g., in the Lagged Trend or Metric Insights screen), Covary uses **Min-Max Normalization** to scale both metrics to a relative `0.0 - 1.0` scale.

*   **The Implementation**: The app normalizes based on the *observed* minimum and maximum values within the selected time window.
*   **The Risk**: If a user's subjective energy level is highly stable (e.g., only fluctuating between 6.0 and 6.5 on a 1-10 scale), the algorithm stretches `6.0` to the bottom of the graph (`0.0`) and `6.5` to the top (`1.0`). 
*   **Thesis Discussion Point**: This visual stretching can exaggerate insignificant micro-variances. A tiny 0.5 dip in energy might visually appear as a massive crash, artificially looking highly correlated to a behavior spike (like coffee). Researchers analyzing the visualizations must be aware of the underlying absolute variance.

## 2. The "Total Days" Sparsity Skew
When calculating the "Average 24-Hour Profile" (Circadian Rhythm) for a behavior/counter like coffee, the backend averages the counts over `totalDays`.

*   **The Implementation**: `totalDays` is calculated as the number of *unique days where the metric was logged at least once*.
*   **The Risk**: If a user is observed for 14 days, but only drinks coffee on 2 of those days, the algorithm divides the total coffee count by 2, not 14. 
*   **Thesis Discussion Point**: While this does not affect the *shape* of the circadian curve (the peak time remains accurate), it shifts the absolute average values upward. The data reflects "average behavior *on days the behavior occurred*" rather than the absolute average across the entire observation period.

## 3. Binning Boundaries vs. Pharmacokinetics
EMA tools often need to align self-reported events that happen continuously in time.

*   **The Implementation**: Covary aggregates circadian data into discrete 1-hour bins (e.g., 8:00 AM – 8:59 AM is "Hour 8").
*   **The Risk**: Caffeine takes roughly 30–45 minutes to reach peak plasma concentration. If a user logs coffee at 8:55 AM (Hour 8), and logs an energy spike at 9:05 AM (Hour 9), the chart perfectly reflects the lag by showing a coffee peak at 8 and an energy peak at 9. However, they were only 10 minutes apart in reality.
*   **Thesis Discussion Point**: Hourly binning is a standard proxy for EMA data, but it introduces arbitrary boundaries. Researchers must consider these boundaries when analyzing rapid-onset interventions versus the granularity of the binning.

## 4. Interpolation of Subjective States During Sleep
Self-reported EMA data fundamentally differs from passive continuous sensing (like an ECG or smartwatch).

*   **The Implementation**: If a user logs their energy at 11:00 PM and again at 7:00 AM, the circadian chart draws a straight, interpolated line across the night. For behaviors (counters), unlogged hours correctly default to `0.0`.
*   **Thesis Discussion Point**: While mathematically sound for subjective self-reports (we don't want the graph dropping to zero), it is physiologically inaccurate, as actual energy/arousal dips significantly during sleep. This highlights the inherent limitation of EMA—we only have data when the user is awake and willing to interact.
